# Pre-registration — legible skills + the harness-richness experiment

A living development document **until we commit to a scored run**, at which point it is frozen
(§10). This binds a *measurement*, not exploratory work. Rigor is held at parity with the SWE-bench
Pro pre-registration it is modeled on (`../../swebench-pro/PREREGISTRATION.md`).

## 0. Goal & posture (what this is *for*) — amended 2026-05-30

**This project is one stage of a prose compiler** (PRD-shaped prose in, gradeable software
artifacts out). The stage we publish here: PRD → typed-acceptance design-doc → discriminating
proxy-gate test suite → implementation → cross-family-audited revision. Other stages of the
broader prose compiler (PRD discovery, deployment, observability) sit upstream and downstream
of this one and are not part of this release.

Three deliverables, ordered by durability:

1. **The compiler stage** (`skills/{design-doc,build-tools,compose,implement-spec,verify-spec}/`
   + `skills/STANDARD_PROMPTS.md` + the typed-acceptance protocol + the RESIDUE.md cross-phase
   carry-forward mechanism + `dsr` CLI shell). Well-defined I/O contracts so other compiler
   stages can chain in front or after. Reusable on any PRD-shaped feature spec with any
   coding-capable LLM that responds to schema-tight prompts. **This is the artifact that
   travels.**

2. **The bench measurement that validates the stage (two-harness within-model).** Same model
   (GPT-5.5 via codex CLI subscription) in two harnesses on the same 109 eligible tasks:
   our compiler stage (Arm A) and codex CLI alone (Arm B). McNemar paired delta + Wilson 95%
   on each marginal. DeepSWE's published 70.05% gpt-5-5 in mini-swe-agent is cited as an
   external reference point, not part of the paired stats. See §3a for full arm specifications.

3. **The methodology essay** — now with three observations, not one:
   (a) Cursor structurally prevents independent measurement of Composer 2.5 (model locked to
   cursor-agent CLI + Cursor IDE, no public API). The model-vs-system collapse the DeepSWE
   audit identified now visible in a vendor-stack instance.
   (b) Every benchmark number is a harness number. There is no "model alone" to measure. The
   publishing convention (`gpt-5-5 → 70.05%`) is a useful fiction. The honest sentence is
   always `<model> in <harness> at <config> → X%`. This isn't a niche observation; it's
   structural to how benchmarks operate.
   (c) The bench's job (per §0 of any honest leaderboard) is to discriminate between candidate
   improvements to BOTH the model layer and the harness layer. DeepSWE's post foreclosed the
   harness axis ("mini matches or beats native CLIs"); our project demonstrates a counter-
   example. The bench-as-discriminator deserves to be defended against local optimizations
   (publisher foreclosure posts, vendor API gating) that work against its stated purpose.

The framing matters: **a measurement-run that happened to surface a reusable compiler stage**
is the wrong order. The stage was designed first, validated on DeepSWE as the substrate that
demanded it. The measurement is the receipt, not the headline.

**Prior framings dropped (timeline of amendments):**

- 2026-05-27 original: "match/beat DeepSWE on 113 tasks via richer harness; submit PR."
  → Datacurve dropped as recipient (won't engage; no submission path).
- 2026-05-28: "harness-richness ablation: scaffold vs single-agent cursor-agent vs single-agent
  gemini-cli, paired Fisher exact." → switched to McNemar (paired binary, not 2×2). Switched
  baseline pair from Sonnet+GPT-5.5 to Composer+Flash (~10× cheaper).
- 2026-05-30 first reframe: "two publishable numbers: Composer in mini-swe-agent + scaffold,
  paired McNemar at α=0.05." → discovered Cursor's API gating prevents Composer-in-mini.
- 2026-05-30 final reframe (this section): **drop the comparison entirely.** The skill
  collection is the durable artifact; the measurement is one validation; the methodology
  observation is the narrative wrapper. No comparison baseline, no comparison statistic.
   2026-05-29 Fisher→McNemar amendment and the 2026-05-30 drop of the secondary Gemini baseline.)
   The harness delta is **measured**, not asserted.

   **Primary model pair amended 2026-05-28** from Sonnet 4.5 + GPT-5.5 to Gemini 3.5 Flash +
   Composer 2.5 — both ~10× cheaper at comparable coding capability, keeping the full-suite
   ablation budget under ~$200 all-in instead of the Max-subscription window the earlier pair
   required. Setup, smoke tests, and key hygiene in [`docs/PROCEDURES.md`](docs/PROCEDURES.md).

   **Role-split (added 2026-05-28, mirrors `swebench-pro/PREREGISTRATION-cheap-ablation.md` §1.1).**
   Stage assignment is role-specialized: **Composer 2.5 is the craft model** (writes the
   implementation patch + the proxy-gate tests — impl strength where it pays); **Gemini 3.5
   Flash is the recon/adversary model** (cheap divergent abduction in design-doc; adversarial
   critique of Composer's craft diff). Audit deterministic. Cross-family preserved (Cursor-Kimi
   × Google-Gemini). The hypothesis under test, shared with the sibling Pro run: *match model
   to stage, not symmetric pair.* Skill-side wiring via `$DSR_CRAFT_MODEL` /
   `$DSR_ADVERSARY_MODEL` env vars (see `harness/bootstrap.sh`).

