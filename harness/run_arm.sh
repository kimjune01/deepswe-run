#!/usr/bin/env bash
# run_arm.sh <task_id> <arm> — single arm run on local docker.
#
# Per FREEZE-CHECKLIST §I.b, emits the canonical artifact schema:
#   prompts.jsonl     — every prompt (timestamped, model-ID stamped)
#   responses.jsonl   — every raw model response (timestamped, model-ID stamped)
#   model.patch       — diff against task base commit, source files only
#   audit/            — scaffold only: design-doc, proxy_gate, RESIDUE, adversary reviews
#   grade.json        — reward + base/new pass + exception (from dsr grade)
#   wall.txt          — seconds
#   cost.json         — token counts + estimated dollars per model call
#   env.json          — CLI versions, model IDs, temperature, auth mode
#   failure_class.txt — one value from FREEZE-CHECKLIST §V taxonomy
#
# Arms (FREEZE-CHECKLIST §I, codex review: arms instantiate the treatment, not skill components):
#   scaffold       — design-doc (Flash) → build-tools (Composer) → Phase 3.5 dual-adv → impl-spec (Composer) → grade
#   baseline-comp  — single-agent cursor-agent (composer-2.5) on PRD only → grade
#   baseline-flash — single-agent gemini-cli (gemini-3.5-flash) on PRD only → grade
#
# Container isolation: each arm tears down + recreates the dsr-<task_id> container.
# Workspace: docker cp /app from container to host workdir, run model there, copy back, grade.

set -uo pipefail
TASK_ID="${1:?usage: run_arm.sh <task_id> <arm>}"
ARM="${2:?usage: run_arm.sh <task_id> <arm>}"

# --- parameterized source dirs ----------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
DEEPSWE_RUN_DIR="${DEEPSWE_RUN_DIR:-$(cd "$HERE/.." && pwd)}"
DEEP_SWE_DIR="${DEEP_SWE_DIR:-$(cd "$DEEPSWE_RUN_DIR/../deep-swe" && pwd)}"
DSR="$DEEPSWE_RUN_DIR/harness/feature/dsr.py"
TASK_DIR="$DEEP_SWE_DIR/tasks/$TASK_ID"
[ -f "$TASK_DIR/instruction.md" ] || { echo "FATAL: no $TASK_DIR/instruction.md"; exit 1; }
[ "$ARM" = "scaffold" ] || [ "$ARM" = "baseline-comp" ] || [ "$ARM" = "baseline-flash" ] || \
  { echo "FATAL: arm must be scaffold|baseline-comp|baseline-flash"; exit 1; }

OUT="${OUT_DIR:-$DEEPSWE_RUN_DIR/results/runs/$TASK_ID/$ARM}"
mkdir -p "$OUT/audit"
PROMPTS="$OUT/prompts.jsonl"
RESPONSES="$OUT/responses.jsonl"
: > "$PROMPTS"; : > "$RESPONSES"

# --- API keys + models (auth mode: per-token) -------------------------------
: "${CURSOR_API_KEY:?must be set; source ~/.zshrc first}"
: "${GEMINI_API_KEY:?must be set; source ~/.zshrc first}"

CRAFT_MODEL="${DSR_CRAFT_MODEL:-composer-2.5}"
RECON_MODEL="${DSR_RECON_MODEL:-composer-2.5}"            # was gemini-3.5-flash; amended 2026-05-29 (n=3 head-to-head)
ADVERSARY_MODEL="${DSR_ADVERSARY_MODEL:-gemini-3.5-flash}" # Flash retained as adversary (cross-family preserved)
BREADTH_MODEL="${DSR_ADVERSARY_BREADTH_MODEL:-composer-2.5}"

log(){ echo "[$(date +%H:%M:%S)] $*" >&2; }
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- env.json (FREEZE-CHECKLIST §III) ---------------------------------------
cat > "$OUT/env.json" <<EOF
{
  "task_id": "$TASK_ID",
  "arm": "$ARM",
  "started_at": "$(ts)",
  "gemini_cli_version": "$(gemini --version 2>&1 | head -1 | tr -d '[:space:]')",
  "cursor_agent_version": "$(cursor-agent --version 2>&1 | head -1 | tr -d '[:space:]')",
  "dsr_repo_sha": "$(cd "$DEEPSWE_RUN_DIR" && git rev-parse HEAD 2>/dev/null)",
  "deep_swe_sha": "$(cd "$DEEP_SWE_DIR" && git rev-parse HEAD 2>/dev/null)",
  "craft_model": "$CRAFT_MODEL",
  "recon_model": "$RECON_MODEL",
  "adversary_model": "$ADVERSARY_MODEL",
  "breadth_model": "$BREADTH_MODEL",
  "auth_mode": "per-token",
  "host": "$(hostname)"
}
EOF

