#!/usr/bin/env bash
# Provision ONE spot m7i.8xlarge (32 vCPU/128GB, separate spot quota -> does not touch Pro's
# on-demand fleet), bootstrap docker+pier+deep-swe, run the gold-patch defect audit ($0 model),
# stream results, collect, and self-terminate (EXIT trap + +60min shutdown backstop).
set -uo pipefail
REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.8xlarge; VPC=vpc-02c2ac734b774000f
TS=$(date +%s); KEY=deepswe-oracle-$TS; SGN=deepswe-oracle-$TS; PEM=/tmp/${KEY}.pem
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $PEM"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST=/Users/junekim/Documents/deepswe/deepswe-run/results/oracle_audit_ec2.jsonl
log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "keypair + SG (ssh from this IP only)"
aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name "$SGN" --description deepswe-oracle --vpc-id $VPC --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null

log "launch spot $ITYPE (800G gp3)"
IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
  --security-group-ids "$SG" --count 1 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":800,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=deepswe-oracle}]" \
  --query "Instances[0].InstanceId" --output text --region $REGION) || { log "FATAL: run-instances failed"; exit 1; }
log "iid=$IID"
cleanup(){ log "TEARDOWN $IID";
  # cancel the spot request first — a one-time request lingers 'active' after the instance dies and
  # keeps counting against the spot limit (caused MaxSpotInstanceCountExceeded on a same-size relaunch).
  SIR=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].SpotInstanceRequestId" --output text --region $REGION 2>/dev/null)
  [ -n "${SIR:-}" ] && [ "$SIR" != "None" ] && aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SIR" --region $REGION >/dev/null 2>&1
  aws ec2 terminate-instances --instance-ids "$IID" --region $REGION >/dev/null 2>&1; sleep 6;
  aws ec2 delete-security-group --group-id "$SG" --region $REGION 2>/dev/null; aws ec2 delete-key-pair --key-name "$KEY" --region $REGION 2>/dev/null; log "torn down"; }
trap cleanup EXIT

aws ec2 wait instance-running --instance-ids "$IID" --region $REGION
IP=$(aws ec2 describe-instances --instance-ids "$IID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)
log "ip=$IP; wait for ssh"
for i in $(seq 50); do $SSH ec2-user@"$IP" "echo up" >/dev/null 2>&1 && break || sleep 5; done

log "bootstrap docker + uv + pier + clone deep-swe"
$SSH ec2-user@"$IP" "
  set -e
  sudo shutdown -h +60 || true
  sudo dnf install -y -q docker git >/dev/null 2>&1
  sudo systemctl enable --now docker
  sudo chmod 666 /var/run/docker.sock
  # AL2023 'docker' ships the engine WITHOUT the Compose v2 plugin, which pier needs to bring up
  # the sandbox + egress-proxy. Install it into cli-plugins, then ASSERT (loud fail, not silent NA).
  mkdir -p ~/.docker/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
  docker compose version >/dev/null 2>&1 || { echo 'FATAL: docker compose plugin missing after install'; exit 1; }
  docker buildx version >/dev/null 2>&1 || { echo 'FATAL: docker buildx missing'; exit 1; }
  command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH=\$HOME/.local/bin:\$PATH
  uv tool install datacurve-pier >/dev/null 2>&1
  ~/.local/bin/pier --version
  git clone -q https://github.com/datacurve-ai/deep-swe.git ~/deep-swe
  echo BOOT_OK ntasks=\$(ls ~/deep-swe/tasks | grep -vcE '\.json\$')
" || { log "FATAL: bootstrap failed"; exit 1; }

log "push box_audit.sh + run (streaming per-task results)"
scp -o StrictHostKeyChecking=no -i "$PEM" "$HERE/box_audit.sh" ec2-user@"$IP":~/box_audit.sh >/dev/null
$SSH ec2-user@"$IP" "bash ~/box_audit.sh"

log "collect ledgers"
scp -o StrictHostKeyChecking=no -i "$PEM" ec2-user@"$IP":~/oracle_audit.jsonl "$DEST" >/dev/null 2>&1 && log "wrote $DEST"
scp -o StrictHostKeyChecking=no -i "$PEM" ec2-user@"$IP":~/oracle_rerun.jsonl "${DEST%.jsonl}_rerun.jsonl" >/dev/null 2>&1
log "AUDIT COMPLETE — cleanup on exit"
