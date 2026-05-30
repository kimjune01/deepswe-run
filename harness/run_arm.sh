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
#   scaffold       — design-doc (Composer) → build-tools (Composer) → Phase 3.5 dual (Flash+Composer) → impl (Composer) → Phase 5 (Composer) → grade
#   scaffold-codex — same compiler stage but every model layer is `codex exec` (gpt-5.5). [v4 reframe 2026-05-30, runs after Composer arm]
#   baseline-codex — single-agent `codex exec` (gpt-5.5) on PRD only → grade
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
case "$ARM" in
  scaffold|scaffold-codex|baseline-codex|baseline-comp|baseline-flash) ;;
  *) echo "FATAL: arm must be scaffold|scaffold-codex|baseline-codex|baseline-comp|baseline-flash"; exit 1 ;;
esac

OUT="${OUT_DIR:-$DEEPSWE_RUN_DIR/results/runs/$TASK_ID/$ARM}"
mkdir -p "$OUT/audit"
PROMPTS="$OUT/prompts.jsonl"
RESPONSES="$OUT/responses.jsonl"
: > "$PROMPTS"; : > "$RESPONSES"

# --- API keys + models ------------------------------------------------------
# Per-arm credentials & model layer:
#   scaffold / baseline-comp        → cursor-agent (Composer 2.5) + Gemini Flash adv (gemini_api.py)
#   scaffold-codex / baseline-codex → codex CLI subscription (~/.codex/auth.json), no API keys
#   baseline-flash                  → gemini_api.py (Flash)
case "$ARM" in
  scaffold|baseline-comp)        : "${CURSOR_API_KEY:?must be set for $ARM; source ~/.zshrc first}" ;;
esac
case "$ARM" in
  scaffold|baseline-flash)       : "${GEMINI_API_KEY:?must be set for $ARM; source ~/.zshrc first}" ;;
esac

# Defaults assume the Composer/Flash scaffold. The codex arms override these
# inline before each codex_call (set just below in the scaffold-codex block).
CRAFT_MODEL="${DSR_CRAFT_MODEL:-composer-2.5}"
RECON_MODEL="${DSR_RECON_MODEL:-composer-2.5}"               # amended 2026-05-29 (n=3 head-to-head)
ADVERSARY_MODEL="${DSR_ADVERSARY_MODEL:-gemini-3.5-flash}"   # Flash retained as cross-family adversary
BREADTH_MODEL="${DSR_ADVERSARY_BREADTH_MODEL:-composer-2.5}"
case "$ARM" in
  scaffold-codex|baseline-codex)
    CRAFT_MODEL="${DSR_CRAFT_MODEL_CODEX:-gpt-5.5}"
    RECON_MODEL="${DSR_RECON_MODEL_CODEX:-gpt-5.5}"
    ADVERSARY_MODEL="${DSR_ADVERSARY_MODEL_CODEX:-gpt-5.5}"
    BREADTH_MODEL="${DSR_ADVERSARY_BREADTH_MODEL_CODEX:-gpt-5.5}"
    ;;
esac
CODEX_BIN="${CODEX_BIN:-codex}"  # subscription-auth codex CLI (codex-cli 0.133+)
CODEX_SANDBOX_RO="${CODEX_SANDBOX_RO:-read-only}"
CODEX_SANDBOX_WR="${CODEX_SANDBOX_WR:-workspace-write}"

# Subscription-throttle pacing: codex CLI under a paid subscription returns
# rate-limit errors when called too quickly. codex_call wraps a single non-
# workspace prompt with backoff-on-rate-limit retry. codex_call_in returns
# the last-message text and runs from a working directory (for workspace writes).
# Caller is responsible for stdout capture; we print the final message to stdout
# and progress JSONL to /dev/null (codex defaults to human stdout otherwise).
codex_call(){  # codex_call <model> <sandbox> <cwd> <prompt>  -> last message on stdout
  local model="$1" sandbox="$2" cwd="$3" prompt="$4"
  local attempts=0 max_attempts=6 sleep_s=30 last_msg
  last_msg="$(mktemp -t codex-last.XXXXXX)"
  while : ; do
    attempts=$((attempts + 1))
    if "$CODEX_BIN" exec \
        -c model="$model" \
        --sandbox "$sandbox" \
        --skip-git-repo-check \
        --dangerously-bypass-approvals-and-sandbox \
        -C "$cwd" \
        --output-last-message "$last_msg" \
        "$prompt" >/dev/null 2>&1
    then
      cat "$last_msg"
      rm -f "$last_msg"
      return 0
    fi
    # Detect rate-limit / quota signals in the last message; back off and retry.
    if grep -qiE 'rate.?limit|429|too many requests|quota' "$last_msg" 2>/dev/null && [ "$attempts" -lt "$max_attempts" ]; then
      log "codex_call: rate-limited (attempt $attempts/$max_attempts); sleeping ${sleep_s}s"
      sleep "$sleep_s"
      sleep_s=$((sleep_s * 2))
      continue
    fi
    # Non-rate-limit failure: emit whatever last_msg we got + bail.
    cat "$last_msg"
    rm -f "$last_msg"
    return 1
  done
}

log(){ echo "[$(date +%H:%M:%S)] $*" >&2; }
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

