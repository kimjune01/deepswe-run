#!/usr/bin/env bash
# Runs ON the EC2 box. Gold-grade every deep-swe task via pier oracle ($0, no model).
# Pass 1: parallel (-P10, ~80GB < 128GB box, no oversubscription). Pass 2: re-run every non-1 SEQUENTIALLY to
# rule out resource contention — so an OOM/throttle (rc!=0) can never masquerade as a real
# defect (rc=0, reward=0). The pass-2 verdict is authoritative for those tasks.
set -uo pipefail
export PATH=$HOME/.local/bin:$PATH
cd ~/deep-swe
OUT=~/oracle_audit.jsonl; RERUN=~/oracle_rerun.jsonl
: > "$OUT"; : > "$RERUN"

grade(){  # $1=task  $2=ledger  $3=job-prefix
  local t="$1" led="$2" pfx="$3"; cd ~/deep-swe
  [ -d "tasks/$t" ] || return 0
  local img s rc rj rw
  img=$(grep -E '^docker_image' "tasks/$t/task.toml" | sed -E 's/.*"(.*)".*/\1/')
  s=$(date +%s)
  timeout 1800 pier run -p "tasks/$t" --agent oracle --env docker --job-name "${pfx}-$t" >/dev/null 2>&1
  rc=$?
  rj=$(ls -d jobs/${pfx}-$t/*/ 2>/dev/null | head -1)
  rw=$(tr -d '[:space:]' < "${rj}verifier/reward.txt" 2>/dev/null)
  printf '{"task_id":"%s","reward":"%s","rc":%s,"secs":%s}\n' "$t" "${rw:-NA}" "$rc" "$(( $(date +%s)-s ))" >> "$led"
  local fl=""; [ "${rw:-NA}" != "1" ] && fl=" <<< NON-1 (rc=$rc)"
  echo "$t reward=${rw:-NA} rc=$rc${fl}"
  [ -n "$img" ] && docker rmi -f "$img" >/dev/null 2>&1
  docker images --filter "reference=*${t}*" -q 2>/dev/null | xargs -r docker rmi -f >/dev/null 2>&1
}
export -f grade

echo "=== PASS 1: parallel -P10 ==="
ls tasks | grep -vE '\.json$' | xargs -P10 -I{} bash -c 'grade "$1" ~/oracle_audit.jsonl o {}' _ {}
echo "=== PASS 1 done: graded=$(wc -l < "$OUT") non1=$(grep -vc '"reward":"1"' "$OUT") ==="

echo "=== PASS 2: sequential re-confirm of every non-1 ==="
nonone=$(grep -v '"reward":"1"' "$OUT" | sed -E 's/.*"task_id":"([^"]+)".*/\1/')
if [ -n "$nonone" ]; then
  while IFS= read -r t; do [ -n "$t" ] && grade "$t" "$RERUN" r; done <<< "$nonone"
fi
echo "=== PASS 2 done: reran=$(wc -l < "$RERUN") ==="

# Authoritative: pass-2 verdict for re-run tasks, else pass-1.
echo "=== CONFIRMED DEFECTS (reward!=1 after sequential re-run) ==="
if [ -s "$RERUN" ]; then grep -v '"reward":"1"' "$RERUN" || true; else echo "(none re-run)"; fi
echo "BOX_AUDIT_DONE graded=$(wc -l < "$OUT") confirmed_non1=$(grep -vc '"reward":"1"' "${RERUN:-/dev/null}" 2>/dev/null || echo 0)"
