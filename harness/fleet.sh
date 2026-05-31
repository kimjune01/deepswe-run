#!/usr/bin/env bash
# fleet.sh — verb-driven driver for DeepSWE EC2 spot-fleet runs.
#
# Replaces launch_phase_a.sh / launch_phase_b.sh / smoke_codex_ec2.sh.
# Patterned on swebench-pro's driver/run_fleet.sh (single script, sub-verbs,
# per-box manifest, watchdog self-terminate, explicit AUTH_MODE assertion).
#
# Usage:
#   ./fleet.sh smoke    <task_id> <arm>
#   ./fleet.sh provision <N> <arm>     [run-tag]
#   ./fleet.sh dispatch <run-tag> <eligible> <arms>
#   ./fleet.sh status   <run-tag>
#   ./fleet.sh collect  <run-tag>
#   ./fleet.sh teardown <run-tag>
#   ./fleet.sh drain    <run-tag> <box-name>...
#   ./fleet.sh nuke-all                 # emergency sweep of every dsr-fleet-* resource in the region
#
# State files (banked from swebench-pro):
#   /tmp/dsr-<name>.env                 — per-box: KEY/PUBIP/IID/SG/REGION
#   results/coordinator/<run-tag>/manifest.json   — fleet manifest for this run
#   results/coordinator/<run-tag>/ledger.jsonl    — coordinator's resume source
#
# AUTH_MODE (explicit, never inferred):
#   api          — Composer/Flash scaffold via cursor-agent + gemini_api (CURSOR/GEMINI keys billed)
#   subscription — codex CLI scaffold via ~/.codex/auth.json (gpt-5.5 Pro subscription, $0)
# The script PRINTS a loud banner with the chosen mode + the cost implication before any box starts.
#
# Box self-terminate watchdog: `sudo shutdown -h +WATCHDOG_MIN` (default 720 min) on every box.
# Independent of any host-side trap; the box will go away on its own if the driver crashes.

set -uo pipefail

# -- config -----------------------------------------------------------------
REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=150
WATCHDOG_MIN="${WATCHDOG_MIN:-720}"

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"

SSH() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$1" "ec2-user@$2" "${@:3}"; }
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
die()  { echo "FATAL: $*" >&2; exit 1; }
banner() { echo "================ $* ================" ; }

# -- AUTH_MODE gating + cred staging ----------------------------------------
arm_auth_mode() {
  case "$1" in
    scaffold|baseline-comp)        echo api ;;
    scaffold-codex|baseline-codex) echo subscription ;;
    baseline-flash)                echo api ;;
    *) die "unknown arm: $1" ;;
  esac
}

assert_creds() {
  local mode="$1"
  if [ "$mode" = api ]; then
    banner "AUTH_MODE=api → cursor-agent bills CURSOR_API_KEY, gemini_api bills GEMINI_API_KEY"
    [ -n "${CURSOR_API_KEY:-}" ] || die "CURSOR_API_KEY unset (source ~/.zshrc)"
    [ -n "${GEMINI_API_KEY:-}" ] || die "GEMINI_API_KEY unset (source ~/.zshrc)"
  elif [ "$mode" = subscription ]; then
    banner "AUTH_MODE=subscription → codex CLI bills ~/.codex/auth.json (Pro plan, \$0)"
    [ -s "$HOME/.codex/auth.json" ] || die "~/.codex/auth.json missing (run 'codex login' locally first)"
  else
    die "unknown auth mode: $mode"
  fi
}

# -- per-box env file -------------------------------------------------------
box_envf() { echo "/tmp/dsr-$1.env"; }
run_manifest() { echo "$DEEPSWE_RUN_DIR/results/coordinator/$1/manifest.json"; }
run_boxes_env() { echo "$DEEPSWE_RUN_DIR/results/coordinator/$1/boxes.json"; }