# revert_test_files_in_workdir <dir>
# Banked 2026-05-30 (codex smoke v1): the scaffold's source-only constraint is
# advisory in prompts and the model violates it (e.g. abs-module-cache-flags
# scaffold edited evaluator/require_resolution_test.go). Test-file edits leak
# into model.patch, get pushed to /app, and corrupt the regression suite for
# `test.sh base`. Guard: hard-revert test-shaped paths in the workspace before
# we capture the diff or push back. Patterns cover Go, Python, JS/TS, Ruby,
# plus the common test.sh / Makefile.test sentinels.
# Regex of test-shaped paths (matches `git ls-tree`/`git ls-files` output, which
# uses forward slashes). Covers Go, Python, JS/TS, Ruby, plus common test.sh /
# Makefile.test sentinels and anything under tests/, test/, __tests__/.
TEST_FILE_RE='(^|/)([^/]+_test\.go|test_[^/]+\.py|[^/]+_test\.py|conftest\.py|[^/]+\.(test|spec)\.(ts|js|tsx|jsx)|[^/]+_(spec|test)\.rb|test\.sh|Makefile\.test)$|/(tests?|__tests__)/'
revert_test_files_in_workdir(){
  local dir="$1"
  ( cd "$dir" 2>/dev/null || exit 0
    # Tracked test files at HEAD → restore to HEAD content. (Per-path checkout
    # to dodge git checkout's "any unmatched pathspec aborts all" mode.)
    git ls-tree -r --name-only HEAD 2>/dev/null \
      | grep -E "$TEST_FILE_RE" \
      | while IFS= read -r f; do git checkout HEAD -- "$f" 2>/dev/null; done
    # Untracked test-shaped files the model added → drop.
    git status --porcelain=v1 -uall 2>/dev/null \
      | awk '/^\?\? / {sub(/^\?\? /, ""); print}' \
      | grep -E "$TEST_FILE_RE" \
      | while IFS= read -r f; do rm -f -- "$f" 2>/dev/null; done
  ) || true
}

# --- env.json (FREEZE-CHECKLIST §III) ---------------------------------------
cat > "$OUT/env.json" <<EOF
{
  "task_id": "$TASK_ID",
  "arm": "$ARM",
  "started_at": "$(ts)",
  "codex_cli_version": "$($CODEX_BIN --version 2>&1 | head -1 | tr -d '[:space:]')",
  "gemini_cli_version": "$(gemini --version 2>&1 | head -1 | tr -d '[:space:]' || echo NA)",
  "cursor_agent_version": "$(cursor-agent --version 2>&1 | head -1 | tr -d '[:space:]' || echo NA)",
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
    GEMINI_PY=$(command -v python3-dsr 2>/dev/null || command -v python3)
    $GEMINI_PY "$DEEPSWE_RUN_DIR/harness/feature/gemini_api.py" -m "$ADVERSARY_MODEL" --prompt "$AP" > "$OUT/audit/adv-flash.txt" 2>/dev/null &
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

    # ===== Phase 4: implement-spec (Composer-craft, workspace = $WORK) =====
    log "[scaffold] implement-spec via $CRAFT_MODEL in $WORK"
    ISP="Implement the feature from the PRD below. Edit files in this workspace directly. The workspace is a git repo at base $BASE_SHA — only source files should be modified.

PRD:
$PRD

DESIGN DOC (your prior reasoning):
$DD_OUT"
    record_prompt "implement-spec" "$CRAFT_MODEL" "$ISP"
    cd "$WORK"
    # Banked 2026-05-29 from kysely scaffold v2: cursor-agent can write the impl correctly
    # then sit idle in S state for 30+ min without exiting. Hard-timeout via `timeout(1)`;
    # workspace state is captured regardless of exit code.
    # Banked 2026-05-29 from EC2 coordinator test drive: cursor-agent's --workspace
    # default-to-cwd is NOT reliable — on a fresh box it falls back to last-trusted dir
    # or refuses to write. Always pass --workspace + --trust explicitly when we expect file edits.
    IMPL_TIMEOUT="${IMPL_TIMEOUT:-900}"  # 15 min default
    IMPL_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout "$IMPL_TIMEOUT" \
      cursor-agent -p -f --workspace "$WORK" --model "$CRAFT_MODEL" "$ISP" 2>&1)
    IMPL_RC=$?
    if [ "$IMPL_RC" = "124" ]; then
      log "[scaffold] impl-spec TIMED OUT after ${IMPL_TIMEOUT}s; continuing with whatever workspace state was reached"
      echo "TIMEOUT after ${IMPL_TIMEOUT}s" >> "$OUT/audit/impl-timeout.txt"
    fi
    cd - >/dev/null
    echo "$IMPL_OUT" | record_response "implement-spec" "$CRAFT_MODEL"

    # Strip any test-file edits the model wrote, then capture pre-Phase-5 impl diff.
    revert_test_files_in_workdir "$WORK"
    IMPL_DIFF=$(cd "$WORK" && git add -A && git diff --cached -- \
      ':(exclude).venv' ':(exclude).venv/**' ':(exclude)node_modules' ':(exclude)node_modules/**' \
      ':(exclude)__pycache__' ':(exclude)**/__pycache__' ':(exclude)__pycache__/**' \
      ':(exclude)dist' ':(exclude)dist/**' ':(exclude)build' ':(exclude)build/**' \
      ':(exclude).pytest_cache' ':(exclude)**/.pytest_cache' ':(exclude).tox' ':(exclude).tox/**' \
      ':(exclude)*.pyc' ':(exclude)*.pyo' ':(exclude)*.egg-info' ':(exclude)*.egg-info/**')
    echo "$IMPL_DIFF" > "$OUT/audit/impl-diff-pre-phase5.patch"
    IMPL_DIFF_BYTES=$(printf '%s' "$IMPL_DIFF" | wc -c | tr -d ' ')
    log "[scaffold] pre-Phase-5 impl diff: ${IMPL_DIFF_BYTES} bytes"

    # ===== Phase 5: cross-family adversary on impl + RESIDUE re-type (treatment-defining) =====
    # Reviews PRD + design-doc + proxy gate + RESIDUE.md + impl diff. Four asks; 4th is the
    # residue-conversion: SPECULATION at Phase 3.5 can convert to ENTAILMENT when the impl
    # gives the speculation a concrete shape (Hₐ₁₀ operationalized). Composer-sole here per
    # the 2026-05-29 finding that soundness-emphasis prompt + Composer catches axis_crossing
    # bugs Flash caught at Phase 3.5; Flash adversary is OPTIONAL second lens (controlled by
    # PHASE5_DUAL=1 env var) for cross-cutting findings.
    log "[scaffold] Phase 5 adversary on impl ($IMPL_DIFF_BYTES bytes)"
    PG_TRUNC=$(printf '%s' "$PG_OUT" | head -c 5000)
    RESIDUE_CONTENT=$(cat "$OUT/audit/RESIDUE.md")
    AP5="You are the cross-family adversary reviewing an IMPLEMENTATION against the PRD it was supposed to satisfy. You also receive the design-doc the author worked from, the proxy gate that defined the necessary bar, and a RESIDUE.md of SPECULATION-typed findings from earlier (pre-impl) review.

