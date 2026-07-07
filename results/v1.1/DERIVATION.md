# DeepSWE v1.1 — receipts and derivation (2026-07-07)

Snapshots of the public v1.1 artifacts, fetched 2026-07-07 from
`https://deepswe.datacurve.ai/artifacts/v1.1/`, with the exact re-run behind
every quantitative claim in [Auditing DeepSWE v1.1](https://june.kim/auditing-deepswe-v1-1).

The live URLs resolved at fetch time but are versioned and may move (the v1
`/artifacts/*.json` paths already 404). These snapshots are the durable copy.

## Files

- `v1-delta.json` — per-config and per-task v1 vs v1.1 comparison (same rollouts, re-graded)
- `leaderboard-live.json` — v1.1 leaderboard rows, CI method, denominators
- `heatmap.json` — per-task/per-model grid
- `trials.json.gz` — all 11,752 v1.1 trial records (gunzip before use)

```bash
gunzip -k trials.json.gz   # -> trials.json (~20 MB)
```

## Claim 1 — the four flagged golds climb; the aggregate barely moves

```bash
node -e '
const d=require("./v1-delta.json");
console.log("pooled:", d.pooled);   // {v1:0.5094, current:0.5179}
for (const n of ["narwhals-rolling-window-suite","skrub-duration-encoding",
                 "langchain-request-coalescing","prometheus-transactional-reload-status"]) {
  const t=d.tasks.find(x=>x.task===n);
  console.log(n, (t.v1*100).toFixed(1)+"%", (t.current*100).toFixed(1)+"%",
              "delta "+(t.delta*100).toFixed(1), "attempts "+t.n_v1+"->"+t.n_current);
}'
```

Expected:

```
pooled: { v1: 0.5094, current: 0.5179 }
narwhals-rolling-window-suite          30.0% 95.0% delta 65.0 attempts 40->40
skrub-duration-encoding                22.5% 60.0% delta 37.6 attempts 49->40
langchain-request-coalescing           14.3% 27.5% delta 13.2 attempts 49->40
prometheus-transactional-reload-status  2.5% 12.5% delta 10.0 attempts 40->40
```

Only `narwhals` and `prometheus` have an unchanged attempt count, so for those
two the grader is the only moving part. `langchain` and `skrub` also shed
attempts (49 -> 40); their deltas are directional.

## Claim 2 — CI method is now run-to-run; one config is scored over 111 tasks, not 113

```bash
node -e '
const d=require("./leaderboard-live.json");
console.log("n_tasks_in_set:", d.n_tasks_in_set);
console.log("ci_method:", d.rows[0].ci_method);
const off = d.rows.filter(r=>r.n_tasks_attempted!==113)
                  .map(r=>r.config+": "+r.n_tasks_attempted+" tasks, "+r.n_attempted+" attempts");
console.log("configs not over 113 tasks:\n  "+off.join("\n  "));'
```

`ci_method` is `"95% run-to-run: SE across repeated whole-benchmark passes
(1.96 * std(runs)/sqrt(R))"`. The footer says 113, but at least one config
(`mini_swe_agent_claude_opus_4_8_max`) is scored over 111 tasks / 429 attempts.

## Claim 3 — heatmap lists 8 models where the leaderboard ranks 10

```bash
node -e '
const h=require("./heatmap.json"), l=require("./leaderboard-live.json");
const lm=[...new Set(l.rows.map(r=>r.model))].sort();
const hm=[...h.models].sort();
console.log("leaderboard models ("+lm.length+"):", lm.join(", "));
console.log("heatmap models ("+hm.length+"):", hm.join(", "));
console.log("in leaderboard, not heatmap:", lm.filter(m=>!hm.includes(m)).join(", "));'
```

Expected: leaderboard 10, heatmap 8; `claude-sonnet-5` and `glm-5-2` absent from
the grid.

## Claim 4 — exclusion disclosure gap: 122 excluded, 73 disclosed, 49 unmentioned

```bash
gunzip -k trials.json.gz
node -e '
const d=require("./trials.json"); const a=Array.isArray(d)?d:(d.trials||d.rows||[]);
const ex=a.filter(t=>t.included_in_score===false);
const by={}; ex.forEach(t=>by[t.error_category]=(by[t.error_category]||0)+1);
console.log("total excluded:", ex.length, by);
const disclosed=by.model_routing_404||0;
console.log("disclosed (Fable model_routing_404):", disclosed, "| unmentioned:", ex.length-disclosed);'
```

Expected: 122 excluded — `model_routing_404` 73 (the disclosed Fable
suspension), plus `provider_timeout` 36, `verifier_timeout` 7,
`upstream_provider_error` 3, `unclassified_exception` 2, `rate_limit` 1 = 49
unmentioned.

## Claim 5 — stated timeout rule contradicted by trial rows

```bash
node -e '
const d=require("./trials.json"); const a=Array.isArray(d)?d:(d.trials||d.rows||[]);
const hits=a.filter(t=>t.error_category==="agent_timeout" && t.passed===true);
console.log("agent_timeout AND passed:true:", hits.length);
hits.forEach(t=>console.log(" ", t.trial_name, "outcome="+t.outcome, "score="+t.score_value));'
```

`leaderboard-live.json`'s `unit` says agent timeouts are scored failures; four
trial rows carry `error_category: "agent_timeout"` with `passed: true`,
`outcome: "pass"`, `score_value: 1`.

## Claim 6 — node-id scoring is not checkable from what ships

`trials.json` lists each trial's `verifier_files` (`ctrf.json`, `reward.json`)
by name but not their contents; `has_model_patch` is a boolean, never a URL.
`tasks.json` (not snapshotted here; fetch from the live path) exposes
`base_commit_hash` and `display_description` but not the full prompt, hidden
tests, node IDs, or scoring script. A reader cannot re-derive a single verdict
from the published artifacts.
