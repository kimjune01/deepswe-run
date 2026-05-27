# Pre-registration — DeepSWE submission

A living development document **until we commit to a scored run**, at which point it is frozen
(§10). This binds a *measurement* (a claimed number on DeepSWE's 113 tasks), not exploratory work.
Rigor is held at parity with the SWE-bench Pro pre-registration it is modeled on
(`../../swebench-pro/PREREGISTRATION.md`).

## 0. Goal & posture (what this submission is *for*)

DeepSWE ships tasks + harness (Pier) but **no run data, no procedures, no repro steps** across its
whole GitHub org (verified 2026-05-27: 6 repos; the only "trajectory" hits are viewer UI + Storybook
fixtures). Its leaderboard and its harness-neutrality claim ("lighter harness wins") rest on
**n=2, unpublished**. An engineer's report wearing science's clothes.

This submission is the **complement**: every task's trajectory, captured diff, verifier output, and
per-trial cost published, re-derivable from a frozen tag. The submission is itself the test — it
forces anyone who claims to care about rigor to either engage with full run data or reveal they
won't. We hold no commercial incentive; the artifact is given away.

- **Deliverable = a credible, reproducible, fully-published run** on DeepSWE's official 113 + a
  methodology claim, not a maximal %.
- **The methodology claim is the harness ablation DeepSWE skipped.** They concluded lighter harness >
  heavier harness on two data points and never published either. We run, on the *same* 113 tasks
  under the *same* Pier verifier: (a) our recon→craft→audit composition, (b) single-agent
  claude-code (Sonnet 4.5), (c) single-agent codex (GPT-5.5). The harness delta is **measured**, with
  Wilson intervals and a Fisher exact test, not asserted.

## 1. Predicate (a result is admissible iff all hold)

1. **General** — the scaffold is instance-blind; no per-task tuning, no reading DeepSWE `solution/`
   dirs (they are held out from the agent by us, not just by the harness).
2. **No leakage** — verifier reward is never an iteration input; one frozen scaffold version, one
   scored pass over all 113.
3. **Official-attested** — a win is the **Pier verifier's** reward on the captured diff, run under
   the unmodified task `tests/`. No bespoke grader. Pier is their harness; we use it as-is.
4. **Honest denominator** — exclusions are documented defects only (§4 audit), reported as a count
   with reasons; a defect is never our failure relabeled.
5. **Reproducible** — frozen tag, re-derivable from committed per-trial artifacts, runnable by a
   third party (`pier run -p deep-swe/tasks --agent-import-path <ours>`).

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
plumbing (smoke test); it does not scale to 113 × 3 passes (disk + serial wall-clock). Per-box: `uv
tool install datacurve-pier` + clone `deep-swe`, run `pier run -p tasks/<id> --env docker`, parse
`jobs/<id>/result.json` (reward 1.0 = WIN). EC2 is the only marginal dollar cost (~$0.20/box-hr,
arc ≈ $20–40); model runs $0 on subscription (or the paid key window). A periodic `docker image
prune` bounds per-box disk against image accumulation. Provenance (§7) is pulled off-box by the same
read-only daemon, capturing pier `jobs/` trial trees.

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
- **Harness ablation** (the DeepSWE gap): scaffold vs claude-code-Sonnet vs codex-GPT-5.5 on the
  identical eligible set, paired per task, Fisher exact + Wilson. We report the delta and its
  uncertainty; we do **not** claim a winner the interval doesn't support.
- **The scaffold is a permanent confound vs DeepSWE's single-agent leaderboard.** We never compare
  our scaffold number to their `claude-opus-4-7 / mini-swe-agent` number and call it a model result.
  Our claim is about *composition under a fixed verifier*, scoped to these 113 tasks.
- Model disclosure: Sonnet 4.5 generator + GPT-5.5 (codex) challenger. Never Opus.

## 7. Provenance (the whole point)

A run is not a headline until, for every trial, we publish: the Pier ATIF v1.7 trajectory
(`agent/`), the captured diff, the verifier output (`reward.txt`, `ctrf.json`, `test-stdout.txt`),
and the per-trial cost/token stats from `result.json`. Published as a release archive + linked from
the PR. This is the burden-of-proof direction DeepSWE inverted: publish the runs and invite
refutation, not publish the result and ask for trust.

**PR gate (hard precondition).** The PR to `datacurve-ai/deep-swe` is not opened until the scored run
is complete *and* the trajectory archive is published. A PR before that is a claim with nothing behind
it — the exact inversion this submission refutes — so it is forbidden, not merely discouraged.

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
- **Custom-agent confound:** our scaffold is not a DeepSWE-blessed agent. We disclose it as a
  `--agent-import-path` adapter and publish the adapter source, so the harness is inspectable.
- **Cost asymmetry:** our composition costs more per task than a single agent. Reported, not buried;
  the ablation table carries cost-per-resolve alongside resolve rate.

## 9. Held-out discipline

DeepSWE `solution/` dirs are reference patches held out from the agent at grading time by Pier. We
add our own discipline: the scaffold never reads `solution/` during development either. Verifier
`tests/` are visible to the agent at run time (Pier applies `test.patch` only at grade time), same
as every other entrant.

## 10. Freeze mechanism

Pre-freeze gate (all committed before cutting the tag): §5 defect audit + `defects.jsonl`; the
`--agent-import-path` adapter; the frozen Pier job config; `run_order.txt`; this §10 self-update +
worklog rotation. Cut annotated tag `deepswe-sub-v1`; every scored artifact cites its SHA.

## 11. Post-freeze amendments

Transparency-only changes (publishing more, never bending a verdict or the denominator) are logged
here without a restart. Anything touching the scaffold, the eligible set, or the grading is a §3
restart under a new tag.