**The honest hazard (named so it can be guarded).** We *want* the heavier-scaffold result; that is
exactly the precondition for motivated reasoning. The preregistration, blind/official grading, and
the commitment to report the delta **even if the scaffold loses** are what make "we dispelled the
myth" credible rather than our own under-powered slice. The narrow claim, stated boldly: *for these models,
this scaffold, these 113 tasks.* No generalization beyond that without more benches.

## 1. Predicate (a result is admissible iff all hold)

1. **General** — the scaffold is instance-blind; no per-task tuning, no reading DeepSWE `solution/`
   dirs (they are held out from the agent by us, not just by the harness).
2. **No leakage** — verifier reward is never an iteration input; one frozen scaffold version, one
   scored pass over all 113.
3. **Official-attested** — the bench is the **113 Harbor tasks + each task's own verifier**
   (`tests/test.sh` + held-out `test.patch`, run in the task image), *not* any one runner. A win is
   that task verifier's reward on the captured diff. No bespoke grader: the verifier is executed
   unmodified (via Pier as the verifier executor, so the grading is demonstrably theirs). Pier's
   *only* load-bearing role is grading; our agent does not run through it.
4. **Honest denominator** — exclusions are documented defects only (§4 audit), reported as a count
   with reasons; a defect is never our failure relabeled.
5. **Reproducible** — frozen tag, re-derivable from committed per-trial artifacts, runnable by a
   third party (run our driver against `deep-swe/tasks`, grade with the task verifier via Pier).

## 2. Two modes

- **Exploratory (development):** any subset, any peek at our own trajectories, no scoreboard.
- **Measurement (a run):** freeze the scaffold → run the **whole 113** under one frozen version →
  that is the number. A pass that does not complete all 113 eligible under one frozen scaffold is an
  **aborted run, not a headline** (§3 stopping rule).

## 3. Stopping rule & run order

- No early stop. The run ends only when every eligible task has a terminal verdict (WIN/LOSS) or a
  documented defect exclusion.
- Run order is the lexicographic sort of the 113 `task_id`s from `tasks/manifest.json`, committed as
  `run_order.txt` at freeze. Order is fixed only to remove a degree of freedom from partial/resumed
  runs; it does not affect a completed measurement.
- **Restarts are unbounded but accountable:** the motivation for any scaffold change + restart is the
  opening entry of the new tag's worklog, written before that tag's run, and must name a failure
  *class*. "The last number was low" has no class to write and nowhere to hide.

## 3a. Execution environment

The scored run executes on an **EC2 fleet** driven by the SWE-bench Pro coordinator
(dynamic dispatch, fault-tolerant, `AUTH_MODE`), not on local docker. Local docker validated the
plumbing (smoke test); it does not scale to 113 × 3 passes (disk + serial wall-clock).

