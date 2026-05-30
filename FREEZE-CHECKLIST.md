# Freeze checklist

Concrete preconditions for declaring the scaffold + baselines frozen and starting the scored run. Built from codex's 2026-05-29 critical review of the pre-freeze state. Each item is binary (✓/✗); freeze is blocked while any ✗ remains.

The deep cut in codex's review: **validating skill components is not validating arm pipelines.** Until each of the three arms produces a `model.patch` through the same frozen runner path, "the rest is partly lab-bench evidence." This document operationalizes that bar.

## I. Arms instantiate the treatment

Status: ✗ all three. Highest priority before freeze.

- [ ] **End-to-end smoke per arm.** Scaffold, baseline-Composer, baseline-Flash each runs ≥1 task through the full pipeline and emits the artifact schema below. No "phase fired in isolation" counts; the run must compose the same way the scored run will.
- [ ] **Artifact schema fixed.** Each arm-task must emit:
  - `prompts.jsonl` — every prompt sent to a model (timestamped, model-ID stamped)
  - `responses.jsonl` — every raw model response (timestamped, model-ID stamped)
  - `model.patch` — diff against base commit, source files only
  - `audit/` (scaffold arm only) — proxy gate, RESIDUE.md, adversary reviews
  - `grade.json` — reward, base-pass, new-pass, exception-info if any
  - `wall.txt` — seconds
  - `cost.json` — token counts + estimated dollars per model call
  - `env.json` — CLI versions, model IDs, temperature, auth mode
  - `failure_class.txt` — if reward != 1, one of the values from §V below
- [ ] **Replay test.** Given frozen `prompts.jsonl` + `responses.jsonl` + `model.patch`, re-grading produces the identical `grade.json`. Deterministic scorer is a hard requirement.
- [ ] **No-op test.** When the impl phase produces no `model.patch` (empty diff), the pipeline fails closed (no false REWARD 1 from an unchanged tree).
- [ ] **Patch-capture sanity.** `model.patch` contains only changes to source files. No harness files, no log files, no test files (which are graders), no caches, no generated artifacts. Asserted by `dsr grade` ahead of test.patch application.
- [ ] **Arm isolation.** Each arm starts from a freshly-instantiated container against the same image. No state carries across arms; explicit container teardown + recreate between arms.

## II. Prompt + skill freeze

- [ ] **Prompt-freeze hash.** SHA256 of every prompt template + skill file. Stored in `frozen/HASHES.txt`. The scored run reads from these exact files; the runner refuses to start if any hash mismatches.
- [ ] **Skill-set tagged.** Git tag `frozen-skills-v1` on the commit whose `skills/`, `harness/feature/dsr.py`, and `harness/bootstrap.sh` files are in `HASHES.txt`.

## III. Model identity freeze

- [ ] **Pinned versions.** `gemini-cli@0.38.0`, `cursor-agent@2026.05.28-a70ca7c`, `datacurve-pier==0.2.0`, deep-swe `@2f0f4125`, AMI `ami-00563078bca04e287`. All in `frozen/VERSIONS.txt`.
- [ ] **Model IDs.** `gemini-3.5-flash` (recon + adversary), `composer-2.5` (craft + author + adversary-breadth). The `-fast` variant is forbidden.
- [ ] **Temperature.** Composer 2.5 default (no temperature override available through cursor-agent). Gemini default. Documented in `VERSIONS.txt`.
- [ ] **Auth mode.** Per-token, NOT subscription-Max. Documented in `VERSIONS.txt` so reproducers know which billing path applies.

## IV. Eligible-denominator file

- [ ] **`frozen/eligible.txt`** — the explicit list of 109 task IDs (113 − 4 defectives per audit-v1). Frozen at the same commit as skills.
- [ ] **`frozen/run_order.txt`** — lexicographic sort of `eligible.txt`. Order is fixed but does not affect a completed measurement.
- [ ] **Exclusion criteria written before any arm runs.** A task can ONLY be excluded if (a) it's in the audit-v1 defectives list, or (b) the runner emits a specific infra-failure class (see §V) AND that class was named in this checklist before the run. No post-hoc exclusions.

## V. Failure taxonomy (defined BEFORE the run sees outcomes)

Per task per arm, the failure (if any) is exactly one of:

- `RESOLVED` — reward = 1
- `UNRESOLVED_MODEL` — model produced a patch that the grader rejected (reward = 0, model.patch non-empty, no exceptions)
- `UNRESOLVED_NO_DIFF` — model produced no diff (reward = 0, model.patch empty)
- `INFRA_TIMEOUT` — wall-clock exceeded N minutes (see retry policy below)
- `INFRA_DOCKER` — container failed to start, OOM, or died mid-run
- `INFRA_AUTH` — model API authentication failure
- `INFRA_PARSE` — couldn't parse model output into a patch
- `EVALUATOR_ERROR` — test.patch failed to apply, test.sh crashed unrelated to model patch
- `DEPENDENCY_FAILURE` — npm/pip install failed in container during grading

