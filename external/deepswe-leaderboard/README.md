# DeepSWE leaderboard data (mirrored 2026-05-29)

Mirror of the public artifacts behind <https://deepswe.datacurve.ai/>, pulled to make our analysis reproducible without depending on their CDN.

## What's here

```
raw/
  summary.json     188B    counts: 113 tasks, 91 repos, 7232 rollouts, 8852 trials
  leaderboard.json 13KB    pass@1 + pass@4 per model, with methodology disclosure
  heatmap.json     264KB   1806 (model × task) cells with n_passed / n_attempted
  tasks.json       57KB    113 task definitions (id, title, repo, language, base_commit)
  trials.json      16MB    8852 rollout records (reward, passed, outcome, included_in_score)
derived/
  stratified-30.json       30-task paired comparison set, stratified by gpt-5-5 difficulty
  flash-vs-frontier.csv    gemini-3-5-flash per-task pass-rate vs gpt-5-5, opus-4-7
  defectives.json          the 4 defective tasks (langchain/narwhals/prometheus/skrub) — handling
analysis/
  ANALYSIS.md              the read-out: what the data tells us, methodology notes, comparison set rationale
```

## How they're served

The site is a single-page React app at `https://deepswe.datacurve.ai/`. Data loads via:

- `/artifacts/{name}.json` — global artifacts (summary, leaderboard, heatmap, trials, tasks)
- `/artifacts/tasks/{taskId}.json` — per-task detail (not mirrored here yet)

Discovery: source-greppable via `curl https://deepswe.datacurve.ai/assets/index-*.js | grep "artifacts"`. The actual artifact names (`summary`, `heatmap`, etc.) were probed against a small candidate list; five returned 200.

## Methodology disclosures (extracted from `leaderboard.json` + `summary.json`)

- **n_tasks_in_set:** 113
- **Trials per (model, task) pair:** 4 (per `selection_source: "deep-swe-all-4x-cross-bench-minimal"`)
- **Total rollout_attempts:** 7232
- **Total trials (post fairness-filtering):** 8852
- **pass@1:** macro-averaged over tasks from each task's scored rollout pass fraction
- **pass@4:** tasks with at least one passing rollout, divided by tasks attempted
- **Failure scoring:** context-window failures + agent timeouts are scored failures
- **Excluded:** provider/verifier/network errors
- **Data generated:** 2026-05-20T19:36 UTC
- **Models tracked:** 16 (12 surfaced on the leaderboard by default)

## What this dataset enables for our work

1. **Per-task per-model pass rates** for stratifying a paired comparison set.
2. **Direct comparison** of our scaffold (Flash+Composer) against single-agent rows on the same task IDs we plan to fire.
3. **Independent verification target:** if we run mini-swe-agent + gemini-3-5-flash on a sampled subset and our numbers don't match theirs (~28% leaderboard), the methodology gap is locatable.
4. **Defect handling check:** the 4 tasks our own §6 audit found defective (langchain-request-coalescing, narwhals-rolling-window-suite, prometheus-transactional-reload-status, skrub-duration-encoding) — we can now see how their leaderboard treats them. If gpt-5-5 hits 0/4 on those tasks the denominator is the same as ours; if they're excluded silently, that's documented.

## Provenance

Pulled 2026-05-29 from `https://deepswe.datacurve.ai/artifacts/*.json`. Their `generated_at` was 2026-05-20T19:36 UTC, so this snapshot is 9 days post-generation. The mirror is read-only; if their numbers update, re-pull and diff.

## Caveats

- We don't have per-task trajectories or captured diffs. The trials.json gives us pass/fail + reward + outcome but not the rollout content. The per-task `/artifacts/tasks/{id}.json` URLs likely have more detail; not mirrored here yet.
- Their data freezes a specific run (May 13 DeepSWE Pier job per leaderboard.json). Newer model snapshots may not be reflected.
- The 16 models in heatmap.json include 4 not surfaced on the default leaderboard view; treat the hidden ones with caution (may be deprecated or in-flight).