Two arms, two runners, one grader:
- **Scaffold arm** — our recon→craft→audit driver runs in the task's docker image (pulled from
  public ECR), produces a source-only diff. Same driver as Pro; **not** Pier-driven. Role-split
  (amended 2026-05-29 after Composer-as-recon empirical comparison; see below):
  Composer 2.5 writes craft, authors the proxy gate, AND writes the design-doc/recon
  (`$DSR_CRAFT_MODEL` + `$DSR_RECON_MODEL`, both via `cursor-agent -p -f --model composer-2.5`);
  Gemini 3.5 Flash serves as Phase 3.5 + Phase 4 cross-family adversary critique
  (`$DSR_ADVERSARY_MODEL`, via direct API per `harness/feature/gemini_api.py`); Composer 2.5
  also serves as `$DSR_ADVERSARY_BREADTH_MODEL` for the Phase 3.5 dual-adversary breadth lens.
  Cross-family property is preserved at the *adversary* step (where H₉ measured 37.9% bandit /
  11.5% kysely substantive overlap, both << 70% collapse), not at recon. See
  `docs/PROCEDURES.md` + `harness/bootstrap.sh` for the wiring.

  **Why recon moved from Flash to Composer (n=3 head-to-head on same prompt 2026-05-29):**
  Flash drifted into conversational prose on all three substrates (kysely / bandit / oxvg),
  filling schema fields with free-form text (e.g. `BRANCH: "feature/grouped-aggregation-…"`,
  treating the project-defined `BRANCH` enum slot as a git-branch name) and ending kysely's
  doc with "Please let me know if you would like me to proceed." Composer followed the schema
  on 3/3, surfaced explicit `PRD hard negatives` and `Typed-interface surface` sections
  unprompted (exactly the structure build-tools needs for axis-crossing test design), and
  flagged ambiguous PRD clauses in a `*Residue (AMBIGUOUS):*` section — applying the typed-
  acceptance discipline at recon-stage on its own initiative. Cost delta: ~$1.13 added across
  113 scaffold-arm tasks at Composer Standard rates. Receipts at
  `results/recon-comparison/composer-recon-{kysely,bandit,oxvg}-*.txt` vs the matching Flash
  outputs in `results/runs/<task>/scaffold/audit/design-doc.md`. See [[composer-2.5-review]]
  F14 + [[gemini-family-discriminator-not-generator]] memory for the broader pattern.

  **The scaffold treatment explicitly includes cross-family adversary review at proxy-author
  time (Phase 3.5) AND at impl-review time (Phase 4), with SPECULATION-typed findings carried
  forward via `RESIDUE.md`** (amendment 2026-05-29 per codex review — naming what makes the
  scaffold richer instead of hiding it under "richness"). Per `FREEZE-CHECKLIST.md` §VII,
  RESIDUE.md content is bounded: type-classification reasoning + PRD-ambiguity quotes +
  discriminating-input shapes ARE allowed; patch sketches, file-level impl plans, hidden-test
  references, and gold-patch inferences are NOT. A pre-Phase-4 hook scans RESIDUE.md and
  rejects forbidden content. The hook script + its acceptance pattern is part of the prompt-
  freeze hash (§II of FREEZE-CHECKLIST).
- **Two harnesses, model held constant (amended 2026-05-30 final-final, codex CLI subscription).**
  Both arms use **GPT-5.5 via `codex exec` CLI on a paid subscription** — same model, same access
  method, only the harness shape differs. The previously-planned Composer 2.5 scaffold is dropped
  because Cursor's API gating makes Composer unmeasurable outside their stack (see "Methodology
  essay" below); GPT-5.5 + codex CLI replaces it.

  - **Arm A — our scaffold** (the compiler stage):
    `design-doc` → `build-tools`/`compose` → Phase 3.5 dual cross-family adversary
    → `implement-spec` → Phase 5 adversary on impl + RESIDUE-conversion ask
    → bounded one-shot regression-guarded revision pass.
    Model layer: `codex exec -c model="gpt-5.5"` at each phase that needs the model.

  - **Arm B — codex CLI alone:**
    `codex exec -c model="gpt-5.5" "<PRD prompt>"` against the task's docker workspace.
    OpenAI's general-purpose agent harness; no compiler stage, no Phase 3.5/5, no revision.
    Codex CLI drives its own tool loop natively.

  **Both arms are harnesses.** Neither is "GPT-5.5 alone." This bears repeating because the
  publishing convention treats benchmark numbers as model ranks (`gpt-5-5 → 70.05%`) when the
  measurement is always of model-in-some-harness (`gpt-5-5 in mini-swe-agent at xhigh, 4
  trials → 70.05%`). Stripping the harness erases the measurement. **Every result in this
  prereg is a harness result wearing a model label by convention; the model label is the
  fiction.**

  **Trials, pacing, and budget.** 1 trial per task per arm (no pass@4 framing this run; the
  pass@1 is the reportable number). 109 eligible tasks × 2 arms = 218 trial cells. Scaffold
  averages ~5-7 codex calls per task (design-doc, build-tools, dual-adversary × 2, impl,
  Phase 5, conditional revision); codex-CLI-alone averages ~10-30 turns per task. Total
  ~3000-4000 codex calls.

  Subscription rate-limit pacing: the run executes slowly through the codex CLI subscription
  throttle (no API fallback). Expected wall: 1-3 days of pacing, ~$25-50 EC2 for that
  uptime. **Total scored-run cost: ~$25-50 EC2 + ~$1 Composer adversary calls at Phase 3.5,
  near-zero codex model spend (subscription).**

  **Why both arms are valuable on the same model:**
  - Same model: the comparison isolates harness shape from model capability.
  - Same access method (codex CLI subscription): controls for the "raw API vs CLI behavior"
    confound that would arise if we ran mini-swe-agent via litellm against the OpenAI API.
  - Same eligible task set + grader: standard pre-registered controls.
  - DeepSWE's published gpt-5-5 number (70.05% in mini-swe-agent at xhigh, 4 trials) is
    triangulated against both our arms as an external reference — not part of the paired
    stats (different methodology, different N), but cited in the writeup.