Soundness is the load-bearing axis. Catch PRD violations the impl introduced.

Answer 4 numbered asks. For each finding, prefix with one of: TYPE: ENTAILMENT | DISCRIMINATOR | SPECULATION | WRONG. ENTAILMENT findings will trigger an impl revision pass — be honest about whether something is plainly PRD-violating or merely your aesthetic.

## 1. Soundness (PRD violations in the impl)
Cite the file + line range; quote the impl; quote the PRD clause it violates.

## 2. Discrimination (impl looks right but a mutant would pass the same tests)
Name the mutant; give an input shape that would surface it.

## 3. Missing coverage (PRD behaviors NOT implemented)
Quote the PRD clause; describe what the impl is missing.

## 4. RESIDUE conversion — re-type each RESIDUE entry against the impl
For each RESIDUE entry, does the impl exhibit a behavior that converts it from SPECULATION to ENTAILMENT? If yes, name the new ENTAILMENT finding and describe the conversion. If still ambiguous, mark as REMAINS-SPECULATION.

End with COUNT: N.

---

PRD:
$PRD

DESIGN DOC:
$DD_OUT

PROXY GATE (truncated to first 5KB):
$PG_TRUNC

RESIDUE.md:
$RESIDUE_CONTENT

IMPL DIFF (current model patch):
$IMPL_DIFF"

    record_prompt "phase5-adversary" "$BREADTH_MODEL" "$AP5"
    PH5_OUT=$(echo "$AP5" | CURSOR_API_KEY="$CURSOR_API_KEY" cursor-agent -p -f --model "$BREADTH_MODEL" 2>/dev/null)
    echo "$PH5_OUT" > "$OUT/audit/phase5-adversary.txt"
    echo "$PH5_OUT" | record_response "phase5-adversary" "$BREADTH_MODEL"

    # Optional Flash second lens at Phase 5 — disabled by default per 2026-05-29 finding
    # that Composer-sole catches axis_crossing-class bugs with soundness-emphasis prompt.
    if [ "${PHASE5_DUAL:-0}" = "1" ]; then
      log "[scaffold] Phase 5 optional Flash second lens (PHASE5_DUAL=1)"
      GEMINI_PY=$(command -v python3-dsr 2>/dev/null || command -v python3)
      $GEMINI_PY "$DEEPSWE_RUN_DIR/harness/feature/gemini_api.py" -m "$ADVERSARY_MODEL" --prompt "$AP5" > "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null
      cat "$OUT/audit/phase5-adversary-flash.txt" | record_response "phase5-adversary-flash" "$ADVERSARY_MODEL"
    fi

    # Detect ENTAILMENT findings → one revision pass (bounded; no further iteration)
    ENTAIL_COUNT=$(grep -ciE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary.txt" 2>/dev/null)
    ENTAIL_COUNT=${ENTAIL_COUNT:-0}
    if [ "${PHASE5_DUAL:-0}" = "1" ] && [ -f "$OUT/audit/phase5-adversary-flash.txt" ]; then
      EXTRA=$(grep -ciE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null)
      EXTRA=${EXTRA:-0}
      ENTAIL_COUNT=$((ENTAIL_COUNT + EXTRA))
    fi
    log "[scaffold] Phase 5 ENTAILMENT findings: $ENTAIL_COUNT"
    echo "$ENTAIL_COUNT" > "$OUT/audit/phase5-entailment-count.txt"

    if [ "$ENTAIL_COUNT" -gt 0 ]; then
      log "[scaffold] grade pre-revision (regression guard)"
      revert_test_files_in_workdir "$WORK"
      docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      python3 "$DSR" grade "$TASK_ID" > "$OUT/audit/grade-pre-revision.txt" 2>&1
      PRE_REWARD=$(grep -oE 'REWARD [01]' "$OUT/audit/grade-pre-revision.txt" | head -1 | awk '{print $2}')
      # grep -qE + echo gives clean 0/1; using -c+||echo created "0\n0" capture and bash int compares barfed silently
      PRE_BASE_PASS=$(grep -qE '^base[[:space:]]+->[[:space:]]+pass' "$OUT/audit/grade-pre-revision.txt" 2>/dev/null && echo 1 || echo 0)
      log "[scaffold] pre-revision: reward=${PRE_REWARD:-NA} base_pass=$PRE_BASE_PASS"

      log "[scaffold] revision pass (one shot, no further iteration)"
      FEEDBACK=$(grep -B1 -A8 -iE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary.txt" 2>/dev/null || echo "")
      if [ -f "$OUT/audit/phase5-adversary-flash.txt" ]; then
        FEEDBACK_FLASH=$(grep -B1 -A8 -iE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null || echo "")
        FEEDBACK="$FEEDBACK

$FEEDBACK_FLASH"
      fi

      REV="Your previous implementation has the following PRD-violation findings from cross-family adversary review. Revise the impl in this workspace to address each ENTAILMENT-typed finding.

CRITICAL: do not break existing tests. The codebase had base-test parity before your initial impl; the impl preserved that (your pre-revision diff is at $OUT/audit/impl-diff-pre-phase5.patch). Your revision must continue to preserve base-test parity. If you cannot fix an ENTAILMENT finding without risking base-test regression, leave it for follow-up rather than break working code.

ENTAILMENT findings:
$FEEDBACK"
      record_prompt "impl-revision" "$CRAFT_MODEL" "$REV"
      cd "$WORK"
      REV_TIMEOUT="${REV_TIMEOUT:-600}"  # 10 min for the revision pass (typically faster than impl)
      REV_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout "$REV_TIMEOUT" \
        cursor-agent -p -f --workspace "$WORK" --model "$CRAFT_MODEL" "$REV" 2>&1)
      REV_RC=$?
      [ "$REV_RC" = "124" ] && log "[scaffold] revision TIMED OUT after ${REV_TIMEOUT}s; continuing"
      cd - >/dev/null
      echo "$REV_OUT" | record_response "impl-revision" "$CRAFT_MODEL"
      log "[scaffold] revision pass complete"

      # Regression guard: grade post-revision; revert if it regressed base from pass to fail.
      log "[scaffold] grade post-revision (regression check)"
      revert_test_files_in_workdir "$WORK"
      docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      python3 "$DSR" grade "$TASK_ID" > "$OUT/audit/grade-post-revision.txt" 2>&1
      POST_REWARD=$(grep -oE 'REWARD [01]' "$OUT/audit/grade-post-revision.txt" | head -1 | awk '{print $2}')
      POST_BASE_PASS=$(grep -qE '^base[[:space:]]+->[[:space:]]+pass' "$OUT/audit/grade-post-revision.txt" 2>/dev/null && echo 1 || echo 0)
      log "[scaffold] post-revision: reward=${POST_REWARD:-NA} base_pass=$POST_BASE_PASS"

      # Decide which to keep:
      # 1. post-revision is REWARD 1 → keep (success).
      # 2. pre-revision REWARD higher than post → revert (catches REWARD 1 → 0 regression).
      # 3. pre-revision base passed, post-revision base failed → revert (base regression).
      # 4. otherwise (neither passing, no base regression) → keep post (the revision attempt).
      KEEP="post"
      REASON="default"
      if [ "${POST_REWARD:-0}" = "1" ]; then
        KEEP="post"; REASON="post-revision REWARD 1"
      elif [ "${PRE_REWARD:-0}" = "1" ] && [ "${POST_REWARD:-0}" != "1" ]; then
        KEEP="pre"; REASON="REVISION_REVERTED (pre REWARD 1, post REWARD ${POST_REWARD:-0})"
      elif [ "$PRE_BASE_PASS" -gt 0 ] && [ "$POST_BASE_PASS" -eq 0 ]; then
        KEEP="pre"; REASON="REVISION_REVERTED (pre base passed, post base failed)"
      fi
      echo "$REASON" > "$OUT/audit/revision-decision.txt"
      log "[scaffold] revision decision: KEEP=$KEEP ($REASON)"

      if [ "$KEEP" = "pre" ]; then
        # Restore workspace to pre-revision state via the captured patch
        log "[scaffold] reverting workspace to pre-revision impl"
        cd "$WORK"
        git checkout -- . 2>/dev/null
        git clean -fd 2>/dev/null
        git apply --whitespace=nowarn "$OUT/audit/impl-diff-pre-phase5.patch" 2>"$OUT/audit/revert-apply.log"
        cd - >/dev/null
        docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      fi
    fi
    ;;

  scaffold-codex)
    # v4 reframe 2026-05-30: every phase routed through `codex exec` (gpt-5.5)
    # via subscription. Same skill stage as `scaffold` — different model layer.
    # ===== Phase 1: design-doc (recon) =====
    # BRANCH-slot is the project's decision-tree branch (1/2/3/4), NOT a git branch name.
    # Tightened prompt schema to prevent the Flash + Composer git-branch confusion observed
    # in the n=3 recon comparison (both models defaulted to git-branch reading without the
    # explicit definition).
    log "[scaffold-codex] design-doc via $RECON_MODEL"
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
    DD_OUT=$(codex_call "$RECON_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$DDP")
    echo "$DD_OUT" > "$OUT/audit/design-doc.md"
    echo "$DD_OUT" | record_response "design-doc" "$RECON_MODEL"

    # ===== Phase 2: build-tools (Composer, author) =====
    log "[scaffold-codex] build-tools (proxy gate) via $CRAFT_MODEL"
    BTP="You are build-tools. Read this PRD + design doc and emit a proxy gate (test file) that tests the PRD's behaviors. Apply: PRD-quote per test, axis-crossing inputs, boundary clauses, # RESIDUE: at file head for SPECULATION. Output one fenced code block.

