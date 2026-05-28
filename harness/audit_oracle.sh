#!/usr/bin/env bash
# Grade every task's GOLDEN solution with its own verifier (oracle agent, $0 model).
# A task whose gold != reward 1 is a defect (PREREGISTRATION §5). Prune after each to bound disk.
set -uo pipefail
ROOT=/Users/junekim/Documents/deepswe
TASKS="$ROOT/deep-swe/tasks"
OUT="$ROOT/submission/results/oracle_audit.jsonl"
mkdir -p "$(dirname "$OUT")"
cd "$ROOT/pier" || exit 1
log(){ echo "[$(date +%H:%M:%S)] $*"; }
total=$(ls "$TASKS" | wc -l | tr -d ' '); i=0
for d in $(ls "$TASKS" | sort); do
  [ -d "$TASKS/$d" ] || continue
  i=$((i+1))
  grep -q "\"task_id\":\"$d\"" "$OUT" 2>/dev/null && { log "($i/$total) $d already done, skip"; continue; }
  img=$(grep -E '^docker_image' "$TASKS/$d/task.toml" | sed -E 's/.*"(.*)".*/\1/')
  start=$(date +%s)
  timeout 2700 pier run -p "$TASKS/$d" --agent oracle --env docker --job-name "oracle-audit-$d" >/dev/null 2>&1
  rc=$?
  rj=$(ls -d jobs/oracle-audit-$d/*/ 2>/dev/null | head -1)
  reward=$(tr -d '[:space:]' < "${rj}verifier/reward.txt" 2>/dev/null)
  secs=$(( $(date +%s) - start ))
  printf '{"task_id":"%s","reward":"%s","rc":%s,"secs":%s}\n' "$d" "${reward:-NA}" "$rc" "$secs" >> "$OUT"
  flag=""; [ "${reward:-NA}" != "1" ] && flag="  <<< DEFECT CANDIDATE (gold != 1)"
  log "($i/$total) $d reward=${reward:-NA} rc=$rc ${secs}s$flag"
  [ -n "$img" ] && docker rmi -f "$img" >/dev/null 2>&1
  docker images --filter "reference=*${d}*" -q 2>/dev/null | xargs -r docker rmi -f >/dev/null 2>&1
  docker image prune -af >/dev/null 2>&1; docker container prune -f >/dev/null 2>&1
done
log "AUDIT DONE: $(grep -c reward "$OUT") graded, $(grep -v '"reward":"1"' "$OUT" | grep -c reward) non-1"
