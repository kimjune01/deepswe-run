# 5-minute audit of DeepSWE v1.1 via codex (2026-07-07)

Same procedure as the [v1 codex audit](../codex-audit/): one short, un-priming
prompt to `gpt-5.5` via the codex CLI, pointed this time at the **v1.1**
artifacts. Purpose is to check whether the v1.1 revision, which fixes the
grading defects the main audit found, still surfaces methodological problems to
a careful reader running one prompt.

## What was run

```
codex exec "$(cat prompt.txt)"
```

- `prompt.txt` — the prompt, re-pointed at the v1.1 artifact paths
- `codex-gpt-5.5-output.txt` — full transcript including codex's own curl probes
  and final summary

## Findings that carry into the blog post

These are the flags I independently re-derived from the artifact snapshots in
[`../../results/v1.1/`](../../results/v1.1/). See
[`DERIVATION.md`](../../results/v1.1/DERIVATION.md) for the exact re-run of each.
Every one is a disclosure or consistency gap the grading fix left untouched.

| # | flag | verified against snapshot |
|---|------|---------------------------|
| A | `heatmap.json` charts 8 models where the leaderboard ranks 10 (`claude-sonnet-5`, `glm-5-2` dropped from the grid) | yes |
| B | Stated rule "agent timeouts are scored failures" contradicted by trial rows with `error_category: "agent_timeout"`, `passed: true`, reward 1 | yes (4 rows) |
| C | Blog discloses 73 excluded Fable rollouts; `trials.json` has 122 exclusions, so 49 more go unmentioned | yes |
| D | Node-id scoring is not checkable from what ships: trials name `ctrf.json` / `reward.json` without their contents; `has_model_patch` is a boolean, not a link | yes |
| E | `v1-delta.json` labels the comparison "same rollouts, re-graded," but per-config attempt counts differ (`n_v1` != `n_current`) | yes |

Finding E is why the blog reports the four flagged tasks with an explicit
`attempts (v1->v1.1)` column: only `narwhals` and `prometheus` (40 in both
versions) are clean same-rollout re-grades; `langchain` and `skrub` shed
attempts (49 to 40), so those two are read as directional.

## Other flags codex raised (not load-bearing for the post)

Recorded for completeness; not independently re-derived here:

- Public trial universe is larger than the leaderboard universe (mixed
  `eval_scope` / `source` rows).
- Some configs cover fewer than 113 tasks but are ranked directly (e.g.
  `mini_swe_agent_claude_opus_4_8_max` over 111 tasks); `n_runs: 4` is
  misleading for those, and run IDs are not exposed to audit the run-to-run CI.
- Large per-task v1-to-v1.1 swings are shown, but the artifacts do not identify
  which tests changed per task.
- Public, reused tasks carry the usual forward contamination risk.

## Note on counting

The count of flags is not itself a finding and is deliberately not reported as
one; what matters is which specific claims survive an independent re-derivation,
listed above.
