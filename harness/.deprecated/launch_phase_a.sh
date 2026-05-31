#!/usr/bin/env bash
# launch_phase_a.sh [N=4] — provision N spot boxes, run coordinator against
# frozen/eligible.txt × scaffold (Composer/Flash) × 1 trial, then tear down.
#
# v4 Phase A scored-run launcher. Each box is bootstrapped with docker+compose
# +pier+cursor-agent+google-generativeai (the v3 dependency set). The
# coordinator dispatches (task_id, arm) work units dynamically across boxes;
# trap on EXIT tears down every box, SG, and key-pair regardless of exit path.

set -uo pipefail
N="${1:-4}"
ARMS="${ARMS:-scaffold}"
ELIGIBLE="${ELIGIBLE:-frozen/eligible.txt}"
CEILING="${CEILING:-2400}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"

REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=150

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"
: "${CURSOR_API_KEY:?must be set; source ~/.zshrc first}"
: "${GEMINI_API_KEY:?must be set; source ~/.zshrc first}"

TS=$(date +%s)-$$
RUN_TAG="phase-a-$TS"
DEST="$DEEPSWE_RUN_DIR/results/coordinator/$RUN_TAG"
mkdir -p "$DEST"
BOXES_JSON="$DEST/boxes.json"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$DEST/launch.log"; }

# Track every resource we create so the trap can sweep cleanly.
declare -a IIDS=() SGS=() KEYS=()
cleanup(){
  log "==== TEARDOWN start ===="
  for iid in "${IIDS[@]}"; do
    SIR=$(aws ec2 describe-instances --instance-ids "$iid" --query "Reservations[0].Instances[0].SpotInstanceRequestId" --output text --region $REGION 2>/dev/null)
    [ -n "${SIR:-}" ] && [ "$SIR" != "None" ] && aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SIR" --region $REGION >/dev/null 2>&1
    aws ec2 terminate-instances --instance-ids "$iid" --region $REGION >/dev/null 2>&1
  done
  # wait for terminate so SGs become deletable
  for iid in "${IIDS[@]}"; do
    aws ec2 wait instance-terminated --instance-ids "$iid" --region $REGION 2>/dev/null
  done
  for sg in "${SGS[@]}"; do aws ec2 delete-security-group --group-id "$sg" --region $REGION 2>/dev/null; done
  for k in "${KEYS[@]}"; do aws ec2 delete-key-pair --key-name "$k" --region $REGION 2>/dev/null; rm -f "/tmp/${k}.pem"; done
  log "==== TEARDOWN done ===="
}
trap cleanup EXIT

MYIP=$(curl -s https://checkip.amazonaws.com)

# --- per-box provisioning (sequential create, parallel bootstrap) -----------
declare -a PUBIPS=()
log "provisioning $N spot boxes ($ITYPE, ${EBS_GB}G gp3, $REGION)"
for i in $(seq 1 $N); do
  KEY="dsr-phaseA-$TS-$i"; SGN="dsr-phaseA-$TS-$i"; PEM="/tmp/${KEY}.pem"
  aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
  KEYS+=("$KEY")
  SG=$(aws ec2 create-security-group --group-name "$SGN" --description "phase-A box $i" --vpc-id $VPC --query GroupId --output text --region $REGION)
  SGS+=("$SG")
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null
  IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
    --security-group-ids "$SG" --count 1 \
    --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
    --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=dsr-phaseA-$i}]" \
    --query "Instances[0].InstanceId" --output text --region $REGION)
  IIDS+=("$IID")
  log "  box $i: iid=$IID key=$KEY sg=$SG"
done

# wait for all to be running
for iid in "${IIDS[@]}"; do
  aws ec2 wait instance-running --instance-ids "$iid" --region $REGION
done