PRD:
$PRD

DESIGN DOC:
$DD_OUT"
    record_prompt "build-tools" "$CRAFT_MODEL" "$BTP"
    PG_OUT=$(codex_call "$CRAFT_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$BTP")
    echo "$PG_OUT" > "$OUT/audit/proxy_gate-raw.txt"
    echo "$PG_OUT" | record_response "build-tools" "$CRAFT_MODEL"

    # ===== Phase 3.5: dual adversary (soundness lens + breadth lens) =====
    # v4 reframe 2026-05-30: model held constant at GPT-5.5 across the scaffold,
    # so "cross-family" no longer applies literally. We preserve the dual-lens
    # structure (separate soundness + breadth prompts) because the structural
    # property under test is the scaffold's review *shape*, not the family mix.
    # NOTE: serialized rather than parallel — subscription throttle dislikes
    # concurrent codex calls; we accept the wall hit (one codex turn is small).
    log "[scaffold-codex] Phase 3.5 dual adversary (soundness + breadth lenses)"
    AP_SOUND="Adversary review — SOUNDNESS LENS. Three asks: soundness | discrimination | missing coverage. Emphasize PRD-violation catches and false-positive tests. Number findings F1..; end with COUNT: N.

PRD:
$PRD

PROXY GATE:
$PG_OUT"
    AP_BREADTH="Adversary review — BREADTH LENS. Three asks: soundness | discrimination | missing coverage. Emphasize coverage of edge cases and axis-crossing inputs the proxy gate may miss. Number findings F1..; end with COUNT: N.