# ===========================================================================
# VERB: provision <N> <arm> [run-tag]
# Provisions N spot boxes, bootstraps each (parallel), pushes creds + repo + tasks.
# Writes per-box envs + a run manifest. Boxes self-terminate after WATCHDOG_MIN.
# ===========================================================================
verb_provision() {
  local N="$1" ARM="$2" TAG="${3:-$(date +%s)-$$}"
  local MODE; MODE=$(arm_auth_mode "$ARM")
  assert_creds "$MODE"
  local DEST="$DEEPSWE_RUN_DIR/results/coordinator/$TAG"
  mkdir -p "$DEST"
  log "provision: tag=$TAG N=$N arm=$ARM mode=$MODE region=$REGION"

  local MYIP; MYIP=$(curl -s https://checkip.amazonaws.com)
  local -a NAMES=() IIDS=()
  for i in $(seq 1 "$N"); do
    local NAME="fleet-$TAG-$i" KEY="dsr-$TAG-$i" SGN="dsr-$TAG-$i" PEM="/tmp/${KEY}.pem"
    aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"
    chmod 400 "$PEM"
    local SG
    SG=$(aws ec2 create-security-group --group-name "$SGN" --description "dsr fleet $TAG" --vpc-id $VPC --query GroupId --output text --region $REGION)
    aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null
    local IID
    IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
      --security-group-ids "$SG" --count 1 \
      --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
      --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=dsr-$NAME}]" \
      --query "Instances[0].InstanceId" --output text --region $REGION)
    NAMES+=("$NAME"); IIDS+=("$IID")
    log "  $NAME: iid=$IID key=$KEY sg=$SG"
  done

  log "waiting for instance-running on $N boxes"
  aws ec2 wait instance-running --instance-ids "${IIDS[@]}" --region $REGION

  # collect IPs and write env files
  for i in "${!NAMES[@]}"; do
    local NAME="${NAMES[$i]}" IID="${IIDS[$i]}"
    local IP
    IP=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
    local SG
    SG=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text --region $REGION)
    printf "KEY=dsr-%s-%s\nPUBIP=%s\nIID=%s\nSG=%s\nREGION=%s\nTAG=%s\nARM=%s\nMODE=%s\n" \
      "$TAG" "$((i+1))" "$IP" "$IID" "$SG" "$REGION" "$TAG" "$ARM" "$MODE" > "$(box_envf "$NAME")"
  done

  log "bootstrap+push in parallel"
  for i in "${!NAMES[@]}"; do
    bootstrap_one "${NAMES[$i]}" "$DEST" &
  done
  wait

  # write boxes.json for coordinator
  python3 - <<PY > "$(run_boxes_env "$TAG")"
import json, os
names = "${NAMES[*]}".split()
out = []
for name in names:
    env = {}
    with open(f"/tmp/dsr-{name}.env") as f:
        for line in f:
            k, _, v = line.strip().partition("=")
            env[k] = v
    out.append({"name": name, "PUBIP": env["PUBIP"], "KEY": env["KEY"]})
print(json.dumps(out, indent=2))
PY

  # fleet manifest
  python3 - <<PY > "$(run_manifest "$TAG")"
import json
print(json.dumps({
    "tag": "$TAG",
    "arm": "$ARM",
    "mode": "$MODE",
    "boxes": "${NAMES[*]}".split(),
    "region": "$REGION",
    "instance_type": "$ITYPE",
    "watchdog_min": $WATCHDOG_MIN,
}, indent=2))
PY

  banner "PROVISION DONE tag=$TAG"
  log "  manifest: $(run_manifest "$TAG")"
  log "  boxes.json: $(run_boxes_env "$TAG")"
  log "  next: ./fleet.sh dispatch $TAG <eligible> <arms>"
}

