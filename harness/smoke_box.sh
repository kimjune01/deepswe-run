#!/usr/bin/env bash
# Thinnest EC2 smoke for DeepSWE. Validates box-side infra ONLY:
#   - AL2023 + docker engine + Compose v2 + buildx
#   - pier install
#   - public ECR image pull
#   - dsr grade with gold patch
# NO model orchestration. NO 3-arm dispatch. That all stays on local containers
# until validated separately. This smoke is the freeze-gate precondition for
# box infra alone.
#
# Provisions ONE m7i.xlarge spot in us-west-2 (independent of Pro's on-demand
# coord fleet). ~$0.10 EC2 total. ~30 min wall.

set -uo pipefail
TASK_ID="${1:-kysely-window-grouping-helpers}"
REGION=us-west-2; AMI=ami-00563078bca04e287; ITYPE=m7i.xlarge; VPC=vpc-02c2ac734b774000f; EBS_GB=120

# --- parameterized source dirs (copied to box; no clone) --------------------
# Override via env: DEEP_SWE_DIR=/path/to/deep-swe DEEPSWE_RUN_DIR=/path/to/deepswe-run
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" 2>/dev/null && pwd)}"
[ -d "$DEEP_SWE_DIR" ] || { echo "FATAL: DEEP_SWE_DIR not found ($DEEP_SWE_DIR); set DEEP_SWE_DIR env"; exit 1; }
[ -d "$DEEP_SWE_DIR/tasks/$TASK_ID" ] || { echo "FATAL: task dir not found ($DEEP_SWE_DIR/tasks/$TASK_ID)"; exit 1; }
[ -f "$DEEPSWE_RUN_DIR/harness/feature/dsr.py" ] || { echo "FATAL: dsr.py not found in $DEEPSWE_RUN_DIR"; exit 1; }

TS=$(date +%s)-$$; KEY=deepswe-boxsmoke-$TS; SGN=deepswe-boxsmoke-$TS; PEM=/tmp/${KEY}.pem
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $PEM"
DEST="${SMOKE_DEST:-$DEEPSWE_RUN_DIR/results/smoke/box}"
mkdir -p "$DEST"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

log "DEEPSWE_RUN_DIR=$DEEPSWE_RUN_DIR"
log "DEEP_SWE_DIR=$DEEP_SWE_DIR"
log "task=$TASK_ID -> $DEST"

log "itype=$ITYPE spot region=$REGION"

# --- keypair + SG ------------------------------------------------------------
aws ec2 create-key-pair --key-name "$KEY" --query KeyMaterial --output text --region $REGION > "$PEM"; chmod 400 "$PEM"
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name "$SGN" --description deepswe-boxsmoke --vpc-id $VPC --query GroupId --output text --region $REGION)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr ${MYIP}/32 --region $REGION >/dev/null

# --- launch spot ------------------------------------------------------------
log "launch spot $ITYPE (${EBS_GB}G gp3)"
IID=$(aws ec2 run-instances --image-id $AMI --instance-type $ITYPE --key-name "$KEY" \
  --security-group-ids "$SG" --count 1 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":${EBS_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=deepswe-boxsmoke-$TASK_ID}]" \
  --query "Instances[0].InstanceId" --output text --region $REGION) || { log "FATAL: run-instances failed"; exit 1; }
log "iid=$IID"