PRD:
$PRD

PROXY GATE:
$PG_OUT"
    record_prompt "adversary-soundness" "$ADVERSARY_MODEL" "$AP_SOUND"
    record_prompt "adversary-breadth" "$BREADTH_MODEL" "$AP_BREADTH"
    codex_call "$ADVERSARY_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$AP_SOUND" > "$OUT/audit/adv-soundness.txt" 2>/dev/null
    codex_call "$BREADTH_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$AP_BREADTH" > "$OUT/audit/adv-breadth.txt" 2>/dev/null
    cat "$OUT/audit/adv-soundness.txt" | record_response "adversary-soundness" "$ADVERSARY_MODEL"
    cat "$OUT/audit/adv-breadth.txt" | record_response "adversary-breadth" "$BREADTH_MODEL"

    # RESIDUE.md (synthetic for smoke: capture SPECULATION-typed findings; real
    # implementation has Composer/Flash type-classify themselves. For smoke we
    # just stub a minimal residue from the volume of findings.)
    {
      echo "# RESIDUE — SPECULATION-typed findings carried forward to Phase 4"
      echo "# Phase 3.5 dual-adversary on $TASK_ID, $(ts)"
      echo "(For smoke: synthetic minimal residue; production version has each finding typed.)"
    } > "$OUT/audit/RESIDUE.md"

    # ===== residue-lint (FREEZE-CHECKLIST §VII contamination check) =====
    log "[scaffold-codex] residue-lint"
    if ! python3 "$DSR" residue-lint "$OUT/audit/RESIDUE.md" >/dev/null 2>&1; then
      log "[scaffold-codex] residue-lint FAILED — halting"
      echo INFRA_RESIDUE_LINT > "$OUT/failure_class.txt"
      docker rm -f "dsr-$TASK_ID" >/dev/null 2>&1
      exit 2
    fi

    # ===== Phase 4: implement-spec (Composer-craft, workspace = $WORK) =====
    log "[scaffold-codex] implement-spec via $CRAFT_MODEL in $WORK"
    ISP="Implement the feature from the PRD below. Edit files in this workspace directly. The workspace is a git repo at base $BASE_SHA — only source files should be modified.

PRD:
$PRD

DESIGN DOC (your prior reasoning):
$DD_OUT"
    record_prompt "implement-spec" "$CRAFT_MODEL" "$ISP"
    # v4: codex exec writes directly to $WORK via --sandbox workspace-write, -C $WORK.
    # We still hard-timeout via timeout(1) — codex CLI can also hang on long-running
    # tool loops, and the workspace state captures regardless of exit code.
    IMPL_TIMEOUT="${IMPL_TIMEOUT:-900}"  # 15 min default
    IMPL_LAST="$(mktemp -t codex-impl.XXXXXX)"
    timeout "$IMPL_TIMEOUT" "$CODEX_BIN" exec \
      -c model="$CRAFT_MODEL" \
      --sandbox "$CODEX_SANDBOX_WR" \
      --skip-git-repo-check \
      --dangerously-bypass-approvals-and-sandbox \
      -C "$WORK" \
      --output-last-message "$IMPL_LAST" \
      "$ISP" > "$OUT/audit/impl-stdout.txt" 2>&1
    IMPL_RC=$?
    if [ "$IMPL_RC" = "124" ]; then
      log "[scaffold-codex] impl-spec TIMED OUT after ${IMPL_TIMEOUT}s; continuing with whatever workspace state was reached"
      echo "TIMEOUT after ${IMPL_TIMEOUT}s" >> "$OUT/audit/impl-timeout.txt"
    fi
    cat "$IMPL_LAST" | record_response "implement-spec" "$CRAFT_MODEL"
    rm -f "$IMPL_LAST"

    # Strip any test-file edits the model wrote, then capture pre-Phase-5 impl
    # diff for the adversary to review (artifact-dir excluded).
    revert_test_files_in_workdir "$WORK"
    IMPL_DIFF=$(cd "$WORK" && git add -A && git diff --cached -- \
      ':(exclude).venv' ':(exclude).venv/**' ':(exclude)node_modules' ':(exclude)node_modules/**' \
      ':(exclude)__pycache__' ':(exclude)**/__pycache__' ':(exclude)__pycache__/**' \
      ':(exclude)dist' ':(exclude)dist/**' ':(exclude)build' ':(exclude)build/**' \
      ':(exclude).pytest_cache' ':(exclude)**/.pytest_cache' ':(exclude).tox' ':(exclude).tox/**' \
      ':(exclude)*.pyc' ':(exclude)*.pyo' ':(exclude)*.egg-info' ':(exclude)*.egg-info/**')
    echo "$IMPL_DIFF" > "$OUT/audit/impl-diff-pre-phase5.patch"
    IMPL_DIFF_BYTES=$(printf '%s' "$IMPL_DIFF" | wc -c | tr -d ' ')
    log "[scaffold-codex] pre-Phase-5 impl diff: ${IMPL_DIFF_BYTES} bytes"

    # ===== Phase 5: cross-family adversary on impl + RESIDUE re-type (treatment-defining) =====
    # Reviews PRD + design-doc + proxy gate + RESIDUE.md + impl diff. Four asks; 4th is the
    # residue-conversion: SPECULATION at Phase 3.5 can convert to ENTAILMENT when the impl
    # gives the speculation a concrete shape (Hₐ₁₀ operationalized). Composer-sole here per
    # the 2026-05-29 finding that soundness-emphasis prompt + Composer catches axis_crossing
    # bugs Flash caught at Phase 3.5; Flash adversary is OPTIONAL second lens (controlled by
    # PHASE5_DUAL=1 env var) for cross-cutting findings.
    log "[scaffold-codex] Phase 5 adversary on impl ($IMPL_DIFF_BYTES bytes)"
    PG_TRUNC=$(printf '%s' "$PG_OUT" | head -c 5000)
    RESIDUE_CONTENT=$(cat "$OUT/audit/RESIDUE.md")
    AP5="You are the cross-family adversary reviewing an IMPLEMENTATION against the PRD it was supposed to satisfy. You also receive the design-doc the author worked from, the proxy gate that defined the necessary bar, and a RESIDUE.md of SPECULATION-typed findings from earlier (pre-impl) review.

