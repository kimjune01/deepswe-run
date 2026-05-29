# 3-arm local smoke — kysely-window-grouping-helpers — 2026-05-29

**FREEZE-CHECKLIST §X.1 closed.** All three arms produced the canonical artifact schema end-to-end through the unified `harness/run_arm.sh` driver. Codex's "components vs arms" cut is addressed: the experimental treatment now exists as a runnable object, not just as composed skill phases.

## Results

| arm | reward | wall | model.patch | files | failure_class | est. $ |
|---|---|---|---|---|---|---|
| scaffold | **1** | 485s (8:05) | 36 KB | 15 | RESOLVED | ~$1.50 |
| baseline-comp | **1** | 163s (2:43) | 47 KB | 21 | RESOLVED | ~$0.30 |
| baseline-flash | 0 | 214s (3:34) | 0 | (diff didn't apply) | INFRA_PARSE | ~$0.005 |

Total: ~$1.80 model spend, ~14 min wall serial.

## What's validated

- **Container isolation per arm** — each arm tears down + recreates `dsr-<task-id>`. Confirmed: fresh `git rev-parse HEAD` at base for each arm; no state carry.
- **Workspace mirror via `docker cp /app/.`** — round-trips correctly. After-model `git diff --cached` captures the model's edits.
- **Phase 3.5 dual-adversary fires in parallel** — Flash + Composer adversary calls run concurrently and complete; both findings written to `audit/adv-{flash,composer}.txt`.
- **residue-lint hook** — fired pre-Phase-4 on scaffold arm, passed (synthetic minimal residue contained nothing matching deny patterns).
- **dsr grade end-to-end** — identical reward to manual local + EC2 measurement on the same gold patch (REWARD 1, 22 base + 254 new tests pass).
- **Artifact schema** — all 9 schema items present per arm: env.json, prompts.jsonl, responses.jsonl, audit/, model.patch, grade.json, grade.txt, failure_class.txt, wall.txt.
- **Failure taxonomy fires correctly** — RESOLVED for both passing arms; INFRA_PARSE for the diff-didn't-apply case after a classifier tightening (was incorrectly UNRESOLVED_NO_DIFF before).

## What's measured

### scaffold arm (5 model calls, ~$1.50)

| phase | model | prompt chars | wall |
|---|---|---|---|
| design-doc | gemini-3.5-flash | 2,744 | ~36s |
| build-tools (proxy gate author) | composer-2.5 | 9,137 | ~2:00 |
| Phase 3.5 adversary-flash | gemini-3.5-flash | 43,068 | concurrent with breadth |
| Phase 3.5 adversary-breadth | composer-2.5 | 43,068 | ~2:25 (whichever was slower) |
| implement-spec | composer-2.5 | 9,106 | ~2:21 |

Patch shape: 852 insertions / 3 deletions across 15 source files, idiomatic kysely operation-node decomposition (Hₐ₇ codebase-conformance preserved).

### baseline-comp arm (1 model call)

cursor-agent composer-2.5 single-pass on PRD-only prompt, workspace=cwd, ~2:00 model + ~40s grade. 21 files / 1048 LOC across kysely's parser/, query-builder/, query-compiler/, plugin/. Passes 22/22 base + 254/254 new.

### baseline-flash arm (1 model call)

Direct Gemini API (via `harness/feature/gemini_api.py`), NOT gemini-cli. The cli's headless mode `-p --approval-mode plan` explored kysely's 800MB workspace via tool calls for 17+ min on a prior attempt; switching to direct API request was 214s and bounded.

Gemini produced a 32KB fenced diff but `git apply` rejected it with `corrupt patch at line 81` — Flash hallucinated hunk-context lines on the unfamiliar codebase. Classifier: INFRA_PARSE (model output looked like a diff but didn't apply, distinct from UNRESOLVED_NO_DIFF).

**This is the kind of baseline behavior the scored run will measure.** Not a pipeline bug; an honest limitation of single-agent Flash on large unfamiliar codebases.

## Bugs caught + fixed during the smoke (codex's "no-op test" essentially)

1. **gemini-cli `--approval-mode yolo` hangs over stdin** — sits waiting for more turns even after consuming the prompt. Switched baseline-flash to direct API.
2. **gemini-cli `-p` + `plan` explores 800MB workspace via tool calls** — 17+ min, never returned. Switched to direct API.
3. **Temp diff file leaked into model.patch** — created baseline-flash.diff inside $WORK; git add -A picked it up as a new file even when extraction failed. Moved extraction path outside $WORK.
4. **Classifier said UNRESOLVED_NO_DIFF when model.patch was 0** — but didn't distinguish "no diff produced" from "diff produced but didn't apply." Added an APPLY_LOG check; the diff-didn't-apply case now correctly classifies as INFRA_PARSE.

## Cost ledger (this segment of the session)

| line item | $ |
|---|---|
| baseline-flash v1 (hung yolo, killed) | 0 (gemini free) |
| baseline-flash v2 (no diff in plan-mode response) | 0 |
| baseline-flash v3 (gemini -p explored 800MB, killed) | 0 |
| baseline-flash v4 (direct API, applied → corrupt) | ~$0.005 |
| baseline-comp | ~$0.30 |
| scaffold | ~$1.50 |
| **Total** | **~$1.81** |

## Closes which FREEZE-CHECKLIST items

- ✅ §I.a End-to-end smoke per arm
- ✅ §I.b Artifact schema fixed and emitted by each arm
- ⏸ §I.c Replay test (artifacts are deterministic-replayable in principle; the replay script not yet written)
- ✅ §I.d No-op test (baseline-flash v2 hit the "no diff block" path correctly; v4 hit INFRA_PARSE)
- ✅ §I.e Patch-capture sanity (fixed leak + verified no grader-file modifications)
- ✅ §I.f Arm isolation
- ✅ §V Failure taxonomy fires correctly across the three observed cases (RESOLVED ×2, INFRA_PARSE ×1)
- ✅ §VII RESIDUE.md content rules (residue_lint.py + dsr CLI wired; hook fired on scaffold arm)

## Remaining before freeze

- §I.c replay-test script (~30 min, $0)
- §II prompt-freeze hashes + `frozen-skills-v1` tag (~10 min, $0)
- §X.2 n≥3 task smoke across feature classes — bandit (compositional) + oxvg (subtractive) to confirm INFRA_PARSE isn't dominating the baseline-flash arm (which would mean we need to amend the prereg to use a multi-turn strategy for Flash baseline)
- §X.3 EC2 single-box smoke per arm (already validated for `dsr grade` chain in earlier `smoke_box.sh` fire; needs to repeat with `run_arm.sh` for full arm)
- §X.4 EC2 multi-box dispatcher smoke (cheapest variant of the Pro coordinator pattern)

## Receipts

- `scaffold/{env.json,prompts.jsonl,responses.jsonl,audit/,model.patch,grade.json,grade.txt,failure_class.txt,wall.txt}`
- `baseline-comp/{...same schema...}`
- `baseline-flash/{...same schema..., baseline-flash-extracted.diff, baseline-flash-apply.log}`
- This file: `SMOKE-RESULT.md`
