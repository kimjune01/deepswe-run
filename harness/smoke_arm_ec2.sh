#!/usr/bin/env bash
# smoke_arm_ec2.sh <task-id> <arm> — full arm pipeline on a fresh EC2 spot box.
#
# Validates FREEZE-CHECKLIST §X.3: run_arm.sh runs end-to-end on EC2 box-infra.
# Extends smoke_box.sh (which did dsr grade with gold patch only) by adding
# cursor-agent + google-generativeai installs so model arms can dispatch.

set -uo pipefail
TASK_ID="${1:?usage: smoke_arm_ec2.sh <task-id> <arm>}"
ARM="${2:?usage: smoke_arm_ec2.sh <task-id> <arm>}"
[ "$ARM" = "scaffold" ] || [ "$ARM" = "baseline-comp" ] || [ "$ARM" = "baseline-flash" ] || \
  { echo "FATAL: arm must be scaffold|baseline-comp|baseline-flash"; exit 1; }

REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=150

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"
[ -d "$DEEP_SWE_DIR/tasks/$TASK_ID" ] || { echo "FATAL: task $TASK_ID not in $DEEP_SWE_DIR"; exit 1; }

: "${CURSOR_API_KEY:?must be set; source ~/.zshrc first}"
: "${GEMINI_API_KEY:?must be set; source ~/.zshrc first}"

# PID-suffix prevents keypair name collision when multiple boxes provision in the same
# epoch second (banked 2026-05-29 from multibox smoke v1 — slot1+slot2 fired in the
# same second, both used TS=epoch, slot1 raced and lost CreateKeyPair).
TS=$(date +%s)-$$; KEY=deepswe-armsmoke-$TS; SGN=deepswe-armsmoke-$TS; PEM=/tmp/${KEY}.pem
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $PEM"
DEST="${SMOKE_DEST:-$DEEPSWE_RUN_DIR/results/smoke/arm-$TASK_ID-$ARM}"
mkdir -p "$DEST"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "task=$TASK_ID arm=$ARM itype=$ITYPE spot region=$REGION"

aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name "$SGN" --description deepswe-armsmoke --vpc-id $VPC --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null

log "launch spot $ITYPE (${EBS_GB}G gp3)"
IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
  --security-group-ids "$SG" --count 1 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=deepswe-armsmoke-$TASK_ID-$ARM}]" \
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

log "bootstrap (~6 min)"
$SSH ec2-user@"$IP" "
  set -e
  # Directory layout FIRST so subsequent failures don't break scp+run_arm.sh
  mkdir -p ~/deep-swe/tasks ~/deepswe-run ~/.docker/cli-plugins
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
  # Create a venv with google-generativeai preinstalled; symlink as /usr/local/bin/python3-dsr.
  # gemini_api.py invoked through this python will find google.generativeai. Avoids the
  # uv-managed-Python-has-no-pip issue and the --system flag ambiguity.
  uv venv /home/ec2-user/.dsr-venv --python 3.12 >/dev/null 2>&1
  uv pip install --python /home/ec2-user/.dsr-venv/bin/python google-generativeai >/dev/null 2>&1
  /home/ec2-user/.dsr-venv/bin/python -c 'import google.generativeai' || { echo 'FATAL: genai not importable'; exit 1; }
  sudo ln -sf /home/ec2-user/.dsr-venv/bin/python /usr/local/bin/python3-dsr
  echo 'GENAI OK'
  curl -fsS https://cursor.com/install -o /tmp/cursor-install.sh
  bash /tmp/cursor-install.sh >/dev/null 2>&1 || true
  CA=\$(ls ~/.cursor/bin/cursor-agent 2>/dev/null || ls ~/.local/bin/cursor-agent 2>/dev/null || which cursor-agent 2>/dev/null)
  [ -n \"\$CA\" ] && \$CA --version >/dev/null 2>&1 && echo \"CURSOR-AGENT OK at \$CA\" || { echo 'FATAL: cursor-agent install'; exit 1; }
  echo 'BOOTSTRAP DONE'
" 2>&1 | tee "$DEST/bootstrap.log" | tail -10

log "scp task + deepswe-run"
scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
  "$DEEP_SWE_DIR/tasks/$TASK_ID" ec2-user@"$IP":/home/ec2-user/deep-swe/tasks/
rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $PEM" \
  --exclude='results/' --exclude='.git/' --exclude='.venv/' --exclude='__pycache__/' \
  --exclude='external/' --exclude='harness/feature/run/' \
  "$DEEPSWE_RUN_DIR/" ec2-user@"$IP":/home/ec2-user/deepswe-run/

log "push keys"
$SSH ec2-user@"$IP" "cat > ~/.dsr.env" <<EOF
export CURSOR_API_KEY="$CURSOR_API_KEY"
export GEMINI_API_KEY="$GEMINI_API_KEY"
export PATH=\$HOME/.local/bin:\$HOME/.cursor/bin:\$PATH
export DEEP_SWE_DIR=\$HOME/deep-swe
export DEEPSWE_RUN_DIR=\$HOME/deepswe-run
EOF

log "fire run_arm.sh $TASK_ID $ARM"
$SSH ec2-user@"$IP" "
  source ~/.dsr.env
  cd ~/deepswe-run
  bash harness/run_arm.sh $TASK_ID $ARM 2>&1 | tail -60
  echo ARM_DONE
" 2>&1 | tee "$DEST/arm-run.log" | tail -25

log "pull receipts"
scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
  "ec2-user@$IP:/home/ec2-user/deepswe-run/results/runs/$TASK_ID/$ARM" \
  "$DEST/run/" 2>&1 | tail -3 || log "(scp partial OK)"

log "smoke complete; receipts in $DEST"
ls "$DEST/" 2>/dev/null | head
