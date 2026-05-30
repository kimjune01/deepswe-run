#!/usr/bin/env bash
# setup_box.sh <name> — provision ONE spot m7i.xlarge, bootstrap the deepswe-run
# arm-dispatch stack, write /tmp/<name>.env (PUBIP, KEY, IID, SG), and EXIT.
# Caller is responsible for kill_box.sh <name> when done.
#
# Used by harness/coordinator.py as the per-box setup primitive.

set -uo pipefail
NAME="${1:?usage: setup_box.sh <name>}"
REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=150

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"

: "${CURSOR_API_KEY:?must be set; source ~/.zshrc first}"
: "${GEMINI_API_KEY:?must be set; source ~/.zshrc first}"

TS=$(date +%s)-$$-$NAME
KEY=deepswe-coord-$TS; SGN=deepswe-coord-$TS; PEM=/tmp/${KEY}.pem
ENVF=/tmp/${NAME}.env
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $PEM"
log(){ echo "[$(date +%H:%M:%S)] [$NAME] $*"; }

log "provision: keypair + SG"
aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name "$SGN" --description "deepswe-coord-$NAME" --vpc-id $VPC --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null

log "launch spot $ITYPE"
IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
  --security-group-ids "$SG" --count 1 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=deepswe-coord-$NAME}]" \
  --query "Instances[0].InstanceId" --output text --region $REGION) || { log "FATAL: run-instances"; exit 1; }
log "iid=$IID"

aws ec2 wait instance-running --instance-ids "$IID" --region $REGION
IP=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
log "ip=$IP"
for i in $(seq 50); do $SSH ec2-user@"$IP" "echo up" >/dev/null 2>&1 && break || sleep 5; done

log "bootstrap"
$SSH ec2-user@"$IP" "
  set -e
  mkdir -p ~/deep-swe/tasks ~/deepswe-run ~/.docker/cli-plugins
  sudo shutdown -h +240 || true
  sudo dnf install -y -q docker git jq nodejs npm >/dev/null 2>&1
  sudo systemctl enable --now docker
  sudo chmod 666 /var/run/docker.sock
  curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
  docker compose version >/dev/null || { echo 'FATAL: compose'; exit 1; }
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH=\$HOME/.local/bin:\$PATH
  uv tool install --python 3.12 datacurve-pier==0.2.0 >/dev/null 2>&1
  ~/.local/bin/pier --help >/dev/null 2>&1 || { echo 'FATAL: pier'; exit 1; }
  uv venv /home/ec2-user/.dsr-venv --python 3.12 >/dev/null 2>&1
  uv pip install --python /home/ec2-user/.dsr-venv/bin/python google-generativeai >/dev/null 2>&1
  /home/ec2-user/.dsr-venv/bin/python -c 'import google.generativeai' || { echo 'FATAL: genai'; exit 1; }
  sudo ln -sf /home/ec2-user/.dsr-venv/bin/python /usr/local/bin/python3-dsr
  curl -fsS https://cursor.com/install -o /tmp/cursor-install.sh
  bash /tmp/cursor-install.sh >/dev/null 2>&1 || true
  CA=\$(ls ~/.cursor/bin/cursor-agent 2>/dev/null || ls ~/.local/bin/cursor-agent 2>/dev/null)
  [ -n \"\$CA\" ] && \$CA --version >/dev/null 2>&1 || { echo 'FATAL: cursor-agent'; exit 1; }
  echo 'BOOTSTRAP DONE'
" 2>&1 | tail -5

log "rsync deepswe-run"
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

# Per-task scp happens in run_arm.sh via DEEP_SWE_DIR — but coordinator pushes
# individual task dirs on demand. For the smoke we pre-push the full DEEP_SWE
# tasks dir (small total, ~50MB across 113 tasks) so any arm can fire.
log "scp deep-swe tasks (one-shot)"
scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
  "$DEEP_SWE_DIR/tasks" ec2-user@"$IP":/home/ec2-user/deep-swe/

cat > "$ENVF" <<EOF
NAME=$NAME
PUBIP=$IP
KEY=$KEY
IID=$IID
SG=$SG
REGION=$REGION
EOF
log "ENVF=$ENVF READY"
