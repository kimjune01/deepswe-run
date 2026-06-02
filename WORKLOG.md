# deepswe-run worklog — `deepswe-sub-v3` (supersedes `deepswe-sub-v2`)

Newest first. This is the **scored-run trail** for validating the methodeutic harness on DeepSWE
(feature-implementation tasks). `deepswe-sub-v1` was frozen and dispatched but aborted ~30 min in on
a credential defect; `deepswe-sub-v2` ran but was invalid — the scaffold never dispatched `compose`,
so 95% of tasks (the `mixed`-shape majority) ran build-tools-only and the null result was mislabeled
"harness no-lift". `deepswe-sub-v3` is the clean restart on the rewired driver (FEATURE-SHAPE routing
→ compose dispatch; smoke-verified RESOLVED with a real surface-matrix before re-freeze). Pre-freeze
development history is in [`WORKLOG_PREFREEZE.md`](WORKLOG_PREFREEZE.md). Per PREREGISTRATION §10/§11,
each scored tag gets its own trail.

## 2026-06-02 — v3 scaffold-only run complete; failure-mode investigation; A1/A2 fixes; codex pilot

**v3 scaffold-only run (Composer 2.5).** After the first 3-arm dispatch hit a space-vs-comma `--arms`
bug (cells ran but the coordinator's jq verdict path word-split → "box fault"; caught at ~10 cells,
$0 overage, fleet torn down), re-dispatched scaffold-only (resume, reused 39 cells). Completed
**109/109 terminal: 35 win / 16 regression-fail / 56 feature-miss = 35/107 = 32.7% raw**. One
straggler (valibot) was a cursor-agent hang (ENTAIL=0), killed manually.

