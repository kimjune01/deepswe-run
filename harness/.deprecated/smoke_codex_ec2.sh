#!/usr/bin/env bash
# smoke_codex_ec2.sh <task-id> — v4 (2026-05-30) two-arm smoke on a fresh EC2 spot box.
#
# Runs BOTH publishable arms (scaffold, baseline-codex) for one task_id using
# codex CLI subscription auth (gpt-5.5). Validates run_arm.sh's codex_call
# wrapper end-to-end on box infra before cutting frozen-skills-v3.
#
# Pushes ~/.codex/auth.json (subscription token bundle) to the box; no API keys
# required for these arms. Tears down the box, key-pair, and SG on EXIT.

set -uo pipefail
TASK_ID="${1:?usage: smoke_codex_ec2.sh <task-id>}"

REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=150

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"
[ -d "$DEEP_SWE_DIR/tasks/$TASK_ID" ] || { echo "FATAL: task $TASK_ID not in $DEEP_SWE_DIR"; exit 1; }
[ -f "$HOME/.codex/auth.json" ] || { echo "FATAL: ~/.codex/auth.json missing — run 'codex login' locally first"; exit 1; }

TS=$(date +%s)-$$; KEY=deepswe-codex-$TS; SGN=deepswe-codex-$TS; PEM=/tmp/${KEY}.pem
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $PEM"
DEST="${SMOKE_DEST:-$DEEPSWE_RUN_DIR/results/smoke/codex-$TASK_ID-$TS}"
mkdir -p "$DEST"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "task=$TASK_ID arms=scaffold,baseline-codex itype=$ITYPE spot region=$REGION"

aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name "$SGN" --description deepswe-codex-smoke --vpc-id $VPC --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null

log "launch spot $ITYPE (${EBS_GB}G gp3)"
IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
  --security-group-ids "$SG" --count 1 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=deepswe-codex-$TASK_ID}]" \
  --query "Instances[0].InstanceId" --output text --region $REGION) || { log "FATAL: run-instances failed"; exit 1; }
log "iid=$IID"

cleanup(){ log "TEARDOWN $IID"
  SIR=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].SpotInstanceRequestId" --output text --region $REGION 2>/dev/null)
  [ -n "${SIR:-}" ] && [ "$SIR" != "None" ] && aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SIR" --region $REGION >/dev/null 2>&1
  aws ec2 terminate-instances --instance-ids "$IID" --region $REGION >/dev/null 2>&1; sleep 6
  aws ec2 delete-security-group --group-id "$SG" --region $REGION 2>/dev/null
  aws ec2 delete-key-pair --key-name "$KEY" --region $REGION 2>/dev/null
  rm -f "$PEM"
  log "torn down"
}
trap cleanup EXIT

aws ec2 wait instance-running --instance-ids "$IID" --region $REGION
IP=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
log "ip=$IP; wait for ssh"
for i in $(seq 50); do $SSH ec2-user@"$IP" "echo up" >/dev/null 2>&1 && break || sleep 5; done

log "bootstrap (docker + compose + pier + node + codex; ~5 min)"
$SSH ec2-user@"$IP" "
  set -e
  mkdir -p ~/deep-swe/tasks ~/deepswe-run ~/.docker/cli-plugins ~/.codex
  sudo shutdown -h +120 || true
  sudo dnf install -y -q docker git jq nodejs npm >/dev/null 2>&1
  sudo systemctl enable --now docker
  sudo chmod 666 /var/run/docker.sock
  curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
  docker compose version >/dev/null || { echo 'FATAL: compose missing'; exit 1; }
  echo 'COMPOSE OK'
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH=\$HOME/.local/bin:\$PATH
  uv tool install --python 3.12 datacurve-pier==0.2.0 >/dev/null 2>&1
  ~/.local/bin/pier --help >/dev/null 2>&1 || { echo 'FATAL: pier'; exit 1; }
  echo 'PIER OK'
  # codex CLI via npm; matches the local install used to validate codex_call.
  sudo npm install -g @openai/codex >/dev/null 2>&1
  codex --version >/dev/null 2>&1 || { echo 'FATAL: codex install'; exit 1; }
  echo 'CODEX OK'
  echo 'BOOTSTRAP DONE'
" 2>&1 | tee "$DEST/bootstrap.log" | tail -8

log "scp codex auth + task + deepswe-run"
scp -q -i "$PEM" -o StrictHostKeyChecking=no \
  "$HOME/.codex/auth.json" ec2-user@"$IP":/home/ec2-user/.codex/auth.json
$SSH ec2-user@"$IP" "chmod 600 ~/.codex/auth.json"
scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
  "$DEEP_SWE_DIR/tasks/$TASK_ID" ec2-user@"$IP":/home/ec2-user/deep-swe/tasks/
rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $PEM" \
  --exclude='results/' --exclude='.git/' --exclude='.venv/' --exclude='__pycache__/' \
  --exclude='external/' --exclude='harness/feature/run/' \
  "$DEEPSWE_RUN_DIR/" ec2-user@"$IP":/home/ec2-user/deepswe-run/

log "push env (no API keys needed — codex subscription via auth.json)"
$SSH ec2-user@"$IP" "cat > ~/.dsr.env" <<EOF
export PATH=\$HOME/.local/bin:\$PATH
export DEEP_SWE_DIR=\$HOME/deep-swe
export DEEPSWE_RUN_DIR=\$HOME/deepswe-run
EOF

log "codex pong-check on box"
$SSH ec2-user@"$IP" "
  source ~/.dsr.env
  codex exec -c model='gpt-5.5' --sandbox read-only --skip-git-repo-check \
    --dangerously-bypass-approvals-and-sandbox -C /tmp --output-last-message /tmp/pong.txt \
    'Reply with exactly the word PONG and nothing else.' >/dev/null 2>&1
  echo PONG_RESULT: \$(cat /tmp/pong.txt 2>/dev/null | head -1)
" 2>&1 | tee -a "$DEST/bootstrap.log" | tail -3

for ARM in scaffold baseline-codex; do
  log "fire run_arm.sh $TASK_ID $ARM"
  $SSH ec2-user@"$IP" "
    source ~/.dsr.env
    cd ~/deepswe-run
    bash harness/run_arm.sh $TASK_ID $ARM 2>&1 | tail -80
    echo ARM_DONE_$ARM
  " 2>&1 | tee "$DEST/arm-$ARM.log" | tail -20

  log "pull receipts for $ARM"
  mkdir -p "$DEST/run/$TASK_ID"
  scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
    "ec2-user@$IP:/home/ec2-user/deepswe-run/results/runs/$TASK_ID/$ARM" \
    "$DEST/run/$TASK_ID/" 2>&1 | tail -3 || log "(scp partial OK)"
done

log "smoke complete; receipts in $DEST"
log "scaffold verdict: $(cat $DEST/run/$TASK_ID/scaffold/failure_class.txt 2>/dev/null || echo MISSING) reward=$(jq -r .reward $DEST/run/$TASK_ID/scaffold/grade.json 2>/dev/null || echo NA)"
log "baseline-codex verdict: $(cat $DEST/run/$TASK_ID/baseline-codex/failure_class.txt 2>/dev/null || echo MISSING) reward=$(jq -r .reward $DEST/run/$TASK_ID/baseline-codex/grade.json 2>/dev/null || echo NA)"
