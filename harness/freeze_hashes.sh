#!/usr/bin/env bash
# freeze_hashes.sh — compute SHA256 of every frozen artifact (FREEZE-CHECKLIST §II).
#
# Writes frozen/HASHES.txt with one line per file: "<sha256>  <relative-path>".
# Runs in two modes:
#   write:  bash freeze_hashes.sh write   (regenerate frozen/HASHES.txt)
#   check:  bash freeze_hashes.sh check   (assert every hash matches; exit 1 on drift)

set -uo pipefail
MODE="${1:-write}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
HASH_FILE="$HERE/frozen/HASHES.txt"
mkdir -p "$HERE/frozen"

FILES=(
  "skills/build-tools/skill.md"
  "skills/design-doc/skill.md"
  "skills/implement-spec/skill.md"
  "skills/verify-spec/skill.md"
  "skills/compose/skill.md"
  "skills/STANDARD_PROMPTS.md"
  "harness/run_arm.sh"
  "harness/feature/dsr.py"
  "harness/feature/residue_lint.py"
  "harness/feature/gemini_api.py"
  "frozen/eligible.txt"
  "frozen/run_order.txt"
  "frozen/COMPARISONS.txt"
)

compute_one() {
  local rel="$1"
  local abs="$HERE/$rel"
  if [ ! -f "$abs" ]; then
    return 1
  fi
  printf "%s  %s\n" "$(shasum -a 256 "$abs" | awk '{print $1}')" "$rel"
}

case "$MODE" in
  write)
    {
      printf "# frozen-skills SHA256 manifest — generated %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf "# Regenerate via: bash harness/freeze_hashes.sh write\n"
      printf "# Assert via:     bash harness/freeze_hashes.sh check\n"
      printf "# Files: %d\n\n" "${#FILES[@]}"
      for f in "${FILES[@]}"; do
        compute_one "$f" || { echo "FATAL: missing $f" >&2; exit 1; }
      done
    } > "$HASH_FILE"
    echo "wrote $HASH_FILE"
    wc -l "$HASH_FILE"
    ;;
  check)
    [ -f "$HASH_FILE" ] || { echo "FATAL: $HASH_FILE absent — run 'bash freeze_hashes.sh write' first"; exit 1; }
    drift=0
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$line" ]] && continue
      expected_hash="${line%% *}"
      rel="${line##* }"
      actual=$(compute_one "$rel" | awk '{print $1}')
      if [ "$actual" != "$expected_hash" ]; then
        echo "DRIFT  $rel"
        echo "  expected: $expected_hash"
        echo "  actual:   $actual"
        drift=$((drift + 1))
      fi
    done < "$HASH_FILE"
    if [ "$drift" -gt 0 ]; then
      echo "FATAL: $drift file(s) drifted from frozen hashes"
      exit 1
    fi
    echo "OK: all ${#FILES[@]} frozen artifacts match HASHES.txt"
    ;;
  *)
    echo "usage: $0 {write|check}"
    exit 2
    ;;
esac