**Clean-base screen + manufactured-loss accounting.** Of the 16 `base=False` regressions, only ~2 are
MANUFACTURED (flaky/broken clean base: eicrud confirmed flaky-async over 3 samples; igel clean-base
FAIL). The rest are REAL regressions — the model broke a green base (obsidian-linter x3: clean base
1177/1177 pass, model patch caused a module-not-found cascade breaking 58 suites; cliffy: TS2580
won't-compile). VERIFICATION REVERSAL banked: a single-sample clean-base screen is fooled by flakiness
(it passed eicrud once and mislabeled it "real") — flaky detection needs multi-sample. Honest scaffold
≈ **33-34%** (raw under-counts nothing; excluding the ~2 manufactured ≈ 33.3%).

**Accidental compose ablation (Hₐ₄ case, see HYPOTHESIS_GRAPH).** v2-scaffold = compose OFF (the
severed-edge bug), v3-scaffold = compose ON, same model/gate/eligible → 28% → 33% (~+5pp), read RAW
(broken-gate deflation is common-mode, cancels in the delta). Best kind of ablation: zero experimenter
df. Suggestive direction (cross-run, n~106, not paired), reversed the v2 null.

**Attribution status (honest).** We have CLEAN attribution of the MECHANISMS (the regression cause, the
gate divergence, eicrud flakiness — all deductive/confirmed) but NOT of the NUMBERS: 32.7% under-
attributes the harness (it includes ~14 self-inflicted regression losses from the A1/A2 bugs, live
during v3); the +5pp compose lift is cross-run not paired; flaky exclusion is post-hoc. Clean number-
attribution needs v4 (fixes + pre-screened eligible + within-run compose-paired arm).

**Failure-mode taxonomy (/investigate).** Branch A (16 regressions): my "conditional guard / ENTAIL=0
gap" abduction was REFUTED — 15/16 had ENTAIL>0 (guard ran). Real sub-modes: **A1** (3) revision broke
base, guard tried to revert, but `git checkout -- . ; git clean ; git apply` FAILED on a diverged tree
("patch does not apply" / "already exists") — same broken-reset class codex caught for compose; **A2**
(~12) the INITIAL impl broke base (pre-revision base=FAIL 4/4 sampled) and there was no regression gate
on the initial impl — only post-revision, only relative to pre; **A3** (1) cursor-agent hang.
Branch B (56 feature-misses): dominated by MODEL ceiling (pwntools NotImplementedError stub, clack
missing fallback, near-misses, perf) — harness can't manufacture capability.

**A1+A2 fixes (both arms, working tree — v4 prep, not yet re-frozen).** A1: revert now
`git reset --hard $BASE_SHA && git apply pre-rev.patch` (full reset + re-apply) — validated by a
synthetic git test reproducing the exact "patch does not apply" and showing the new path restores the
pre-revision tree. A2: grade the initial impl UNCONDITIONALLY; trigger the repair pass on
`ENTAIL>0 OR base-regressed`; feed the base failure into the repair prompt — validated by mock-grade
control-flow (enters repair on ENTAIL=0 + base-regress, where the old harness skipped). Integration
validated by a live cliffy smoke (pipeline ran end-to-end, conditional logic didn't false-fire when
base passed). Cost note: A2 adds an unconditional grade + more repair passes per cell → v4 pricier
per cell (no Composer for the grade; Composer only for the extra repairs).

**Codex pilot (gpt-5.5 xhigh, subscription budget — $0 Composer).** Head-to-head on
abs-stepped-slices, a clean Composer feature-miss (off-by-one): **Composer reward=0 → codex reward=1**
(base+new pass; codex's initial impl already won). n=1, on the easy end (near-miss), but a clean
positive signal that the feature-miss bucket is model-ceiling and a stronger model lifts it. A1/A2
codex arm ran clean end-to-end.

**gpt-5.5 minimal-harness baseline (lookup).** baseline-codex xhigh canary ≈ **50%** (n=8, thin);
the n=33 codexrun2 number (33%) was the crippled `reasoning_effort=none` default and is NOT
representative. scaffold-codex (full harness) ≈ 62% (phaseb, n=8). So **the MODEL is the bigger lever**
(gpt-5.5 minimal 50% >> Composer 33%, ~+17pp) and the harness is the smaller one (~+5–12pp). All n=8,
noisy, pre-A1/A2-fix.

**codex reasoning default = `none` (footgun + legibility finding).** Bare `codex exec -c model=gpt-5.5`
runs at reasoning_effort=`none` (crippled) → ~33%; xhigh → ~50%. ~17pp swung on the flag alone. Our
harness forces xhigh at all 3 sites. Reproducing DeepSWE's 70% REQUIRES xhigh explicitly — the default
silently deflates, an unlabeled methodology gap worth noting in the auditing-deepswe vein.

**Contamination framing (operator).** Open-source repos → gpt-5.5 KNOWS the codebases (fine, realistic
prior) but not necessarily the SOLUTIONS. Clean-vs-spectacle hinges only on SOLUTION-originality: is the
requested feature absent from the repo's pre-cutoff history? Repo-familiarity is not contamination;
memorized solutions are. OPEN: per-task upstream-originality check (started on abs-stepped-slices'
`value[start:end:step]`; not yet resolved) to label a codex run clean vs spectacle.

**H_ceiling RETRACTED.** Earlier "Composer can't beat 70% → model is the lever → kill" rested on
DeepSWE's leaderboard 70%, which june.kim/auditing-deepswe already showed is fudged. No real 70% to
lose to; the deliverable is the independently-verified clean number. Bench-score attempt reinstated.

**v4 spec (emerging, not yet cut — validate before freezing):** A1+A2 (done) + eligible pre-screened
clean-base-green (manufactured losses gone by construction) + within-run compose-paired arm (clean
attribution) + decide craft model (Composer = clean claim if cutoff predates tasks; gpt-5.5 codex =
higher + budget-free, clean IFF solution-originality verified). Expected: Composer scaffold ~35% (±~5pp
noise); gpt-5.5 scaffold ~50-60%, model-dominated.

## 2026-05-31 (night) — codex sniff on the v3 driver → 2 real fixes, v3 re-cut pre-dispatch

**Codex (gpt-5.5, high) reviewed the v3 `run_arm.sh` diff before dispatch.** Five flags; triaged
against the code (the script is `set -uo pipefail`, no `-e`):
- **Real (High) — compose reset incomplete.** `git checkout -- .` misses staged/committed edits, so a
  compose that `git add`s or commits would pollute the impl baseline. Fixed: `git reset --hard
  "$BASE_SHA"` + `git clean -fd -e <env dirs>` (commit-state-agnostic; preserves untracked env +
  container-shipped ignored files, no `-x`). Validated: reset undoes a simulated compose commit, source
  edits, and stray files while preserving untracked `.venv`/`node_modules`.
- **Real (Medium) — parse mis-routes punctuation.** `FEATURE-SHAPE: invariant.` or `` `mixed` ``
  silently defaulted to `enum` (the exact silent-misroute class v3 fixes). Hardened: extract the bare
  token from after the colon (punctuation/backtick-tolerant), with a `one of` / `|` guard against
  template-echo. Validated on all 5 edge forms + full corpus re-sweep (8/2/157, 0 defaults, unchanged).
- **False — gate not pathspec-symmetric.** Codex hallucinated a `:!$OUT` exclude in the capture; there
  is none, and `$OUT` (`results/…`) is not under `$WORK` (`/tmp/arm-…`). Gate and capture share the
  same artifact-dir exclude set. No change.
- **Moot (claimed High) — pipefail exit on parse.** No `set -e`, so a no-match grep doesn't exit the arm;
  added `|| true` anyway as intent-documentation.
- **Accepted residual (Medium) — `clean` without `-x`.** Deliberate: `-x` would nuke container-shipped
  ignored files the grade needs. `reset --hard` covers the realistic vector; compose empirically writes
  nothing (smoke patches were source-only).

**v3 re-cut, not v4.** v3 was frozen but **never dispatched** (zero scored artifacts, unpushed), and the
codex sniff is part of freeze validation. Re-cutting the `deepswe-sub-v3` tag at the corrected commit is
honest and avoids version inflation; no published provenance references the old SHA. Only `run_arm.sh`'s
hash moves.

## 2026-05-31 (night) — FIX: deterministic clean-diff gate (commit-state capture hole)

**Operator catch.** "Make sure a deterministic gate is in place for a clean diff — I think I caught
Composer forgetting to commit once." Real silent-failure class, confirmed by synthetic git test.

**Bug.** All impl/patch captures used `git add -A && git diff --cached` — index **vs HEAD**. When the
craft model *commits* its work, HEAD advances, the working tree matches HEAD, `git add -A` stages
nothing, and the diff comes back **empty** — even though real work sits in HEAD. Grade still passes
(it `docker cp`s the actual files), so the cell reports `reward=1` with an **empty `model.patch`**:
broken provenance, and worse, the "revert to pre-revision" path would `git apply` the empty patch and
nuke the impl back to base. Synthetic proof: model edits+commits → old capture **0 bytes**,
base-relative capture **110 bytes**.

**Fix (two layers).** (1) All four captures (both scaffold arms' pre-Phase-5 diff + the final
`model.patch`) are now base-relative: `git diff --cached "$BASE_SHA"` — captures committed + staged +
unstaged, commit-state-agnostic. (2) A deterministic gate after capture asserts `ws_changed ⟺
patch_has_diff` (tree-differs-from-base, artifact dirs excluded, IFF `model.patch` has ≥1 hunk);
mismatch → `INFRA_PATCH_CAPTURE` (`CAPTURE_FAULT`, prereg §4), halt + re-run byte-identical. Receipt
at `audit/clean-diff-gate.json`. The base-relative capture makes the empty-patch case impossible at
the source; the gate is the backstop that fails loudly if any future capture path regresses.

**Also banked this pass.** The compose workspace reset narrowed from blanket `git clean -fd` (which
nuked the untracked `.venv` — latent `node_modules`-wipe risk across 109 repos) to
`git clean -fd -e .venv -e node_modules -e __pycache__ -e .tox -e dist -e build -e '*.egg-info'`,
matching the diff's own exclusion set.

## 2026-05-31 (night) — FIX: wire the severed FEATURE-SHAPE routing edge → compose dispatch in `run_arm.sh`

**Root cause (final, git-confirmed).** The driver never routed on `FEATURE-SHAPE` and never dispatched
`compose`. `git log -S compose -- harness/run_arm.sh` shows the scaffold arm has been build-tools-inline-only
since its first commit (`95940ff`) — there was no prior wiring to restore. What advanced was the *skills
layer*: `compose/skill.md` was written, the monoidal contract added, and the `FEATURE-SHAPE:
enum | invariant | mixed` predicate inserted into `design-doc/skill.md`. The *driver* was never connected
to consume it. That is the "didn't wire the thing back together" — the skills moved forward, `run_arm.sh`
stayed on the old inline path. This is the harness-level twin of the structural finding below.

**Blast radius (why it matters).** Of 167 captured design-docs: **157 `mixed`, 1 `invariant`, 8 `enum`**.
So ~95% of tasks should have routed through compose (`mixed` = build-tools *then* compose) and **zero
did** — every cell ran build-tools-only, producing exactly the coverage-hole the compose skill's own doc
warns about (the F₁₆ oxvg pattern: named surface tested, inferred-axis surface missed). The null result
("harness no-lift", Hₐ₁₁) was therefore measuring build-tools-only on tasks whose own design-doc said the
named surface is insufficient — **the lift the ablation was built to detect was the compose phase, and the
compose phase never fired.**

**Fix.** `run_arm.sh` Phase 2 in both scaffold arms (Composer + codex) now parses `FEATURE-SHAPE` from
the design-doc output and routes: `enum` → build-tools (unchanged), `invariant` → compose, `mixed` → both.
Unparseable shape defaults to `enum` (build-tools always fires — safe). The **compose slice** is a new
in-workspace dispatch (cursor-agent `--workspace $WORK` / codex read-only-sandbox rooted at `$WORK`) because
compose's load-bearing step is *reading the codebase to infer the unstated surface* — the structural
difference from build-tools' codebase-blind PRD-read. It emits a surface-matrix (axis + `file:line`
provenance + deduction/abduction marks) and paired control/perturbation tests, captured to
`audit/compose-gate.txt` + `audit/feature-shape.txt`. The union (`build_tools ∪ compose`) becomes `$PG_OUT`,
fed to the Phase 3.5 + Phase 5 adversaries exactly as before.

**Why minimal-but-faithful (decision recorded).** The scored arm's reward is `dsr grade` (the hidden
oracle); the proxy gate's only role is to feed the adversary reviews. The JSON-manifest / `dsr gate` path
is **isolate-only** and unused in the scored arm. So the faithful fix adds compose as the sibling phase
routed by `FEATURE-SHAPE`, leaving build-tools' enum path and **all baselines byte-for-byte unchanged**.
Going full skill-file-dispatch-with-manifest would also rebuild the enum path and drag the isolate
machinery into the scored arm — a far larger treatment change for no gain in what the adversaries see.

