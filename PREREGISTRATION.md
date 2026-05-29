# Pre-registration — legible skills + the harness-richness experiment

A living development document **until we commit to a scored run**, at which point it is frozen
(§10). This binds a *measurement*, not exploratory work. Rigor is held at parity with the SWE-bench
Pro pre-registration it is modeled on (`../../swebench-pro/PREREGISTRATION.md`).

## 0. Goal & posture (what this is *for*)

Two goals, **neither involving Datacurve as a recipient.** DeepSWE's 113 tasks are used only as a
convenient *contamination-free 2026 substrate* — their leaderboard, recognition, and any PR are not
load-bearing and are explicitly out of scope. The audience is this research program and the broader
claim, not the bench's authors.

1. **Make the skills legible.** Publish the recon→craft→audit scaffold and its full per-task run data
   (trajectories, diffs, verifier output, cost), re-derivable from a frozen tag, so anyone — human or
   agent — can see exactly what the scaffold does and that it works. The skills are the artifact;
   legibility is the deliverable.
2. **Dispel "less prompting is better."** DeepSWE's actual harness finding is modest: across 3 model
   families, `mini-swe-agent` "matches or beats" each native CLI on **a single 10-task slice, one run
   per cell, no intervals or tests**, read as "not disadvantaging any model family." The ecosystem
   inflated that into "lighter harness wins." We contest the inflation directly and at scale: on the
   same 113 tasks under the same
   per-task verifier, does a *richer* scaffold (recon→craft→audit, Gemini 3.5 Flash generator +
   Composer 2.5 challenger) resolve more than *minimal* single-agent prompting — (b) single-agent
   `gemini-cli` (gemini-3.5-flash), (c) single-agent `cursor-agent` (composer-2.5)? Paired per task,
   Fisher exact + Wilson. The harness delta is **measured**, not asserted.

   **Primary model pair amended 2026-05-28** from Sonnet 4.5 + GPT-5.5 to Gemini 3.5 Flash +
   Composer 2.5 — both ~10× cheaper at comparable coding capability, keeping the full-suite
   ablation budget under ~$200 all-in instead of the Max-subscription window the earlier pair
   required. Setup, smoke tests, and key hygiene in [`docs/PROCEDURES.md`](docs/PROCEDURES.md).

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
- **Scaffold arm** — our recon→craft→audit driver (Gemini 3.5 Flash generator + Composer 2.5
  challenger) runs in the task's docker image (pulled from public ECR), produces a source-only diff.
  Same driver as Pro; **not** Pier-driven. Invoked via `gemini -m gemini-3.5-flash` and
  `cursor-agent -p -f --model composer-2.5` (see `docs/PROCEDURES.md`).
- **Baseline arms** — single-agent `gemini-cli` (gemini-3.5-flash) and single-agent `cursor-agent`
  (composer-2.5), each driven minimally on the same task image. Same models as the scaffold; only
  the harness shape differs, so the ablation isolates harness richness from model choice.
- **Grader (all arms)** — the task's own verifier, executed unmodified via Pier (apply `test.patch`,
  run `test.sh`), reward read identically across arms so the only variable is the harness.

Model spend is now **metered per token**, not $0-on-subscription as the earlier prereg version
recorded. Budget at standard tiers: Composer 2.5 $0.50/M in · $2.50/M out; Gemini 3.5 Flash $0.50/M
in · $3.00/M out. Per-arm full-suite estimate: ~$78 (Composer baseline) + ~$82 (Flash baseline) +
~$100-160 (scaffold, both models, ~3× token volume) ≈ **~$260-320 model spend** for the full
ablation. EC2 ~$20-50 on top (~$0.20/box-hr, arc ≈ $20-40). A periodic `docker image prune` bounds
per-box disk against image accumulation. Provenance (§7) is pulled off-box by the same read-only
daemon.

**Composer Fast tier (`composer-2.5-fast` at $3/$15) is forbidden in the scored run** — 6× markup,
~$500/arm, no measured capability gain over standard for this task class. Any deviation requires a
worklog entry naming the failure class that motivated it (§3 restart rule).

**Box bootstrap requirements (learned from the oracle audit).** Pier brings up the sandbox +
egress-proxy via **`docker compose`**, which AL2023's `dnf install docker` does **not** include
(engine only; buildx present, Compose absent). The bootstrap must install the Compose v2 plugin into
`~/.docker/cli-plugins` and **assert** `docker compose version` + `docker buildx version` (loud fail,
not a silent per-task NA). This binds the baseline arms and any pier-graded scaffold-arm run.
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
  - `QUOTA_EXHAUSTED` — Max-subscription token wall → **PAUSE**, resume when budget refreshes.
  - `PROVIDER_INCIDENT` — corroborated upstream model/API incident.
- **Verdict-independent window reclassification.** If a fault window is corroborated, *all* in-window
  trials are reclassified INCOMPLETE regardless of WIN/LOSS — re-running wins too. Asymmetric re-run
  (keep in-window wins, re-run in-window losses) is loss-laundering and is forbidden.

## 5. Eligible denominator & pre-run defect audit

Before freeze, audit all 113 tasks for defects (un-pullable image, broken verifier, ambiguous
instruction relative to its own tests). Excluded tasks are listed with reasons in `defects.jsonl`.
Eligible = 113 − documented defects. Reported alongside the headline. The audit also **spot-checks
task originality** on a sampled subset (does the requested feature exist upstream in code/PRs/issues?)
to substantiate the §8 contamination-clean claim; the check and its results are published.

## 6. Reported metrics — SYSTEM-vs-SYSTEM, harness disclosed

- Headline = our scaffold's resolve rate on the eligible set, with a Wilson 95% interval.
- **Harness ablation** (the DeepSWE gap): scaffold vs single-agent `gemini-cli` (gemini-3.5-flash)
  vs single-agent `cursor-agent` (composer-2.5) on the identical eligible set, paired per task,
  Fisher exact + Wilson. We report the delta and its uncertainty; we do **not** claim a winner the
  interval doesn't support.
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

## 10. Freeze mechanism

Pre-freeze gate (all committed before cutting the tag): §5 defect audit + `defects.jsonl`; the
scaffold driver + the Pier-verifier grading hook; the frozen run config; `run_order.txt`; this §10
self-update +
worklog rotation. Cut annotated tag `deepswe-sub-v1`; every scored artifact cites its SHA.

## 11. Post-freeze amendments

Transparency-only changes (publishing more, never bending a verdict or the denominator) are logged
here without a restart. Anything touching the scaffold, the eligible set, or the grading is a §3
restart under a new tag.
