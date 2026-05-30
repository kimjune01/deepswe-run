#!/usr/bin/env bash
# smoke_multibox_ec2.sh — fire 2 spot boxes concurrently, each running a different
# task × arm. Validates FREEZE-CHECKLIST §X.4: multi-box dispatcher pattern works
# without spot-quota contention, AND the scored run can shard across N boxes
# without serializing on shared state.
#
# Simpler-than-Pro's-coordinator.py shape: each box is independent, no central
# dispatcher needed for the smoke. For the scored run, port Pro's coordinator.py
# for dynamic-dispatch + restart logic. This smoke validates underlying capacity.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"

SLOT1="${SLOT1:-kysely-window-grouping-helpers baseline-comp}"
SLOT2="${SLOT2:-bandit-structured-nosec-directives baseline-comp}"

log(){ echo "[$(date +%H:%M:%S)] $*"; }
log "=== multi-box smoke: 2 concurrent spot boxes ==="
log "slot 1: $SLOT1"
log "slot 2: $SLOT2"

bash "$HERE/smoke_arm_ec2.sh" $SLOT1 > /tmp/multibox-slot1.log 2>&1 &
S1_PID=$!
bash "$HERE/smoke_arm_ec2.sh" $SLOT2 > /tmp/multibox-slot2.log 2>&1 &
S2_PID=$!
log "PIDs: slot1=$S1_PID slot2=$S2_PID"

wait $S1_PID; S1_RC=$?
wait $S2_PID; S2_RC=$?
log "slot1 exit=$S1_RC slot2 exit=$S2_RC"

DEST=$DEEPSWE_RUN_DIR/results/smoke/multibox
mkdir -p $DEST
cp /tmp/multibox-slot1.log $DEST/slot1.log
cp /tmp/multibox-slot2.log $DEST/slot2.log

log "summary:"
for s in slot1 slot2; do
  L=/tmp/multibox-$s.log
  REW_LINE=$(grep -E "scaffold done|baseline-comp done|baseline-flash done" $L 2>/dev/null | tail -1)
  echo "  $s: $REW_LINE"
done
log "multi-box smoke complete; receipts in $DEST"