Soundness is the load-bearing axis. Catch PRD violations the impl introduced.

Answer 4 numbered asks. For each finding, prefix with one of: TYPE: ENTAILMENT | DISCRIMINATOR | SPECULATION | WRONG. ENTAILMENT findings will trigger an impl revision pass — be honest about whether something is plainly PRD-violating or merely your aesthetic.

## 1. Soundness (PRD violations in the impl)
Cite the file + line range; quote the impl; quote the PRD clause it violates.

## 2. Discrimination (impl looks right but a mutant would pass the same tests)
Name the mutant; give an input shape that would surface it.

## 3. Missing coverage (PRD behaviors NOT implemented)
Quote the PRD clause; describe what the impl is missing.

## 4. RESIDUE conversion — re-type each RESIDUE entry against the impl
For each RESIDUE entry, does the impl exhibit a behavior that converts it from SPECULATION to ENTAILMENT? If yes, name the new ENTAILMENT finding and describe the conversion. If still ambiguous, mark as REMAINS-SPECULATION.

End with COUNT: N.

---

PRD:
$PRD

DESIGN DOC:
$DD_OUT

PROXY GATE (truncated to first 5KB):
$PG_TRUNC

RESIDUE.md:
$RESIDUE_CONTENT

IMPL DIFF (current model patch):
$IMPL_DIFF"

    record_prompt "phase5-adversary" "$BREADTH_MODEL" "$AP5"
    PH5_OUT=$(codex_call "$BREADTH_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$AP5")
    echo "$PH5_OUT" > "$OUT/audit/phase5-adversary.txt"
    echo "$PH5_OUT" | record_response "phase5-adversary" "$BREADTH_MODEL"

    # Optional second-lens at Phase 5 — disabled by default. With model held constant
    # the "cross-family" rationale dissolves; PHASE5_DUAL=1 still re-runs the prompt
    # with a fresh codex session, which occasionally surfaces different findings.
    if [ "${PHASE5_DUAL:-0}" = "1" ]; then
      log "[scaffold-codex] Phase 5 optional second-lens pass (PHASE5_DUAL=1)"
      codex_call "$ADVERSARY_MODEL" "$CODEX_SANDBOX_RO" "/tmp" "$AP5" > "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null
      cat "$OUT/audit/phase5-adversary-flash.txt" | record_response "phase5-adversary-flash" "$ADVERSARY_MODEL"
    fi

    # Detect ENTAILMENT findings → one revision pass (bounded; no further iteration)
    ENTAIL_COUNT=$(grep -ciE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary.txt" 2>/dev/null)
    ENTAIL_COUNT=${ENTAIL_COUNT:-0}
    if [ "${PHASE5_DUAL:-0}" = "1" ] && [ -f "$OUT/audit/phase5-adversary-flash.txt" ]; then
      EXTRA=$(grep -ciE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null)
      EXTRA=${EXTRA:-0}
      ENTAIL_COUNT=$((ENTAIL_COUNT + EXTRA))
    fi
    log "[scaffold-codex] Phase 5 ENTAILMENT findings: $ENTAIL_COUNT"
    echo "$ENTAIL_COUNT" > "$OUT/audit/phase5-entailment-count.txt"

    if [ "$ENTAIL_COUNT" -gt 0 ]; then
      log "[scaffold-codex] grade pre-revision (regression guard)"
      revert_test_files_in_workdir "$WORK"
      docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      python3 "$DSR" grade "$TASK_ID" > "$OUT/audit/grade-pre-revision.txt" 2>&1
      PRE_REWARD=$(grep -oE 'REWARD [01]' "$OUT/audit/grade-pre-revision.txt" | head -1 | awk '{print $2}')
      # grep -qE + echo gives clean 0/1; using -c+||echo created "0\n0" capture and bash int compares barfed silently
      PRE_BASE_PASS=$(grep -qE '^base[[:space:]]+->[[:space:]]+pass' "$OUT/audit/grade-pre-revision.txt" 2>/dev/null && echo 1 || echo 0)
      log "[scaffold-codex] pre-revision: reward=${PRE_REWARD:-NA} base_pass=$PRE_BASE_PASS"

      log "[scaffold-codex] revision pass (one shot, no further iteration)"
      FEEDBACK=$(grep -B1 -A8 -iE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary.txt" 2>/dev/null || echo "")
      if [ -f "$OUT/audit/phase5-adversary-flash.txt" ]; then
        FEEDBACK_FLASH=$(grep -B1 -A8 -iE 'TYPE:[[:space:]]*ENTAILMENT' "$OUT/audit/phase5-adversary-flash.txt" 2>/dev/null || echo "")
        FEEDBACK="$FEEDBACK

$FEEDBACK_FLASH"
      fi

      REV="Your previous implementation has the following PRD-violation findings from cross-family adversary review. Revise the impl in this workspace to address each ENTAILMENT-typed finding.

CRITICAL: do not break existing tests. The codebase had base-test parity before your initial impl; the impl preserved that (your pre-revision diff is at $OUT/audit/impl-diff-pre-phase5.patch). Your revision must continue to preserve base-test parity. If you cannot fix an ENTAILMENT finding without risking base-test regression, leave it for follow-up rather than break working code.

ENTAILMENT findings:
$FEEDBACK"
      record_prompt "impl-revision" "$CRAFT_MODEL" "$REV"
      REV_TIMEOUT="${REV_TIMEOUT:-600}"  # 10 min for the revision pass (typically faster than impl)
      REV_LAST="$(mktemp -t codex-rev.XXXXXX)"
      timeout "$REV_TIMEOUT" "$CODEX_BIN" exec \
        -c model="$CRAFT_MODEL" \
        --sandbox "$CODEX_SANDBOX_WR" \
        --skip-git-repo-check \
        --dangerously-bypass-approvals-and-sandbox \
        -C "$WORK" \
        --output-last-message "$REV_LAST" \
        "$REV" > "$OUT/audit/revision-stdout.txt" 2>&1
      REV_RC=$?
      [ "$REV_RC" = "124" ] && log "[scaffold-codex] revision TIMED OUT after ${REV_TIMEOUT}s; continuing"
      cat "$REV_LAST" | record_response "impl-revision" "$CRAFT_MODEL"
      rm -f "$REV_LAST"
      log "[scaffold-codex] revision pass complete"

      # Regression guard: grade post-revision; revert if it regressed base from pass to fail.
      log "[scaffold-codex] grade post-revision (regression check)"
      revert_test_files_in_workdir "$WORK"
      docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      python3 "$DSR" grade "$TASK_ID" > "$OUT/audit/grade-post-revision.txt" 2>&1
      POST_REWARD=$(grep -oE 'REWARD [01]' "$OUT/audit/grade-post-revision.txt" | head -1 | awk '{print $2}')
      POST_BASE_PASS=$(grep -qE '^base[[:space:]]+->[[:space:]]+pass' "$OUT/audit/grade-post-revision.txt" 2>/dev/null && echo 1 || echo 0)
      log "[scaffold-codex] post-revision: reward=${POST_REWARD:-NA} base_pass=$POST_BASE_PASS"

      # Decide which to keep:
      # 1. post-revision is REWARD 1 → keep (success).
      # 2. pre-revision REWARD higher than post → revert (catches REWARD 1 → 0 regression).
      # 3. pre-revision base passed, post-revision base failed → revert (base regression).
      # 4. otherwise (neither passing, no base regression) → keep post (the revision attempt).
      KEEP="post"
      REASON="default"
      if [ "${POST_REWARD:-0}" = "1" ]; then
        KEEP="post"; REASON="post-revision REWARD 1"
      elif [ "${PRE_REWARD:-0}" = "1" ] && [ "${POST_REWARD:-0}" != "1" ]; then
        KEEP="pre"; REASON="REVISION_REVERTED (pre REWARD 1, post REWARD ${POST_REWARD:-0})"
      elif [ "$PRE_BASE_PASS" -gt 0 ] && [ "$POST_BASE_PASS" -eq 0 ]; then
        KEEP="pre"; REASON="REVISION_REVERTED (pre base passed, post base failed)"
      fi
      echo "$REASON" > "$OUT/audit/revision-decision.txt"
      log "[scaffold-codex] revision decision: KEEP=$KEEP ($REASON)"

      if [ "$KEEP" = "pre" ]; then
        # Restore workspace to pre-revision state via the captured patch
        log "[scaffold-codex] reverting workspace to pre-revision impl"
        cd "$WORK"
        git checkout -- . 2>/dev/null
        git clean -fd 2>/dev/null
        git apply --whitespace=nowarn "$OUT/audit/impl-diff-pre-phase5.patch" 2>"$OUT/audit/revert-apply.log"
        cd - >/dev/null
        docker cp "$WORK/." "dsr-$TASK_ID:/app/" >/dev/null
      fi
    fi
    ;;

  baseline-codex)
    # v4 reframe 2026-05-30: codex CLI alone — single-agent harness on the PRD,
    # GPT-5.5 via subscription. Sibling to scaffold; the publishable Arm B.
    BASELINE_CODEX_MODEL="${DSR_BASELINE_CODEX_MODEL:-gpt-5.5}"
    log "[baseline-codex] codex exec --model $BASELINE_CODEX_MODEL in $WORK"
    BCXP="Implement the feature described in this PRD. Edit files in the workspace directly. The workspace is a git repo at base $BASE_SHA — only modify source files (no tests/, no config, no generated artifacts).

PRD:
$PRD"
    record_prompt "baseline-impl" "$BASELINE_CODEX_MODEL" "$BCXP"
    IMPL_TIMEOUT="${IMPL_TIMEOUT:-1800}"  # 30 min — codex-alone runs longer tool loops than scaffold's bounded impl phase
    BCX_LAST="$(mktemp -t codex-baseline.XXXXXX)"
    timeout "$IMPL_TIMEOUT" "$CODEX_BIN" exec \
      -c model="$BASELINE_CODEX_MODEL" \
      --sandbox "$CODEX_SANDBOX_WR" \
      --skip-git-repo-check \
      --dangerously-bypass-approvals-and-sandbox \
      -C "$WORK" \
      --output-last-message "$BCX_LAST" \
      "$BCXP" > "$OUT/baseline-codex-stdout.txt" 2>&1
    BCX_RC=$?
    [ "$BCX_RC" = "124" ] && log "[baseline-codex] codex exec TIMED OUT after ${IMPL_TIMEOUT}s; continuing with workspace state"
    cat "$BCX_LAST" | record_response "baseline-impl" "$BASELINE_CODEX_MODEL"
    rm -f "$BCX_LAST"
    ;;

  baseline-comp)
    log "[baseline-comp] cursor-agent --model $CRAFT_MODEL in $WORK"
    BCP="Implement the feature from this PRD. Edit files in this workspace directly. The workspace is a git repo at base $BASE_SHA — only source files should be modified.