cleanup(){ log "TEARDOWN $IID";
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

# --- bootstrap docker + Compose v2 + pier + clone deep-swe ------------------
log "bootstrap (~5 min)"
$SSH ec2-user@"$IP" "
  set -e
  sudo shutdown -h +60 || true
  sudo dnf install -y -q docker git jq >/dev/null 2>&1
  sudo systemctl enable --now docker
  sudo chmod 666 /var/run/docker.sock

  # AL2023 docker engine ships WITHOUT Compose v2 — pier needs it. Install + ASSERT.
  mkdir -p ~/.docker/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o ~/.docker/cli-plugins/docker-compose && chmod +x ~/.docker/cli-plugins/docker-compose
  docker compose version >/dev/null || { echo 'FATAL: docker compose missing after install'; exit 1; }
  docker buildx version >/dev/null || { echo 'FATAL: docker buildx missing'; exit 1; }
  echo 'COMPOSE+BUILDX OK'

  # pier 0.2.0 requires Python 3.12+ (AL2023 ships 3.11) — use uv to procure both.
  # Banked lesson 2026-05-29: do not substitute system python for uv-tool here.
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH=\$HOME/.local/bin:\$PATH
  uv tool install --python 3.12 datacurve-pier==0.2.0 >/dev/null 2>&1 || { echo 'FATAL: pier install via uv'; exit 1; }
  ~/.local/bin/pier --help >/dev/null 2>&1 || { echo 'FATAL: pier not on PATH after install'; exit 1; }
  echo 'PIER OK'

  # Both repos copied from local (parameterized DEEP_SWE_DIR + DEEPSWE_RUN_DIR).
  # No clone — works without box-side auth, works against uncommitted local changes.
  mkdir -p ~/deep-swe/tasks ~/deepswe-run
  echo 'BOOTSTRAP OK; repos await scp from local'
" 2>&1 | tee "$DEST/bootstrap.log" | tail -8

# --- scp the task dir + deepswe-run (parameterized; no clone) ---------------
log "scp task dir + deepswe-run from local"
# deep-swe is private (datacurve-ai); ship the one task we need.
scp -q -i "$PEM" -o StrictHostKeyChecking=no -r \
  "$DEEP_SWE_DIR/tasks/$TASK_ID" \
  ec2-user@"$IP":/home/ec2-user/deep-swe/tasks/
# deepswe-run: rsync excludes results/, .git, .venv to keep it lean (~hundred KB instead of MB).
rsync -azq -e "ssh -o StrictHostKeyChecking=no -i $PEM" \
  --exclude='results/' --exclude='.git/' --exclude='.venv/' --exclude='__pycache__/' \
  --exclude='external/' --exclude='harness/feature/run/' \
  "$DEEPSWE_RUN_DIR/" \
  ec2-user@"$IP":/home/ec2-user/deepswe-run/
$SSH ec2-user@"$IP" "ls /home/ec2-user/deep-swe/tasks/$TASK_ID | head -3; ls /home/ec2-user/deepswe-run/harness/feature/dsr.py" 2>&1 | tail -5

# --- pull task image ---------------------------------------------------------
log "pull task image (this is the long step — kysely image is ~2GB)"
$SSH ec2-user@"$IP" "
  set -e
  cd ~/deep-swe/tasks/$TASK_ID
  IMG=\$(grep -E '^docker_image' task.toml | head -1 | sed 's/.*= *\"\\(.*\\)\"/\\1/')
  echo \"IMAGE=\$IMG\"
  docker pull \"\$IMG\" 2>&1 | tail -3
  echo 'IMAGE OK'
" 2>&1 | tee "$DEST/image-pull.log" | tail -10

# --- start container + apply gold patch + dsr grade -------------------------
log "start container + apply gold + dsr grade"
$SSH ec2-user@"$IP" "
  set -e
  cd ~/deepswe-run
  export PATH=\$HOME/.local/bin:\$PATH
  # dsr.py is stdlib-only Python, but needs 3.11+ for tomllib. uv-installed 3.12 works.
  PY=\$(uv python find 3.12 2>/dev/null || which python3.12 || which python3.11 || which python3)
  echo \"PYTHON=\$PY\"
  # Start the dsr-managed container for this task
  \$PY harness/feature/dsr.py box $TASK_ID -- 'echo BOX_OK; ls -la /app | head -3' 2>&1 | tail -5
  # Apply the gold patch into /app
  docker cp ~/deep-swe/tasks/$TASK_ID/solution/solution.patch dsr-$TASK_ID:/tmp/gold.patch
  \$PY harness/feature/dsr.py box $TASK_ID -- 'cd /app && git apply --whitespace=nowarn /tmp/gold.patch && git diff --stat | tail -3'
  # Grade
  \$PY harness/feature/dsr.py grade $TASK_ID 2>&1 | tee /tmp/grade.out
  echo 'GRADE DONE'
" 2>&1 | tee "$DEST/grade.log" | tail -40

# --- pull receipts ----------------------------------------------------------
log "pull receipts"
scp -i "$PEM" -o StrictHostKeyChecking=no ec2-user@"$IP":/tmp/grade.out "$DEST/grade.out" 2>&1 | tail -3 || log "(scp grade.out: ok if already in grade.log)"

log "smoke complete; check $DEST/grade.log for reward — expect REWARD 1"