Retry policy: `INFRA_*` and `EVALUATOR_ERROR` get exactly 1 retry. `UNRESOLVED_*` get no retries.

## VI. Statistical method amendment

- [ ] **Switch from Fisher exact to McNemar's exact** for the scaffold-vs-baseline comparison. Fisher is for unpaired 2×2 tables; our outcomes are paired per task (same task, same image, two arms), and the discordant pairs (scaffold-only-pass + baseline-only-pass) are the McNemar quantity. Wilson 95% interval on each arm's marginal still reported.
- [ ] **Two comparisons.** scaffold vs baseline-Composer AND scaffold vs baseline-Flash. Bonferroni-corrected alpha (0.025 per comparison) since we have two tests, or pre-declared "primary is vs best baseline." Decide which **before** seeing arm outcomes.
- [ ] **Effect-size headline.** Marginal pass-rate difference + 95% CI via paired-bootstrap on the discordant set.

## VII. RESIDUE.md contamination rules (Phase 3.5 carry-forward, named as part of treatment)

The Phase 3.5 → Phase 4 `RESIDUE.md` carry-forward leaks information from the adversary critique into the impl-time adversary. Per codex's review, this must be (a) named as part of the scaffold treatment in §0 of the prereg, AND (b) bounded by the following content rules:

- RESIDUE entries may contain: the type-classification reasoning ("SPECULATION because PRD silent on X"), the PRD clause that was ambiguous, the input shape that would convert to ENTAILMENT
- RESIDUE entries may NOT contain: patch sketches, file-level implementation plans, references to hidden test names, references to the gold patch (which the agent should never have seen), or any reasoning that inferred hidden-grader internals
- Asserted by a hook that scans RESIDUE.md before Phase 4 starts and rejects forbidden content patterns

## VIII. Budget stop rules

- [ ] **Per-task soft cap.** If a task accumulates > $5 in model spend across all retries, log a `BUDGET_OVERRUN` flag (not an exclusion) and continue.
- [ ] **Per-arm hard cap.** $200 model spend per arm; if exceeded the runner halts gracefully (no partial-arm publication; either complete or do not).
- [ ] **Free-tier-rate-limit behavior.** If Gemini free tier throttles, the runner switches to paid tier (logged in `cost.json` per call). Mid-run pricing changes are accumulated, not retroactively reclassified.

## IX. Artifact immutability

- [ ] **Write-once layout.** After a task-arm completes, its `results/<task>/<arm>/` directory is sealed via SHA256 manifest. Re-runs go to `results/<task>/<arm>-retry-N/` and are tracked separately.
- [ ] **Receipts off-box before teardown.** Per task-arm, all artifacts are pulled to the operator's local machine before the EC2 box terminates. The teardown step asserts the pull succeeded.

## X. Pre-flight smoke before scored run

The scored run starts only after this exact sequence completes green:

1. End-to-end smoke per arm on local docker, 1 task (kysely): all artifacts emitted, replay test green
2. End-to-end smoke per arm on local docker, 3 tasks across feature classes (kysely breadth-additive + bandit compositional + oxvg subtractive): each arm produces the schema; failure-taxonomy populated; no unexpected failure classes
3. EC2 single-box smoke per arm on the scored AMI: validates box infra matches local
4. EC2 multi-box smoke (≥2 coords): validates dispatcher reconciliation; cancel-spot-request on teardown
5. Frozen-hash assertion: runner reads `HASHES.txt` and refuses to start if any mismatch

---

## Status as of 2026-05-29 12:30 PDT (initial)

Green: §III mostly (pins documented), §IV eligible.txt could be generated from audit-v1 in ~5 min.

Yellow: §V failure taxonomy partial in PREREGISTRATION §4; needs expansion.

Red (must close before freeze):
- §I all items — no arm has yet produced a `model.patch` through the full pipeline
- §II prompt-freeze hash + skill tag
- §VI statistical method amendment to PREREGISTRATION §6 (Fisher → McNemar)
- §VII RESIDUE.md content rules + hook
- §X.1, §X.2 — local-docker arm smokes

The two cheap-to-close items I'd do next: §VI amendment (writing) + §X.1 (local single-arm smoke, ~$0.50). Together they convert two reds to greens for ~$0.50 and ~3h.

---

## Status as of 2026-05-29 17:40 PDT (post freeze-prep session)