# Single-box bootstrap: arm-aware install + creds + repo + tasks
bootstrap_one() {
  local NAME="$1" DEST="$2"
  local envf; envf=$(box_envf "$NAME")
  # shellcheck disable=SC1090
  source "$envf"
  local PEM="/tmp/${KEY}.pem"

  for j in $(seq 50); do SSH "$PEM" "$PUBIP" "echo up" >/dev/null 2>&1 && break || sleep 5; done
  log "  $NAME bootstrap (watchdog=+${WATCHDOG_MIN}m)"

  SSH "$PEM" "$PUBIP" "
    set -e
    mkdir -p ~/deep-swe/tasks ~/deepswe-run ~/.docker/cli-plugins ~/.codex
    sudo shutdown -h +$WATCHDOG_MIN || true   # self-terminate backstop
    sudo dnf install -y -q docker git jq nodejs npm rsync >/dev/null 2>&1
    sudo systemctl enable --now docker
    sudo chmod 666 /var/run/docker.sock
    curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
    docker compose version >/dev/null || { echo 'FATAL compose'; exit 1; }
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    export PATH=\$HOME/.local/bin:\$PATH
    uv tool install --python 3.12 datacurve-pier==0.2.0 >/dev/null 2>&1
    ~/.local/bin/pier --help >/dev/null 2>&1 || { echo 'FATAL pier'; exit 1; }
  " >"$DEST/$NAME-bootstrap.log" 2>&1

  if [ "$MODE" = api ]; then
    SSH "$PEM" "$PUBIP" "
      set -e
      uv venv /home/ec2-user/.dsr-venv --python 3.12 >/dev/null 2>&1
      uv pip install --python /home/ec2-user/.dsr-venv/bin/python google-generativeai >/dev/null 2>&1
      /home/ec2-user/.dsr-venv/bin/python -c 'import google.generativeai' || { echo 'FATAL genai'; exit 1; }
      sudo ln -sf /home/ec2-user/.dsr-venv/bin/python /usr/local/bin/python3-dsr
      curl -fsS https://cursor.com/install -o /tmp/cursor-install.sh
      bash /tmp/cursor-install.sh >/dev/null 2>&1 || true
      ls ~/.cursor/bin/cursor-agent >/dev/null 2>&1 || ls ~/.local/bin/cursor-agent >/dev/null 2>&1 \
        || which cursor-agent >/dev/null 2>&1 || { echo 'FATAL cursor-agent install'; exit 1; }
      echo CREDS_INSTALL_OK
    " >>"$DEST/$NAME-bootstrap.log" 2>&1
  else
    SSH "$PEM" "$PUBIP" "sudo npm install -g @openai/codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1 && echo CODEX_INSTALL_OK || { echo 'FATAL codex install'; exit 1; }" \
      >>"$DEST/$NAME-bootstrap.log" 2>&1
    scp -q -i "$PEM" -o StrictHostKeyChecking=no "$HOME/.codex/auth.json" "ec2-user@$PUBIP:/home/ec2-user/.codex/auth.json"
    SSH "$PEM" "$PUBIP" "chmod 600 ~/.codex/auth.json"
  fi

  log "  $NAME scp tasks + repo"
  rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $PEM" \
    --exclude='results/' --exclude='.git/' --exclude='.venv/' --exclude='__pycache__/' \
    --exclude='external/' --exclude='harness/feature/run/' \
    "$DEEPSWE_RUN_DIR/" "ec2-user@$PUBIP:/home/ec2-user/deepswe-run/"
  rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $PEM" \
    "$DEEP_SWE_DIR/tasks/" "ec2-user@$PUBIP:/home/ec2-user/deep-swe/tasks/"

  # write .dsr.env on box (no keys in api mode if we don't need them; here we do for runtime)
  if [ "$MODE" = api ]; then
    SSH "$PEM" "$PUBIP" "cat > ~/.dsr.env" <<EOF
export CURSOR_API_KEY="$CURSOR_API_KEY"
export GEMINI_API_KEY="$GEMINI_API_KEY"
export PATH=\$HOME/.local/bin:\$HOME/.cursor/bin:\$PATH
export DEEP_SWE_DIR=\$HOME/deep-swe
export DEEPSWE_RUN_DIR=\$HOME/deepswe-run
EOF
  else
    SSH "$PEM" "$PUBIP" "cat > ~/.dsr.env" <<'EOF'
export PATH=$HOME/.local/bin:$PATH
export DEEP_SWE_DIR=$HOME/deep-swe
export DEEPSWE_RUN_DIR=$HOME/deepswe-run
EOF
  fi
  log "  $NAME ready"
}

# ===========================================================================
# VERB: dispatch <run-tag> <eligible> <arms>
# Run coordinator.py against the provisioned fleet. Resumable via ledger.
# ===========================================================================
verb_dispatch() {
  local TAG="$1" ELIGIBLE="$2" ARMS="$3"
  local DEST="$DEEPSWE_RUN_DIR/results/coordinator/$TAG"
  [ -s "$(run_boxes_env "$TAG")" ] || die "no boxes.json for $TAG (provision first)"
  [ -s "$DEEPSWE_RUN_DIR/$ELIGIBLE" ] || die "eligible file missing: $ELIGIBLE"
  banner "DISPATCH tag=$TAG arms=$ARMS eligible=$ELIGIBLE"
  python3 "$DEEPSWE_RUN_DIR/harness/coordinator.py" \
    --eligible "$DEEPSWE_RUN_DIR/$ELIGIBLE" \
    --arms "$ARMS" \
    --boxes-env "$(run_boxes_env "$TAG")" \
    --ledger "$DEST/ledger.jsonl" \
    --dest "$DEST/runs" \
    --ceiling "${CEILING:-2400}" \
    --max-attempts "${MAX_ATTEMPTS:-2}" 2>&1 | tee -a "$DEST/coordinator.log"
}