# collect IPs
for iid in "${IIDS[@]}"; do
  ip=$(aws ec2 describe-instances --instance-ids "$iid" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
  PUBIPS+=("$ip")
done
log "instances running; IPs: ${PUBIPS[*]}"

# --- bootstrap + push (parallel per box) ------------------------------------
bootstrap_one(){
  local idx="$1" key="$2" ip="$3" pem="/tmp/$2.pem"
  local SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $pem"
  for j in $(seq 50); do $SSH ec2-user@"$ip" "echo up" >/dev/null 2>&1 && break || sleep 5; done
  log "  box $idx bootstrap"
  $SSH ec2-user@"$ip" "
    set -e
    mkdir -p ~/deep-swe/tasks ~/deepswe-run ~/.docker/cli-plugins
    sudo shutdown -h +1440 || true   # 24h safety net
    sudo dnf install -y -q docker git jq nodejs npm rsync >/dev/null 2>&1
    sudo systemctl enable --now docker
    sudo chmod 666 /var/run/docker.sock
    curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
    docker compose version >/dev/null || { echo 'FATAL compose'; exit 1; }
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    export PATH=\$HOME/.local/bin:\$PATH
    uv tool install --python 3.12 datacurve-pier==0.2.0 >/dev/null 2>&1
    ~/.local/bin/pier --help >/dev/null 2>&1 || { echo 'FATAL pier'; exit 1; }
    uv venv /home/ec2-user/.dsr-venv --python 3.12 >/dev/null 2>&1
    uv pip install --python /home/ec2-user/.dsr-venv/bin/python google-generativeai >/dev/null 2>&1
    /home/ec2-user/.dsr-venv/bin/python -c 'import google.generativeai' || { echo 'FATAL genai'; exit 1; }
    sudo ln -sf /home/ec2-user/.dsr-venv/bin/python /usr/local/bin/python3-dsr
    curl -fsS https://cursor.com/install -o /tmp/cursor-install.sh
    bash /tmp/cursor-install.sh >/dev/null 2>&1 || true
    CA=\$(ls ~/.cursor/bin/cursor-agent 2>/dev/null || ls ~/.local/bin/cursor-agent 2>/dev/null || which cursor-agent 2>/dev/null)
    [ -n \"\$CA\" ] && \$CA --version >/dev/null 2>&1 || { echo 'FATAL cursor-agent'; exit 1; }
    echo BOOTSTRAP_OK
  " 2>&1 | tee -a "$DEST/box$idx-bootstrap.log" | tail -3
  log "  box $idx scp tasks + repo"
  rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $pem" \
    --exclude='results/' --exclude='.git/' --exclude='.venv/' --exclude='__pycache__/' \
    --exclude='external/' --exclude='harness/feature/run/' \
    "$DEEPSWE_RUN_DIR/" ec2-user@"$ip":/home/ec2-user/deepswe-run/
  rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $pem" \
    "$DEEP_SWE_DIR/tasks/" ec2-user@"$ip":/home/ec2-user/deep-swe/tasks/
  $SSH ec2-user@"$ip" "cat > ~/.dsr.env" <<EOF
export CURSOR_API_KEY="$CURSOR_API_KEY"
export GEMINI_API_KEY="$GEMINI_API_KEY"
export PATH=\$HOME/.local/bin:\$HOME/.cursor/bin:\$PATH
export DEEP_SWE_DIR=\$HOME/deep-swe
export DEEPSWE_RUN_DIR=\$HOME/deepswe-run
EOF
}

for i in $(seq 1 $N); do
  bootstrap_one $i "${KEYS[$((i-1))]}" "${PUBIPS[$((i-1))]}" &
done
wait
log "all boxes bootstrapped + populated"

# --- build boxes.json for coordinator ---------------------------------------
python3 - <<PY > "$BOXES_JSON"
import json
ips = "${PUBIPS[*]}".split()
keys = "${KEYS[*]}".split()
print(json.dumps([{"name": f"box{i+1}", "PUBIP": ip, "KEY": k}
                  for i, (ip, k) in enumerate(zip(ips, keys))], indent=2))
PY
log "boxes.json -> $BOXES_JSON"
cat "$BOXES_JSON"

# --- launch coordinator -----------------------------------------------------
log "==== coordinator: --arms $ARMS --eligible $ELIGIBLE --boxes-env $BOXES_JSON ===="
python3 "$DEEPSWE_RUN_DIR/harness/coordinator.py" \
  --eligible "$DEEPSWE_RUN_DIR/$ELIGIBLE" \
  --arms "$ARMS" \
  --boxes-env "$BOXES_JSON" \
  --ledger "$DEST/ledger.jsonl" \
  --dest "$DEST/runs" \
  --ceiling "$CEILING" \
  --max-attempts "$MAX_ATTEMPTS" 2>&1 | tee -a "$DEST/coordinator.log"

log "==== coordinator exited; trap will sweep ===="