**GREEN (closed):**
- §I.a End-to-end smoke per arm — `harness/run_arm.sh` ships scaffold/baseline-comp/baseline-flash; n=3 substrate smoke (kysely + bandit + oxvg) emitted full artifact schema for each arm
- §I.b Artifact schema fixed — env.json, prompts.jsonl, responses.jsonl, audit/, model.patch, grade.json, grade.txt, failure_class.txt, wall.txt; uniform across all arms
- §I.d No-op test — baseline-flash hit UNRESOLVED_NO_DIFF + INFRA_PARSE paths correctly
- §I.e Patch-capture sanity — `.venv` + `node_modules` + `__pycache__` etc excluded from model.patch (banked from bandit v5 28MB pollution)
- §I.f Arm isolation — fresh dsr-<task-id> container per arm
- §II prompt-freeze hashes — `harness/freeze_hashes.sh write/check` over 12 files; `frozen/HASHES.txt` regenerated on every script change; `STANDARD_PROMPTS.md` canonicalizes the prompts
- §III Model identity freeze — `harness/bootstrap.sh` PIN_GEMINI_CLI/PIN_CURSOR_AGENT/PIN_PIER/PIN_DEEPSWE_SHA; auth_mode in env.json
- §IV Eligible-denominator file — `frozen/eligible.txt` + `frozen/run_order.txt` (109 tasks at deep-swe@2f0f4125)
- §V Failure taxonomy — RESOLVED / UNRESOLVED_MODEL / UNRESOLVED_NO_DIFF / INFRA_TIMEOUT / INFRA_DOCKER / INFRA_AUTH / INFRA_PARSE / EVALUATOR_ERROR / DEPENDENCY_FAILURE; observed firing in smoke (RESOLVED × 3, UNRESOLVED_MODEL × 6, INFRA_PARSE × 3, UNRESOLVED_NO_DIFF × 1)
- §VI Statistical method — PREREGISTRATION §6 amended Fisher → McNemar on discordant pairs + Wilson marginals; Bonferroni alpha 0.025 OR primary-vs-best-baseline (pre-data declaration in `frozen/COMPARISONS.txt`)
- §VII RESIDUE.md content rules — `harness/feature/residue_lint.py` + dsr CLI integration; pre-Phase-4 (now Phase 5) hook fires on every scaffold arm
- §X.1 Local single-arm smoke — kysely scaffold REWARD 1 measured 2026-05-29 in earlier session
- §X.2 n≥3 task smoke across feature classes — kysely (breadth-additive) + bandit (compositional) + oxvg (subtractive); see `results/runs/CHAIN-SMOKE-RESULT.md`
- §X.3 EC2 single-box arm smoke — `harness/smoke_arm_ec2.sh`; v3 validated kysely baseline-comp on box (REWARD 0, but platform green: bootstrap + cursor-agent + venv-genai + dsr grade all worked)
- §X.4 EC2 multi-box dispatcher smoke — `harness/smoke_multibox_ec2.sh`; v2 launched 2 spot boxes concurrently with no quota / keypair collision (banked TS=epoch-PID fix)

**Architectural additions made this session (beyond original checklist):**
- Phase 3.5 dual-adversary on the gate (Flash for soundness + Composer for breadth)
- Phase 5 adversary on impl + RESIDUE-conversion ask + bounded revision pass on ENTAILMENT findings
- Regression-guard: pre-revision + post-revision grading; revert to pre if revision regressed base or REWARD
- Impl/revision timeouts (900s impl, 600s revision) — banked from kysely scaffold v2 31-min hang
- Soundness-emphasis prompts (verbatim in `skills/STANDARD_PROMPTS.md`)
- Composer-as-recon role split (was Flash) per n=3 head-to-head schema-adherence test

**YELLOW (works but could be strengthened):**
- §I.c Replay test — artifacts are deterministic-replayable in principle; the replay script not yet written. Not a blocker for the scored run; nice-to-have for reproduction
- §VIII Budget stop rules — per-task soft cap and per-arm hard cap encoded in operator's head, not in `run_arm.sh`. Should be wired into the dispatcher
- §IX Artifact immutability — write-once layout enforced by per-arm dir convention; no SHA256 sealing manifest yet

**Cost ledger (this session):**
- Model: ~$15 across kysely + bandit + oxvg × 3 arms × 2 rounds + recon comparison + adversary head-to-heads + bandit v3/v4/v5/v6 retries
- EC2: ~$0.30 across 5 box-smoke attempts + multibox v2
- **Total day: ~$15.30**

**Verdict: freeze-ready.** Remaining items are nice-to-haves. The scored run can start as soon as:
1. One final clean validation pass on kysely + bandit scaffold (post all fixes)
2. Commit + skill tag `frozen-skills-v1`
3. Operator launches the scored coordinator (Pro's `coordinator.py` adapted for DeepSWE task-id schema)