# ===========================================================================
# VERB: status <run-tag>
# ===========================================================================
verb_status() {
  local TAG="$1"
  local L="$DEEPSWE_RUN_DIR/results/coordinator/$TAG/ledger.jsonl"
  [ -f "$L" ] || die "no ledger for $TAG"
  local total done_count
  done_count=$(wc -l < "$L")
  local resolved=$(grep -c '"class": "RESOLVED"' "$L")
  local unresolved=$(grep -c '"class": "UNRESOLVED' "$L")
  echo "tag=$TAG ledger=$L"
  echo "  done=$done_count resolved=$resolved unresolved=$unresolved"
  # per-box latest
  for box in $(python3 -c "import json,sys; [print(b['name']) for b in json.load(open('$(run_boxes_env "$TAG")'))]"); do
    local last
    last=$(grep "\"box\": \"$box\"" "$L" | tail -1 | python3 -c 'import json,sys; r=json.loads(sys.stdin.read() or "{}"); print(r.get("task_id","-"), r.get("class","-"), r.get("ts","-")) if r else print("-")')
    echo "  $box -> $last"
  done
}

# ===========================================================================
# VERB: collect <run-tag>  (pull receipts; coordinator already does this per-task,
#   this is a final sweep + sanity check)
# ===========================================================================
verb_collect() {
  local TAG="$1"
  local DEST="$DEEPSWE_RUN_DIR/results/coordinator/$TAG"
  for box in $(python3 -c "import json; [print(b['name'],b['PUBIP'],b['KEY']) for b in json.load(open('$(run_boxes_env "$TAG")'))]"); do
    : # coordinator handles pulls during run; if a re-pull is needed, do it here.
  done
  log "collect: receipts at $DEST/runs"
}

# ===========================================================================
# VERB: teardown <run-tag>
# Cancel spot requests, terminate instances, wait, delete SGs+keys, clean envs.
# ===========================================================================
verb_teardown() {
  local TAG="$1"
  local DEST="$DEEPSWE_RUN_DIR/results/coordinator/$TAG"
  local MANIFEST="$(run_manifest "$TAG")"
  [ -s "$MANIFEST" ] || die "no manifest for $TAG"
  banner "TEARDOWN $TAG"
  local -a IIDS=() SGS=() KEYS=() PEMS=()
  for name in $(python3 -c 'import json; [print(b) for b in json.load(open("'"$MANIFEST"'"))["boxes"]]'); do
    local envf; envf=$(box_envf "$name")
    [ -f "$envf" ] || continue
    # shellcheck disable=SC1090
    source "$envf"
    IIDS+=("$IID"); SGS+=("$SG"); KEYS+=("$KEY"); PEMS+=("/tmp/$KEY.pem")
  done

  for iid in "${IIDS[@]}"; do
    local SIR
    SIR=$(aws ec2 describe-instances --instance-ids "$iid" --query "Reservations[0].Instances[0].SpotInstanceRequestId" --output text --region $REGION 2>/dev/null)
    [ -n "$SIR" ] && [ "$SIR" != None ] && aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SIR" --region $REGION >/dev/null 2>&1
    aws ec2 terminate-instances --instance-ids "$iid" --region $REGION >/dev/null 2>&1
  done
  for iid in "${IIDS[@]}"; do aws ec2 wait instance-terminated --instance-ids "$iid" --region $REGION 2>/dev/null; done
  for sg in "${SGS[@]}"; do aws ec2 delete-security-group --group-id "$sg" --region $REGION 2>/dev/null; done
  for k in "${KEYS[@]}"; do aws ec2 delete-key-pair --key-name "$k" --region $REGION 2>/dev/null; done
  for p in "${PEMS[@]}"; do [ -f "$p" ] && mv "$p" "/tmp/.deepswe-pem-trash-$(date +%s)-$(basename "$p")" 2>/dev/null; done
  for name in $(python3 -c 'import json; [print(b) for b in json.load(open("'"$MANIFEST"'"))["boxes"]]'); do
    mv "$(box_envf "$name")" "/tmp/.deepswe-env-trash-$(date +%s)-$(basename "$(box_envf "$name")")" 2>/dev/null
  done
  log "torn down: ${#IIDS[@]} instances, ${#SGS[@]} SGs, ${#KEYS[@]} key pairs"
}