**What this run now is.** With compose firing on the 157 `mixed` tasks, the scored run becomes the
long-deferred measurement of **Hₐ₄** (compose *case* confidence, stuck at 30 — "machinery built, case
unfound; oxvg refuted") and **Hₐ₅** (the monoidal contract, asserted in prose, never measured). The corpus
is overwhelmingly mixed-shape — exactly the substrate `COMPOSE-EVOLUTION.md` names as the open frontier.

**Parser hardening (deterministic double-check, no keys).** Routing parse runs against all 167 captured
design-docs: 8 `enum`, 2 `invariant`, 157 `mixed`, **zero defaults**. First pass missed oxvg — the one
`invariant` task — because it emits the design-doc skill's *canonical* header form (`## FEATURE-SHAPE`
then `` `invariant` ``) rather than the terse `FEATURE-SHAPE: invariant`. That header form is exactly what
real skill-dispatch would produce, so the parser now handles both (terse anchored after the colon to dodge
template-echo false-matches; header-form fallback scanning the next lines for a bare token). Same bug class
as the top-level fix: driver expectation diverging from skill emit format.

**Known minor (recorded, not blocking).** Phase 3.5 reviews the full untruncated `$PG_OUT` (where gate
review matters most). Phase 5 still truncates `$PG_OUT` to 5KB for impl-review context, so on a long
`mixed` gate the appended compose slice can be clipped there. Acceptable for now (Phase 5 is impl-focused);
revisit if Phase 5 review quality on mixed tasks looks gate-starved.