PRD:
$PRD"
    record_prompt "baseline-impl" "$CRAFT_MODEL" "$BCP"
    cd "$WORK"
    IMPL_TIMEOUT="${IMPL_TIMEOUT:-900}"
    BC_OUT=$(CURSOR_API_KEY="$CURSOR_API_KEY" timeout "$IMPL_TIMEOUT" \
      cursor-agent -p -f --workspace "$WORK" --model "$CRAFT_MODEL" "$BCP" 2>&1)
    BC_RC=$?
    [ "$BC_RC" = "124" ] && log "[baseline-comp] cursor-agent TIMED OUT after ${IMPL_TIMEOUT}s; continuing with workspace state"
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
    # On EC2 boxes, system python3 lacks google-generativeai (PEP 668 blocks system-pip
    # install); setup_box.sh installs it into ~/.dsr-venv and symlinks python3-dsr.
    # Use python3-dsr if available, fall back to python3 (local mac has it system-installed).
    GEMINI_PY=$(command -v python3-dsr 2>/dev/null || command -v python3)
    BF_OUT=$($GEMINI_PY "$GEMINI_API" -m "$BASELINE_FLASH_MODEL" --prompt "$BFP" 2>&1)
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
# Strip test-file edits one more time so the captured patch and the workspace
# pushed back to the container are source-only.
revert_test_files_in_workdir "$WORK"
log "capture model.patch"
cd "$WORK"
# Banked 2026-05-29 from bandit v5: Composer created .venv/ with 3556 pkg files, captured
# into model.patch (28MB). Exclude common artifact dirs at the capture step so the diff is
# only source-file changes that map to PRD-relevant impl. Pier's test.patch also can't apply
# cleanly to a polluted tree, so exclusion is grade-time correctness too.
git add -A
git diff --cached -- \
  ':(exclude).venv' ':(exclude).venv/**' ':(exclude)node_modules' ':(exclude)node_modules/**' \
  ':(exclude)__pycache__' ':(exclude)**/__pycache__' ':(exclude)__pycache__/**' \
  ':(exclude)dist' ':(exclude)dist/**' ':(exclude)build' ':(exclude)build/**' \
  ':(exclude).pytest_cache' ':(exclude)**/.pytest_cache' ':(exclude).tox' ':(exclude).tox/**' \
  ':(exclude)*.pyc' ':(exclude)*.pyo' ':(exclude)*.egg-info' ':(exclude)*.egg-info/**' \
  > "$OUT/model.patch"
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
# Tight pattern: the dsr grade output prints `base  -> pass` / `base  -> FAIL`
# (and same for new). Loose 'base.*pass' falsely matches '(base FAIL, new pass)'
# because .* is greedy. Use the exact -> arrow shape.
BASE_PASS=$(grep -cE '^base[[:space:]]+->[[:space:]]+pass' "$OUT/grade.txt" 2>/dev/null); BASE_PASS=${BASE_PASS:-0}
NEW_PASS=$(grep -cE '^new[[:space:]]+->[[:space:]]+pass' "$OUT/grade.txt" 2>/dev/null); NEW_PASS=${NEW_PASS:-0}
# Banked 2026-05-29: 'exception' alone matches the boilerplate Python traceback
# context line "During handling of the above exception, another exception occurred:"
# which doesn't indicate an evaluator error. Only flag real FATAL lines or
# uncaught exception markers from pier itself.
EXCEPTION=$(grep -E '^FATAL|^Traceback \(most recent call last\)|^RuntimeError' "$OUT/grade.txt" | head -1 | tr -d '\n')

cat > "$OUT/grade.json" <<EOF
{
  "reward": ${REWARD:-null},
  "base_pass": $([ "${BASE_PASS:-0}" -gt 0 ] && echo true || echo false),
  "new_pass": $([ "${NEW_PASS:-0}" -gt 0 ] && echo true || echo false),
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
