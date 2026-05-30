#!/usr/bin/env bash
# kill_box.sh <name> — tear down the box provisioned by setup_box.sh <name>.

set -uo pipefail
NAME="${1:?usage: kill_box.sh <name>}"
ENVF=/tmp/${NAME}.env
[ -f "$ENVF" ] || { echo "no env at $ENVF"; exit 0; }
. "$ENVF"
log(){ echo "[$(date +%H:%M:%S)] [$NAME] $*"; }

log "TEARDOWN $IID"
SIR=$(aws ec2 describe-instances --instance-ids "$IID" \
  --query "Reservations[0].Instances[0].SpotInstanceRequestId" \
  --output text --region $REGION 2>/dev/null)
[ -n "${SIR:-}" ] && [ "$SIR" != "None" ] && \
  aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SIR" --region $REGION >/dev/null 2>&1
aws ec2 terminate-instances --instance-ids "$IID" --region $REGION >/dev/null 2>&1
sleep 6
aws ec2 delete-security-group --group-id "$SG" --region $REGION 2>/dev/null
aws ec2 delete-key-pair --key-name "$KEY" --region $REGION 2>/dev/null
rm -f "/tmp/${KEY}.pem" "$ENVF"
log "torn down"