# ===========================================================================
# VERB: drain <run-tag> <box-name>...
# Lets boxes finish in-flight task then retires them (sentinel-based).
# ===========================================================================
verb_drain() {
  local TAG="$1"; shift
  local L="$DEEPSWE_RUN_DIR/results/coordinator/$TAG/ledger.jsonl"
  [ -f "$L" ] || die "no ledger for $TAG"
  log "drain: tag=$TAG boxes=$*"
  for name in "$@"; do
    local envf; envf=$(box_envf "$name")
    [ -f "$envf" ] || { log "  $name: no envf, skip"; continue; }
    # shellcheck disable=SC1090
    source "$envf"
    # wait for next ledger entry for this box, then terminate
    local before=$(grep -c "\"box\": \"$name\"" "$L" 2>/dev/null || echo 0)
    log "  $name: waiting for next verdict (current count=$before)"
    until [ "$(grep -c "\"box\": \"$name\"" "$L" 2>/dev/null || echo 0)" -gt "$before" ]; do sleep 30; done
    log "  $name: verdict landed; terminating $IID"
    aws ec2 terminate-instances --instance-ids "$IID" --region $REGION >/dev/null 2>&1
    aws ec2 wait instance-terminated --instance-ids "$IID" --region $REGION 2>/dev/null
    aws ec2 delete-security-group --group-id "$SG" --region $REGION 2>/dev/null
    aws ec2 delete-key-pair --key-name "$KEY" --region $REGION 2>/dev/null
    mv "$envf" "/tmp/.deepswe-env-trash-drained-$(date +%s)-$name" 2>/dev/null
    log "  $name: drained"
  done
}

# ===========================================================================
# VERB: smoke <task_id> <arm>
# Single-box, single-task end-to-end smoke. Self-cleans.
# ===========================================================================
verb_smoke() {
  local TASK="$1" ARM="$2" TAG="smoke-$(date +%s)-$$"
  local PARTIAL="$DEEPSWE_RUN_DIR/frozen/eligible-smoke-$TAG.txt"
  echo "$TASK" > "$PARTIAL"
  verb_provision 1 "$ARM" "$TAG"
  verb_dispatch  "$TAG" "frozen/eligible-smoke-$TAG.txt" "$ARM"
  verb_status    "$TAG"
  verb_teardown  "$TAG"
  mv "$PARTIAL" "/tmp/.deepswe-eligible-smoke-$TAG.txt" 2>/dev/null
}

# ===========================================================================
# VERB: nuke-all
# Emergency: terminate ALL dsr-fleet-* instances + SGs + keys in the region.
# ===========================================================================
verb_nuke_all() {
  banner "EMERGENCY NUKE — all dsr-* spot resources in $REGION"
  local IIDS
  IIDS=$(aws ec2 describe-instances --region $REGION \
    --filters "Name=tag:Name,Values=dsr-fleet-*" "Name=instance-state-name,Values=pending,running,stopping" \
    --query "Reservations[].Instances[].InstanceId" --output text)
  [ -n "$IIDS" ] && aws ec2 terminate-instances --instance-ids $IIDS --region $REGION >/dev/null
  [ -n "$IIDS" ] && aws ec2 wait instance-terminated --instance-ids $IIDS --region $REGION
  for sg in $(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=dsr-*" --query "SecurityGroups[].GroupId" --output text); do
    aws ec2 delete-security-group --group-id "$sg" --region $REGION 2>/dev/null
  done
  for k in $(aws ec2 describe-key-pairs --region $REGION --filters "Name=key-name,Values=dsr-*" --query "KeyPairs[].KeyName" --output text); do
    aws ec2 delete-key-pair --key-name "$k" --region $REGION 2>/dev/null
  done
  log "nuke done"
}

# -- dispatcher -------------------------------------------------------------
VERB="${1:-}"; shift || true
case "$VERB" in
  smoke)     verb_smoke "$@" ;;
  provision) verb_provision "$@" ;;
  dispatch)  verb_dispatch "$@" ;;
  status)    verb_status "$@" ;;
  collect)   verb_collect "$@" ;;
  teardown)  verb_teardown "$@" ;;
  drain)     verb_drain "$@" ;;
  nuke-all)  verb_nuke_all ;;
  ""|help|-h|--help) sed -n '2,30p' "$0" ;;
  *) die "unknown verb: $VERB" ;;
esac