# --- record helpers --------------------------------------------------------
record_prompt(){  # role model prompt-text
  local role="$1" model="$2" text="$3"
  python3 -c "
import json, sys
print(json.dumps({'ts': '$(ts)', 'role': '$role', 'model': '$model', 'prompt': sys.stdin.read()}))
" <<<"$text" >> "$PROMPTS"
}
record_response(){  # role model response-text
  local role="$1" model="$2"
  python3 -c "
import json, sys
print(json.dumps({'ts': '$(ts)', 'role': '$role', 'model': '$model', 'response': sys.stdin.read()}))
" >> "$RESPONSES"
}

T0=$(date +%s)

# --- ensure FRESH container (arm isolation per FREEZE-CHECKLIST §I.f) -------
log "tearing down any prior dsr-$TASK_ID container"
docker rm -f "dsr-$TASK_ID" >/dev/null 2>&1 || true
log "starting fresh container"
python3 "$DSR" box "$TASK_ID" -- "echo BOX_OK" >/dev/null 2>&1 || { echo INFRA_DOCKER > "$OUT/failure_class.txt"; exit 2; }

# --- host workspace mirror /app --------------------------------------------
WORK="${WORK_DIR:-/tmp/arm-$TASK_ID-$ARM-$$}"
rm -rf "$WORK"; mkdir -p "$WORK"
log "mirroring /app to $WORK"
docker cp "dsr-$TASK_ID:/app/." "$WORK/" || { echo INFRA_DOCKER > "$OUT/failure_class.txt"; exit 2; }
BASE_SHA=$(cd "$WORK" && git rev-parse HEAD)

# --- the three arms --------------------------------------------------------
PRD=$(cat "$TASK_DIR/instruction.md")

case "$ARM" in
  scaffold)
    # ===== Phase 1: design-doc (Composer, recon — amended 2026-05-29) =====
    # BRANCH-slot is the project's decision-tree branch (1/2/3/4), NOT a git branch name.
    # Tightened prompt schema to prevent the Flash + Composer git-branch confusion observed
    # in the n=3 recon comparison (both models defaulted to git-branch reading without the
    # explicit definition).
    log "[scaffold] design-doc via $RECON_MODEL"
    DDP="Read this PRD and produce a brief design doc using EXACTLY this schema (no other prose outside the schema):