**Process note (operator + mine).** Operator: "I didn't actually watch the run carefully." Mine: same miss
named below — drove a campaign as "validate the methodeutic harness" without verifying the driver emits
what the skill specifies. Discipline going forward: the double-check is **artifact-level and pre-dispatch**
— confirm `audit/feature-shape.txt` + `audit/compose-gate.txt` land with a real surface-matrix on a `mixed`
task BEFORE any box is dispatched, not after. Verify the receipt, don't eyeball the live run.

**Next:** new prereg + re-freeze (`deepswe-sub-v3`); pre-dispatch smoke on a known `mixed` task; then re-run.

## 2026-05-31 (evening) — STRUCTURAL FINDING: the scaffold ran typed-acceptance, NOT the methodeutic hypothesis-graph harness

**Operator catch.** "Is it even producing hypothesis graphs?" → No. The scaffold's audit artifacts are
`design-doc.md` (typed-acceptance: FEATURE-SHAPE / TYPED-INTERFACE-SURFACE / PRD-HARD-NEGATIVES /
ACCEPTANCE-CRITERIA / RESIDUE) + proxy gate + adversary reviews. **No hypothesis-graph artifact, no
kill conditions, no inquiry loop.**

**Root divergence.** `skills/design-doc/skill.md` IS methodeutic (line 21: "Append your nodes to the
hypothesis graph the adapter names"; Peircean confidence-by-mode). But `run_arm.sh:210` does NOT run
the skill — it sends its own inline `DDP` prompt (mirrored in `STANDARD_PROMPTS.md`) that asks for the
**typed-acceptance schema only**, zero hypothesis-graph. So the harness diverged from the skill: it
implements a linear typed-acceptance → proxy-gate → impl pipeline, dropping the hygraph smem, the
abduction/kill-condition inquiry loop, and trajectory-shape gating — the methodeutic harness's
defining core.

**Consequence (the runs are the WRONG ablation).** Every scaffold run today (sub-v2 Composer + the
codex runs) tested the **typed-acceptance pipeline**, not the hypothesis-graph methodeutic harness the
operator ordered. Re-scoping the findings:
- Hₐ₁₁ "harness no-lift" → narrows to "**typed-acceptance pipeline** ≈ single-agent Composer (p=0.51)",
  NOT "the methodeutic harness fails." Mislabeled.
- Hₐ₁₂ (general > specialized) → stands; model-level, scaffold-independent.
- Hₐ₁₃ (test-writing) → partly relevant (build-tools is a test-writing stage) but the inquiry loop was
  never exercised.

**Path to the ordered ablation (real harness build, not a flag):** run_arm.sh must (1) send the
hygraph-producing design-doc prompt per the skill, (2) name + capture a per-instance hygraph, (3)
thread it as smem through build-tools → implement-spec → audit, (4) run the kill-condition/gate loop.
DECISION PENDING (operator): rework to methodeutic vs bank typed-acceptance result + schedule the build.

**Process miss (mine):** drove the whole campaign as "validate the methodeutic harness" without ever
verifying the harness emits hygraphs. Two operator skepticism prompts (reasoning-effort, then hygraphs)
surfaced both defects. Verify the artifact matches the claim BEFORE the scored run, not after.

## 2026-05-31 (evening) — codex run HALTED: `reasoning_effort=none` defect (leaderboard reconciliation)

**Trigger.** Operator skepticism: DeepSWE leaderboard puts gpt-5.5 at **70%**; our baseline-codex was
running **~30%**. Too big to dismiss.

**Defect (confirmed).** `codex_call` + the 2 direct `codex exec` blocks in `run_arm.sh` passed only
`-c model=gpt-5.5` with **no reasoning flag** → codex CLI default is **`reasoning_effort: none`**
(verified live: bare `codex exec -c model=gpt-5.5` banner reads "reasoning effort: none"; the
leaderboard's 70% was gpt-5.5 at **xhigh**). So both codex arms measured a *crippled* gpt-5.5. The
70→30 gap is **our config**, not the leaderboard (its separate reproducibility issues from the audit
still stand). Confounded the Hₐ₁₂ comparison too: Composer at full cursor-agent reasoning vs codex at
*none*.

**Action.** Halted the none-run at ~21% (codexrun2-20260531), torn down clean, 0 orphans. The
partial none-numbers (scaffold-codex 7/22, baseline-codex 7/24) are kept only as *gpt-5.5-at-none*
exploratory, NOT a capability read. Fixed all 3 codex exec sites to
`-c model_reasoning_effort="${DSR_CODEX_REASONING:-xhigh}"` (matches leaderboard; configurable).
Frozen deepswe-sub-v2 Composer/Flash results untouched (don't use codex).

**Canary.** baseline-codex at xhigh on the first 8 tasks (2 boxes) to confirm the jump toward ~70%
before committing the full (slow, quota-heavy) xhigh run.

## 2026-05-31 (evening) — §3b codex secondary launched (the Hₐ₁₃ decider)

After deepswe-sub-v2 completed + torn down (freeing spot quota), launched the §3b within-model
two-harness secondary on **8 spot boxes**: `scaffold-codex` vs `baseline-codex`, GPT-5.5 via codex
CLI subscription, 218 cells, under the **deepswe-sub-v2 freeze** (`0336f49`) — same frozen harness,
codex arms. Run-tag `codexrun2-20260531`. Dispatched 18:17, subscription-paced (hours).

**Purpose:** the decisive test of Hₐ₁₂/Hₐ₁₃ (operator bet) — does the harness HELP a general-purpose
model where it did NOT help coding-specialized Composer? Δ = scaffold-codex − baseline-codex; the
**sign** decides (Δ>0 confirms test-writing/specialization, immune to the capability confound because
it's a within-model delta).

**Provisioning saga (4 attempts — fleet.sh fragility, retro item).** (1) parallel-on-demand →
`MaxSpotInstanceCountExceeded` (spot quota L-34B43A08 = **32 vCPU = 8 boxes**; on-demand L-1216C47A =
128 vCPU is a separate pool). (2) on-demand 10-box → 4/10 empty-IID (rapid `run-instances` throttle).
(3) spot reused-tag → `InvalidKeyPair.NotFound` (tag collided with cleaned-up keys). (4) **fresh-tag
spot → clean.** Cleaned up after each (~$0.20 waste, zero orphans). Added `MARKET=on-demand` to
fleet.sh (`1e06d8a`); provision loop still needs retry-on-empty-IID + no-reused-tags hardening.

## 2026-05-31 (afternoon) — deepswe-sub-v2 COMPLETE: harness-richness thesis UNSUPPORTED

**Run.** 327 cells (109 × {scaffold, baseline-comp, baseline-flash}), 8 spot boxes, dispatched 10:33,
complete + torn down 18:12 (~7.5h wall), 0 orphans, ~$3 EC2. Flash adversary live throughout
(adv-flash.txt 6/6 non-empty at scale; v2 fix held). scaffold 100% real verdicts, 0 infra-fails.

**Final results.**
- scaffold **30/106 = 28.3%** Wilson[20.6, 37.5] — 3 INCOMPLETE (gql/sqlfmt/valibot heavy-tail
  ceiling-faults, classified INCOMPLETE not LOSS per fault taxonomy).
- baseline-comp **36/109 = 33.0%** Wilson[24.9, 42.3].
- baseline-flash **0/109 = 0.0%** Wilson[0, 3.4].
- **McNemar scaffold vs baseline-comp (106 paired):** scaffold-only 16, comp-only 21, discordant 37,
  **exact two-sided p = 0.51 → NOT significant.**

**Finding (honest, corrected).** The harness-richness thesis — scaffold beats single-agent Composer —
is **UNSUPPORTED** on DeepSWE feature tasks. The live-run read of "scaffold underperforms" is
**walked back**: the arms are statistically tied (CIs overlap, p=0.51). The harness does not earn its
complexity at a fixed coding-specialized model. They win DIFFERENT tasks (16 vs 21 discordant) — helps
some, hurts others, nets ≈0.

**Hypotheses opened (see `harness/feature/HYPOTHESIS_GRAPH.md`):** Hₐ₁₁ (harness no-lift), Hₐ₁₂
(general-purpose > coding-specialized on prose-shaped tasks — the whole optimistic graph H₁–Hₐ₁₀ was
built on Sonnet/codex, swapped to Composer/Flash; transfer-risk warning fired), Hₐ₁₃ (test-writing ≠
test-passing; harness leverage is the test-writing stage). Hₐ₁₃ localization MIXED (2 proxy-green/
official-red = test-writing failure, ~5 proxy-red = test-passing failure) → partial only.
baseline-flash 0% is the Hₐ₁₂ axis at its extreme (most coding-tuned model, prose tasks, total fail).

**Decider deferred to the §3b codex run** (above): does the harness help a general-purpose model?

## 2026-05-31 — `deepswe-sub-v1` ABORTED → restart as `deepswe-sub-v2` (failure class: silent Flash-adversary disablement)

**Failure class.** `INFRA_ENV / silent-adversary-disablement`. The Phase 3.5 cross-family **Flash
soundness adversary was silently dead on every box**, and the `baseline-flash` arm was 100%
non-functional — both producing empty/FATAL output. Caught ~30 min into the v1 scored run by the
health-check monitor (1 RESOLVED in the first ~11 verdicts, a cluster of fast `UNRESOLVED_NO_DIFF`).

**Root cause (codex-corroborated).** The driver bootstrap symlinked the uv-venv's python outside the
venv (`ln -sf .dsr-venv/bin/python /usr/local/bin/python3-dsr`). A venv python symlinked outside its
venv loses `pyvenv.cfg` discovery and falls back to the base interpreter, where `google.generativeai`
is absent → `gemini_api.py` FATALs. The bootstrap's genai assert used the *direct* venv path, so it
passed (`CREDS_INSTALL_OK`) and masked the bug. Decisive evidence: the v1 smoke's `adv-flash.txt` was
0 bytes even though that run RESOLVED — scaffold tolerates a dead Flash lens (backgrounded,
`2>/dev/null`), so the defect never surfaced in earlier scaffold-only smokes. The `baseline-flash`
arm, which depends entirely on Flash, exposed it.

**Fix.** `fleet.sh` bootstrap: replace the symlink with a wrapper script
(`#!/bin/sh; exec .dsr-venv/bin/python "$@"`) that preserves the venv exec path, plus a
`python3-dsr -c 'import google.generativeai'` assertion so the failure is loud at bootstrap, not
silent at runtime. The frozen harness code (`run_arm.sh`, `gemini_api.py`, skills, `HASHES.txt`
artifacts) is **unchanged**; only the driver's provisioning changed. Re-smoke confirmed at the
artifact level: scaffold `adv-flash.txt` = 4655 bytes (real soundness review), baseline-flash emits a
real Flash diff.

**Why a new tag.** The frozen hash set is identical, but the *effective treatment* changed — the
scaffold's documented dual cross-family adversary (Flash soundness + Composer breadth) was running as
Composer-only and is now genuinely dual. Honest provenance requires marking the boundary, so
`deepswe-sub-v2`'s freeze SHA pins the fixed driver. v1 produced no valid headline (aborted as
invalid); its ~$0.40 of EC2 is the cost of the canary discipline working as intended.

## 2026-05-31 — FREEZE `deepswe-sub-v1`, begin scored run

## 2026-05-31 — FREEZE `deepswe-sub-v1`, begin scored run

**Freeze SHA:** `d675d4690f328464d62a2c30cee27279faa27962` (tag `deepswe-sub-v1`).

**What is frozen.** The methodeutic harness for PRD-shaped feature tasks (design-doc → build-tools →
Phase 3.5 dual cross-family adversary → implement-spec → Phase 5 + RESIDUE re-type → bounded
regression-guarded revision), Composer 2.5 craft/recon + Gemini 3.5 Flash adversary. `frozen/HASHES.txt`
regenerated at the freeze SHA and verifying (13 artifacts). `frozen/eligible.txt` = 109 tasks
(113 − 4 documented gold-fails-verifier defects per `audit-v1`). `frozen/COMPARISONS.txt` declares
the pre-data comparison: primary = three-arm harness-richness ablation (scaffold vs `baseline-comp`
vs `baseline-flash`), two paired McNemar tests at Bonferroni α=0.025; secondary (exploratory, §3b) =
codex two-harness at GPT-5.5.

**Why this freeze, why now.** Goal: validate the methodeutic harness on DeepSWE — a new
feature-implementation instantiation of the IR, not the recon/craft/audit bug-fix harness validated
on Verified/Pro. The scaffold resolve rate is the validation; the scaffold-vs-`baseline-comp`
ablation (model held fixed, harness toggled) is the clean typed-mode on/off isolation the
methodeutic-harness paper names as missing future work.

**Pre-freeze validation discharged (in `WORKLOG_PREFREEZE.md`).** Phase A n=10 Composer/Flash scaffold
(40% RESOLVED); three end-to-end canary smokes through the frozen `fleet.sh` driver — `scaffold-codex`,
api-mode `scaffold` (Composer/Flash), and the multi-box paired dispatch — each RESOLVED reward=1 on
`abs-module-cache-flags`. Post-v2 harness improvements folded in and re-hashed: the grade-NA fix
(`git config safe.directory '*'` in `dsr.py`), `revert_test_files_in_workdir` source-only-discipline
inserts in `run_arm.sh`, and the codex arms (inert for this run; used only in §3b).

**Run config.** 8× m7i.xlarge spot, us-west-2, ~$0.09/hr. 109 eligible × 3 arms = 327 cells,
1 trial/cell. Coordinator ceiling 2400s, max-attempts 2, ledger-resumable. Budget: ~$6 EC2
(authorized ≤ $20), Composer/Flash marginal-zero on subscription + free gemini-cli.

**Fault runbook (banked from `swebench-pro` worklog).** Watch the ledger for: a fast-fail wave
(sub-2-min cells with 0-byte patches + 401 strings → `PROVIDER_CRED_REJECT`, halt + re-push creds +
resume); cells past p95 / over-ceiling (grader-side flake → SSH in before assuming capability loss);
box death (account guardrail at 00:00 PT → re-provision + re-dispatch, coordinator skips terminal
verdicts). Run launched ~09:30 PT, ~7h wall, finishes before the midnight guardrail.

## 2026-06-02 — codex-hard pilot + A3 coordinator fix (/investigate) + liveness-vs-emission lesson

**Codex-hard pilot.** Ran `scaffold-codex` (gpt-5.5 via codex CLI, $0 subscription) on a diverse set of
v3 Composer LOSSES, to test the "model is the bigger lever" thesis on the HARD cells specifically (not
just the easy abs-stepped-slices flip). 4-box fleet, EC2-only cost (~$0.20/box-hr). Cells: pwntools,
dynamodb-toolbox, cattrs, wasmi (wave 1) + bandit-taint, numba-stencil, go-git-worktree, participle.

Results harvested so far (emission-verified, not liveness):
- cattrs-partial-structuring-recovery: reward=1 — codex FLIPPED a Composer loss.
- pwntools-tube-multiplexing: reward=0 — SHARED wall (base passes, new fails on both models). The
  hard cells produce shared walls, not a clean sweep: model lever is real but bounded.
- bandit / dynamodb / numba / wasmi / go-git / participle: in flight via the fixed coordinator.

**A3 CONFIRMED + EXTENDED (/investigate, graph in HYPOTHESIS_GRAPH.md 2026-06-02).** The dispatch hit
the coordinator ceiling bug hard. Four coupled defects, all confirmed (deduction + induction):
- D1 orphan: `subprocess.run(ssh, timeout=ceiling)` kills the LOCAL ssh; the remote run_arm.sh (no
  `ssh -t`, reparents to init) keeps running. Two live codex procs observed after "fault".
- D2 double-dispatch: worker retries the SAME box while D1's orphan runs → two pipelines, one results
  dir. Same-task confirmed (`run_arm.sh wasmi` x2).
- D3 lost late-completion: remote finishes just after the ceiling; verdict discarded. pwntools
  grade.json mtime 14:39:18, ceiling fired 14:36 — 3min late, single attempt. Decisive mtime evidence.
- D4 ceiling miscalibration (the TRIGGER): sibling SWE-bench Pro uses the IDENTICAL pattern but
  ceiling=36000 ("never-fires backstop"); deepswe inherited it with 2400, far below codex's pace
  (pwntools needed 43min). The orphan is latent in Pro too; Pro just never fires it.

**Fix (coordinator.py, 9/9 synthetic tests, gemini 3-round bug-hunt):** (1) remote self-limit
`timeout -k 60 -s TERM {ceil}s bash run_arm.sh`, local SSH = ceil+300 backstop; (2) `cleanup_box`
scoped pkill before every attempt; (3) `harvest_grade` recovers a grade gated on the
revision-decision.txt completion marker; (4) `remote_ceiling` floors codex arms to 6000s. Gemini
caught two real bugs the prose review missed: inline-verdict bypassing the completion gate on the
kill path (fixed: trust inline ONLY when RUNARM_RC=0, since the remote `;`-chain ends in `echo` so
the local rc is a dead signal), and a clean-exit parse-fail discarding a finished verdict (fixed:
fall through to harvest). r3 converged.

**LIVENESS != HEALTH (operational lesson).** I reported 4 boxes "healthy" off a process count
(`run_arm=1`); switching to the emission criterion (newest-artifact / log mtime recency) exposed that
all 4 were DEAD — the surviving process was a lingering orphan codex, no run_arm driving it, zero
files written in 30+ min. ~1h45m of EC2 burned on stalled boxes I had called healthy. Root cause of
the deaths: manual `nohup ... &`-over-SSH relaunch did not persist (SIGHUP on channel close; the log
file never got created, which was the tell). run_arm.sh itself is fine (proven synchronously).
Recovery: re-dispatched the 6 remaining cells through the FIXED coordinator (holds SSH open, remote
self-limits, cleans orphans), and replaced the liveness monitor with an emission-recency monitor that
flags STALE on >15min of no log growth. Health is now inferred from recent emission, never liveness.