- **Statistical method.** Paired McNemar's exact on the discordant pairs across 109 tasks,
  α=0.05 (single comparison). Wilson 95% on each arm's marginal pass-rate. Effect size:
  marginal pass-rate difference + 95% CI via paired-bootstrap on the discordant set.

- **Grader (all arms)** — the task's own verifier, executed unmodified via Pier (apply `test.patch`,
  run `test.sh`), reward read identically across arms so the only variable is the harness.

Model spend is now **metered per token**, not $0-on-subscription as the earlier prereg version
recorded. Budget at standard tiers: Composer 2.5 $0.50/M in · $2.50/M out; Gemini 3.5 Flash
$1.50/M in · $9/M out paid (free via gemini-cli for adversary use). **Per-instance budget anchor:
~$0.40/task scaffold + ~$0.40/task baseline-comp (mini-swe-agent iteration loop costs more than
the previous single-shot cursor-agent baseline; estimate matches DeepSWE's own per-trial cost).**
Full-suite projection (109 eligible × 4 trials each, 2 arms only):
  - scaffold: 109 × 4 × $0.40 = ~$175 (worst case with full Phase 5 + revision on every trial)
  - baseline (Composer in mini-swe-agent): 109 × 4 × $0.40 = ~$175
  - Total: **~$350 model spend** at 4-trial-per-cell + ~$30-50 EC2.
  - At 1-trial-per-cell (still pre-registered as acceptable): ~$90 model + ~$15-20 EC2 = **~$110 total**.
A periodic `docker image prune` bounds per-box disk against image accumulation. Provenance (§7)
is pulled off-box by the same read-only daemon.

**Composer Fast tier (`composer-2.5-fast` at $3/$15) is forbidden in the scored run** — 6× markup,
~$500/arm, no measured capability gain over standard for this task class. Any deviation requires a
worklog entry naming the failure class that motivated it (§3 restart rule).

**Box bootstrap requirements (learned from the oracle audit).** Pier brings up the sandbox +
egress-proxy via **`docker compose`**, which AL2023's `dnf install docker` does **not** include
(engine only; buildx present, Compose absent). The bootstrap must install the Compose v2 plugin into
`~/.docker/cli-plugins` and **assert** `docker compose version` + `docker buildx version` (loud fail,
not a silent per-task NA). This binds the baseline arm and any pier-graded scaffold-arm run.
Operational: cancel the one-time spot request on teardown (it lingers `active` and keeps counting
against the spot vCPU limit, blocking a same-size relaunch).

## 4. Failure-mode catalog — fixed state machine (DECIDED IN ADVANCE)

Mirrors the Pro prereg §4. Per trial:

- **WIN** — Pier verifier reward == pass on the captured diff. Terminal.
- **LOSS** — verifier reward == fail on a *substantive* agent output (a real diff, full-length run).
  Terminal; stands; never re-run.
- **INCOMPLETE(fault)** — empty/aborted output from an *environment* fault, not capability. Re-run
  byte-identical. Fault classes:
  - `DOCKER_FAULT` — image pull / build / sandbox failure (ECR unavailable, OOM, disk).
  - `AUTH_OUTAGE` — model-provider auth rotation mid-run (operator `/login`, key expiry).
  - `QUOTA_EXHAUSTED` — billing wall on `CURSOR_API_KEY` or `GEMINI_API_KEY` → **PAUSE**,
    resume when budget refreshes (operator action) or the rate limit lifts.
  - `PROVIDER_INCIDENT` — corroborated upstream incident (Cursor statuspage for Composer,
    Google Cloud statuspage for Gemini); no overlap → fault is NOT corroborated → LOSS stands.
- **Verdict-independent window reclassification.** If a fault window is corroborated, *all* in-window
  trials are reclassified INCOMPLETE regardless of WIN/LOSS — re-running wins too. Asymmetric re-run
  (keep in-window wins, re-run in-window losses) is loss-laundering and is forbidden.

## 5. Eligible denominator & pre-run defect audit

Before freeze, audit all 113 tasks for defects (un-pullable image, broken verifier, ambiguous
instruction relative to its own tests). Excluded tasks are listed with reasons in `defects.jsonl`.
Eligible = 113 − documented defects. Reported alongside the headline. The audit also **spot-checks
task originality** on a sampled subset (does the requested feature exist upstream in code/PRs/issues?)
to substantiate the §8 contamination-clean claim; the check and its results are published.

## 6. Reported metrics — HARNESS-vs-HARNESS, model held constant

- **Two harness numbers reported:** Arm A (compiler stage at GPT-5.5) and Arm B (codex CLI
  alone at GPT-5.5), each as Wilson 95% interval. We label both as `<harness>` numbers, never
  as `gpt-5-5` numbers, to avoid the model-vs-system collapse (see §0 deliverable #3).
- **Paired comparison (the harness-richness claim):** Arm A vs Arm B on the identical 109-task
  eligible set, paired per task, **McNemar's exact on the discordant pairs** + Wilson 95% on
  each marginal. (Amendment 2026-05-29: outcomes are paired binary, not independent 2×2.
  Fisher exact would discard the pairing. The discordant-pair count is McNemar's natural
  quantity.) **Single comparison → α=0.05 (no Bonferroni needed).** Effect-size headline:
  marginal pass-rate difference + 95% CI via paired-bootstrap on the discordant set. We
  report the delta and its uncertainty; we do **not** claim a winner the interval doesn't
  support.
- **External reference (cited, not paired):** DeepSWE's published `gpt-5-5 xhigh in
  mini-swe-agent, 4 trials, pass@1 = 0.7005` from their leaderboard. Both our arms are
  cited against this number qualitatively (within or outside their Wilson 95%); the
  comparison is NOT paired and NOT part of the primary statistic — different methodology,
  different N, different harness on their side.
- **Amendment timeline:**
  - 2026-05-29: Fisher → McNemar (paired binary)
  - 2026-05-30 first reframe: two-arms (scaffold + Composer-in-mini), Bonferroni 0.025
  - 2026-05-30 second reframe: Composer-in-mini impossible (Cursor API gating); single arm
    no comparison
  - 2026-05-30 third reframe (current): both arms GPT-5.5 via codex subscription; harness-
    vs-harness paired; the "harness, not model" framing is structural to deliverable #3
- **The scaffold is a permanent confound vs DeepSWE's single-agent leaderboard.** We never compare
  our scaffold number to their `claude-opus-4-7 / mini-swe-agent` number and call it a model result.
  Our claim is about *composition under a fixed verifier*, scoped to these 113 tasks.
- Model disclosure: Gemini 3.5 Flash generator + Composer 2.5 (standard tier) challenger. Never
  Opus, never the Composer Fast tier. Earlier prereg versions named Sonnet 4.5 + GPT-5.5; that pair
  was amended 2026-05-28 (§0.2) and no longer appears in the scored run.

## 7. Provenance (the whole point)

A run is not a headline until, for every trial, we publish: the Pier ATIF v1.7 trajectory
(`agent/`), the captured diff, the verifier output (`reward.txt`, `ctrf.json`, `test-stdout.txt`),
and the per-trial cost/token stats from `result.json`. Published as a release archive + linked from
the PR. This is the burden-of-proof direction DeepSWE inverted: publish the runs and invite
refutation, not publish the result and ask for trust.

**PR to Datacurve: out of scope (dropped 2026-05-27).** Their leaderboard is a closed marketing site
with no submission path; an audience analysis concluded the only stakeholder in the missing data
(Cursor) has its own eval team and wouldn't act on ours. So the PR is not a deliverable. Publication
is on our own terms (the program's site/grimoire); refutation is invited there, not routed to the
bench's authors.

## 8. Confounds & contamination (the part most likely to embarrass us)

- **Contamination — clean, and *verifiably* so.** The mechanism that matters is not the bench's
  launch date but whether a task's **solution** was in the training corpus. DeepSWE tasks are
  *original* features (not lifted from merged PRs): the verifier exercises behavior absent from the
  repo at `base_commit`, and the reference solution is held out. When that feature was never merged
  into the public repo before our models' Jan-2026 cutoff, the solution cannot have been memorized.
  This is **checkable per task** — verified on the smoke task `ts-pattern-match-each` (the requested
  `matchEach` matcher returns zero hits in `gvergnaud/ts-pattern` code, PRs, and issues; it does not
  exist upstream). We commit to spot-checking originality on a sampled subset at freeze (§5 audit) and
  publishing the check, rather than asserting clean for all 113 blindly. **This is the legibility the
  bench itself lacks: a contamination claim earned by inspection, not by assertion.**
- **Custom-runner confound:** our scaffold runs under our own driver, not `pier run`. We disclose
  this and publish the driver source, so the harness is inspectable. Grading is held identical to the
  baselines (the task verifier via Pier), so the runner is the only variable.
- **Cost asymmetry:** our composition costs more per task than a single agent. Reported, not buried;
  the ablation table carries cost-per-resolve alongside resolve rate.

## 9. Held-out discipline

DeepSWE `solution/` dirs are reference patches held out from the agent at grading time. We add our
own discipline: the scaffold never reads `solution/` during development either. The held-out
`test.patch` is applied only at grade time, same as every other entrant — the agent cannot tune to
the hidden tests.

**No-cheating invariants (the same grader as everyone, no exceptions):**
1. **Same tasks** — all 113, whole-set, no cherry-picked subset.
2. **Same grader** — each task's own verifier (`test.sh` + grade-time `test.patch`) in the task's
   docker image, executed **unmodified**. No bespoke grader, no regrade, no touching reward logic.
   Identical grading path to the leaderboard.
3. **Agent never sees** `solution/` or the grade-time `test.patch`.
4. **Source-only diff** — no edits to test files, no scaffolding leakage into the captured patch.
5. **Instance-blind** — one scaffold version, no per-task tuning, verifier reward never an iteration
   input.
6. **The only declared difference from a leaderboard entry is the agent *runner*** (our driver vs
   `pier run`), which is the variable under measurement; the grader is held constant across all arms.
   Disclosed, not hidden.

## 9a. Pinned versions (a reproduction must match these)

| component | pin | enforced by |
|---|---|---|
| deep-swe (task substrate) | `2f0f41255912c9199a1dafa405ca068cd903624b` | `harness/bootstrap.sh` SHA assert |
| datacurve-pier (grader) | `0.2.0` | `harness/bootstrap.sh` version check |
| `@google/gemini-cli` | `0.38.0` | `harness/bootstrap.sh` warn-on-mismatch |
| `cursor-agent` | `2026.05.28-a70ca7c` | `harness/bootstrap.sh` warn-on-mismatch |
| craft model | `composer-2.5` (standard tier; `-fast` forbidden) | `$DSR_CRAFT_MODEL` + `$DSR_FORBID_FAST_TIER=1` |
| adversary model | `gemini-3.5-flash` | `$DSR_ADVERSARY_MODEL` |
| docker engine + compose v2 + buildx | present (pier requires compose v2) | `harness/bootstrap.sh` assert |

CLI version drift is treated as a regression risk (releases can change flags/auth/model
resolution mid-run, per `swebench-pro/PROCEDURE.md` §80). Operator runs `harness/bootstrap.sh`
before every scored arm; the warn-on-mismatch lines surface in the run log.

## 9b. Partial-run scope (NEW, 2026-05-28)

Before any scored run, a **partial run on 6 tasks** measures whether the disciplines in the
hypothesis graph transfer to the new model pair. This is methodologically a *cost-ledger smoke*
+ a *transfer-risk attestation*, not a scored sample — its outputs feed skill patches and the
PREREGISTRATION freeze gate, not the headline. Frozen as annotated tag
**`deepswe-partial-v1`**; scored run remains `deepswe-sub-v1` per §10.

Substrates (selected for orthogonal axis coverage per HG transfer-risk table):

| # | task | F₁₂ class | hypotheses probed |
|---|---|---|---|
| 1 | `kysely-window-grouping-helpers` | 71% breadth | Hₐ₂, H₆ (first grade-green datum), H₃ |
| 2 | `bandit` | 42% comp (anchor) | H₁ᵦ, H₇, H₈ |
| 3 | `happy-dom` | 63% breadth (additive) | Hₐ₂ generality |
| 4 | `opa-template-string-reconstruction` | 50% path | Hₐ₁ (new frontier) |
| 5 | `httpx-streaming-json-iteration` | 33% comp | H₃, H₄, Hₐ₂″ |
| 6 | `oxvg-structural-selector-preservation` | 40% comp (invariant) | Hₐ₄ machinery |

Scaffold arm only; baselines deferred to scored run. Local docker (one task at a time).
Per-instance budget: 6 × ~$0.40 = ~$2.40 model + ~$5 EC2.

**Five measurements run inside the sample** (per HG §Transfer Risks):
1. H₉ blind-spot overlap (Flash vs Composer on the same proxy gate).
2. H₈ mutation-thinking ablation on Flash + Composer separately.
3. H₇ design-doc iteration ablation on bandit.
4. H₁ᵦ default classification accuracy by Flash without override.
5. F₁₂ class-distribution re-measure by Flash on tasks 1, 4, 6.

**Pre-commit three-outcome reading of the scored run** (decided *before* the partial finishes,
shape borrowed from `swebench-pro/PREREGISTRATION-cheap-ablation.md` §3):

| Flash+Composer scaffold-arm rate | Reading |
|---|---|
| Comparable to (or exceeding) the on-axis projection from the prior Claude/GPT-5.5 scaffold | **Loop is the lever; model selection is not.** Strongest possible read — Flash+Composer in the right harness match SOTA on this task class. The publishable claim. |
| Modestly lower | Loop is necessary but not sufficient; frontier capability matters on the hard-tail tasks (likely path/fixture-heavy where Hₐ₁ is unbuilt). |
| Collapses (< 50% of the projection) | Frontier capability does most of the work; the scaffold helps marginally. Cost-quality frontier reframed; no publishable model-stage-matching claim. |

Whichever outcome lands, receipts publish per §7. The point of preregistering the reading is to
prevent post-hoc interpretation drift.

**Pre-run gate checklist** (mirror of `swebench-pro/PREREGISTRATION-cheap-ablation §5`, all must
be green before partial-run dispatch):
- [ ] `harness/bootstrap.sh` returns `READY — env validated` (pins + both CLI smokes).
- [ ] `harness/.dsrenv` emitted, `$DSR_CRAFT_MODEL=composer-2.5`, `$DSR_FORBID_FAST_TIER=1`.
- [ ] `grep -rinE 'codex|claude|sonnet|gpt-5' skills/ | grep -v "skill.md.*Phase"` returns no
      code-path baked-in identity (only the typed-acceptance Phase-4 commentary remains).
- [ ] Capture-discipline pilot run on `ts-pattern-match-each`: `pier run --agent claude-code`
      with a known-good fix, confirm captured patch has no `node_modules`/build blobs/test
      edits leaked.
- [ ] HYPOTHESIS_GRAPH.md updated with the partial-run target list + frozen at this SHA.
- [ ] Cost ledger started; ≤ $3 budget tripwire for the 6-task partial.

## 10. Freeze mechanism

Pre-freeze gate (all committed before cutting the scored tag): §5 defect audit + `defects.jsonl`;
the scaffold driver + the Pier-verifier grading hook; the frozen run config; `run_order.txt`;
§9a pinned versions assertions green; §9b partial-run results folded into HG; this §10
self-update + worklog rotation. Cut annotated tag `deepswe-sub-v1`; every scored artifact cites
its SHA. **Partial-run tag `deepswe-partial-v1`** is cut *before* the partial dispatch and is a
prerequisite for `deepswe-sub-v1`.

## 11. Post-freeze amendments

Transparency-only changes (publishing more, never bending a verdict or the denominator) are logged
here without a restart. Anything touching the scaffold, the eligible set, or the grading is a §3
restart under a new tag.