\`\`\`
FEATURE-SHAPE: <one of: enum | invariant | mixed>
FEATURE-TYPE: <one of: additive | subtractive | transform | filter | selector | optimizer>
BRANCH: <one of: 1 (preserve-existing) | 2 (narrow-the-transform) | 3 (complete-the-isolated-surface) | 4 (never-cross-a-hard-boundary)>

TYPED-INTERFACE-SURFACE:
- <pre-existing types/functions the impl will touch>

PRD-HARD-NEGATIVES:
- <things the PRD plainly forbids — input shapes that must NOT change behavior>

ACCEPTANCE-CRITERIA:
1. <testable behavior, one per line, PRD-quoted where possible>
2. ...

RESIDUE (AMBIGUOUS):
- <PRD clauses that admit multiple readings; build-tools will route these to RESIDUE.md>
\`\`\`

PRD:
$PRD"
    record_prompt "design-doc" "$RECON_MODEL" "$DDP"
    DD_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$RECON_MODEL" "$DDP" 2>/dev/null)
    echo "$DD_OUT" > "$OUT/audit/design-doc.md"
    echo "$DD_OUT" | record_response "design-doc" "$RECON_MODEL"

    # ===== Phase 2: build-tools (Composer, author) =====
    log "[scaffold] build-tools (proxy gate) via $CRAFT_MODEL"
    BTP="You are build-tools. Read this PRD + design doc and emit a proxy gate (test file) that tests the PRD's behaviors. Apply: PRD-quote per test, axis-crossing inputs, boundary clauses, # RESIDUE: at file head for SPECULATION. Output one fenced code block.

PRD:
$PRD

DESIGN DOC:
$DD_OUT"
    record_prompt "build-tools" "$CRAFT_MODEL" "$BTP"
    PG_OUT=$(echo "$BTP" | CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$CRAFT_MODEL" 2>/dev/null)
    echo "$PG_OUT" > "$OUT/audit/proxy_gate-raw.txt"
    echo "$PG_OUT" | record_response "build-tools" "$CRAFT_MODEL"

    # ===== Phase 3.5: dual adversary (Flash for soundness + Composer for breadth) =====
    # Cross-family preserved here: $ADVERSARY_MODEL (Flash) is a different family from
    # $CRAFT_MODEL/$RECON_MODEL (Composer/Kimi-base). This is where H₉'s cross-family
    # complementarity earns its tokens (37.9% bandit / 11.5% kysely overlap, both << 70%).
    log "[scaffold] Phase 3.5 dual adversary (Flash soundness + Composer breadth)"
    AP="Adversary review (3 asks): soundness | discrimination | missing coverage. Number findings F1..; end with COUNT: N.

PRD:
$PRD

PROXY GATE:
$PG_OUT"
    record_prompt "adversary-flash" "$ADVERSARY_MODEL" "$AP"
    record_prompt "adversary-breadth" "$BREADTH_MODEL" "$AP"
    python3 "$DEEPSWE_RUN_DIR/harness/feature/gemini_api.py" -m "$ADVERSARY_MODEL" --prompt "$AP" > "$OUT/audit/adv-flash.txt" 2>/dev/null &
    FA_PID=$!
    echo "$AP" | CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$BREADTH_MODEL" > "$OUT/audit/adv-composer.txt" 2>/dev/null &
    CA_PID=$!
    wait $FA_PID $CA_PID
    cat "$OUT/audit/adv-flash.txt" | record_response "adversary-flash" "$ADVERSARY_MODEL"
    cat "$OUT/audit/adv-composer.txt" | record_response "adversary-breadth" "$BREADTH_MODEL"

    # RESIDUE.md (synthetic for smoke: capture SPECULATION-typed findings; real
    # implementation has Composer/Flash type-classify themselves. For smoke we
    # just stub a minimal residue from the volume of findings.)
    {
      echo "# RESIDUE — SPECULATION-typed findings carried forward to Phase 4"
      echo "# Phase 3.5 dual-adversary on $TASK_ID, $(ts)"
      echo "(For smoke: synthetic minimal residue; production version has each finding typed.)"
    } > "$OUT/audit/RESIDUE.md"

    # ===== residue-lint (FREEZE-CHECKLIST §VII contamination check) =====
    log "[scaffold] residue-lint"
    if ! python3 "$DSR" residue-lint "$OUT/audit/RESIDUE.md" >/dev/null 2>&1; then
      log "[scaffold] residue-lint FAILED — halting"
      echo INFRA_RESIDUE_LINT > "$OUT/failure_class.txt"
      docker rm -f "dsr-$TASK_ID" >/dev/null 2>&1
      exit 2
    fi

    # ===== Phase 5: implement-spec (Composer-craft, workspace = $WORK) =====
    log "[scaffold] implement-spec via $CRAFT_MODEL in $WORK"
    ISP="Implement the feature from the PRD below. Edit files in this workspace directly. The workspace is a git repo at base $BASE_SHA — only source files should be modified.

PRD:
$PRD

DESIGN DOC (your prior reasoning):
$DD_OUT"
    record_prompt "implement-spec" "$CRAFT_MODEL" "$ISP"
    cd "$WORK"
    IMPL_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$CRAFT_MODEL" "$ISP" 2>&1)
    cd - >/dev/null
    echo "$IMPL_OUT" | record_response "implement-spec" "$CRAFT_MODEL"
    ;;

  baseline-comp)
    log "[baseline-comp] cursor-agent --model $CRAFT_MODEL in $WORK"
    BCP="Implement the feature from this PRD. Edit files in this workspace directly. The workspace is a git repo at base $BASE_SHA — only source files should be modified.

PRD:
$PRD"
    record_prompt "baseline-impl" "$CRAFT_MODEL" "$BCP"
    cd "$WORK"
    BC_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$CRAFT_MODEL" "$BCP" 2>&1)
    cd - >/dev/null
    echo "$BC_OUT" | record_response "baseline-impl" "$CRAFT_MODEL"
    ;;

  baseline-flash)
    # Use gemini_api.py direct shim (NOT gemini-cli) — single API request, no
    # workspace exploration. Banked from 2026-05-29: gemini-cli's -p+plan-mode reads
    # files via tool calls, which on kysely's 800MB workspace exceeded 17 min.
    # Per the baseline-flash arm, the model identity is gemini-3.5-flash regardless
    # of the recon/adversary model assignments (baseline arms use single agents).
    BASELINE_FLASH_MODEL="gemini-3.5-flash"
    log "[baseline-flash] gemini_api.py -m $BASELINE_FLASH_MODEL on PRD"
    BFP="Implement the feature from this PRD. Output a SINGLE unified git diff against the current workspace, wrapped in one fenced \`\`\`diff block. Use 'a/' and 'b/' path prefixes as git produces. Modify only source files; do not touch tests/, configuration files, or generated artifacts. No prose outside the block.

PRD:
$PRD"
    record_prompt "baseline-impl" "$BASELINE_FLASH_MODEL" "$BFP"
    GEMINI_API="$DEEPSWE_RUN_DIR/harness/feature/gemini_api.py"
    BF_OUT=$(python3 "$GEMINI_API" -m "$BASELINE_FLASH_MODEL" --prompt "$BFP" 2>&1)
    echo "$BF_OUT" | record_response "baseline-impl" "$BASELINE_FLASH_MODEL"
    # Extract fenced diff block. Path OUTSIDE $WORK so the temp file never ends up
    # in git diff --cached after git add -A (banked from earlier leak bug).
    DIFF_PATH="$OUT/baseline-flash-extracted.diff"
    python3 -c "
import re, sys
text = sys.stdin.read()
m = re.search(r'\`\`\`diff\n(.*?)\n\`\`\`', text, re.S)
sys.stdout.write(m.group(1) if m else '')
" <<<"$BF_OUT" > "$DIFF_PATH"
    if [ -s "$DIFF_PATH" ]; then
      (cd "$WORK" && git apply --whitespace=nowarn "$DIFF_PATH" 2>&1) > "$OUT/baseline-flash-apply.log"
    else
      log "[baseline-flash] no diff block found in response (kept extracted.diff for inspection)"
    fi
    ;;
esac

# --- capture model.patch from workspace -------------------------------------
log "capture model.patch"
cd "$WORK"
git add -A
git diff --cached > "$OUT/model.patch"
PATCH_BYTES=$(wc -c < "$OUT/model.patch")
log "model.patch: $PATCH_BYTES bytes"
cd - >/dev/null

# --- patch-capture sanity (FREEZE-CHECKLIST §I.e): only source-file changes -
# A weak check: model.patch should not modify the test.patch or tests/* files
# (which are the hidden grader). Stronger check goes in dsr grade.
if grep -qE '^diff --git a/(tests/test\.patch|tests/test\.sh)' "$OUT/model.patch" 2>/dev/null; then
  log "PATCH-CAPTURE-SANITY FAIL: model.patch touches grader files"
  echo INFRA_PARSE > "$OUT/failure_class.txt"
  docker rm -f "dsr-$TASK_ID" >/dev/null 2>&1
  exit 2
fi

# --- push workspace back into container + grade -----------------------------
log "push workspace back into container"
docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null

log "dsr grade"
python3 "$DSR" grade "$TASK_ID" > "$OUT/grade.txt" 2>&1
REWARD=$(grep -oE 'REWARD [01]' "$OUT/grade.txt" | head -1 | awk '{print $2}')
BASE_PASS=$(grep -c 'base.*pass' "$OUT/grade.txt" || true)
NEW_PASS=$(grep -c 'new.*pass' "$OUT/grade.txt" || true)
EXCEPTION=$(grep -E 'FATAL|exception' "$OUT/grade.txt" | head -1 | tr -d '\n')

cat > "$OUT/grade.json" <<EOF
{
  "reward": ${REWARD:-null},
  "base_pass": $([ "$BASE_PASS" -gt 0 ] && echo true || echo false),
  "new_pass": $([ "$NEW_PASS" -gt 0 ] && echo true || echo false),
  "exception": "$EXCEPTION",
  "model_patch_bytes": $PATCH_BYTES
}
EOF

# --- failure_class (FREEZE-CHECKLIST §V) ------------------------------------
# The model.patch bytes alone don't disambiguate "model gave no diff" from
# "model gave a diff that didn't apply." Check for an apply-log with errors.
EXTRACTED_DIFF="$OUT/baseline-flash-extracted.diff"
APPLY_LOG="$OUT/baseline-flash-apply.log"
APPLY_FAILED=""
if [ -f "$APPLY_LOG" ] && grep -qE "error|fatal|corrupt|fail" "$APPLY_LOG" 2>/dev/null; then
  APPLY_FAILED=1
fi

if [ "${REWARD:-}" = "1" ]; then
  echo RESOLVED > "$OUT/failure_class.txt"
elif [ -n "$EXCEPTION" ]; then
  echo EVALUATOR_ERROR > "$OUT/failure_class.txt"
elif [ -n "$APPLY_FAILED" ]; then
  echo INFRA_PARSE > "$OUT/failure_class.txt"  # model output looked like a diff but didn't apply
elif [ "$PATCH_BYTES" -eq 0 ]; then
  echo UNRESOLVED_NO_DIFF > "$OUT/failure_class.txt"
else
  echo UNRESOLVED_MODEL > "$OUT/failure_class.txt"
fi

# --- wall + teardown --------------------------------------------------------
echo "$(($(date +%s) - T0))" > "$OUT/wall.txt"

log "teardown container"
docker rm -f "dsr-$TASK_ID" >/dev/null 2>&1
rm -rf "$WORK"

log "=== $ARM done: reward=${REWARD:-NA} class=$(cat $OUT/failure_class.txt) wall=$(cat $OUT/wall.txt)s ==="
cat "$OUT/grade.json"
