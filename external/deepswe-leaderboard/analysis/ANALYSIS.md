# Leaderboard analysis (2026-05-29, corrected)

> **Correction (post-publish):** an earlier draft of this analysis claimed 60
> trials were excluded with no documented reason. I had grepped for
> `error_class`/`error_message` (present in schema but unused) instead of
> `error_category`/`exception` (populated). All 60 excluded_error trials in
> trials.json have both fields populated; the exclusion policy is honored. That
> finding is retracted. The denominator finding (111 vs 113) stands but is
> consistent with their stated exclusion policy applied to two all-errored task
> cells â it is sloppy footer copy, not selective inflation. A new finding
> replaces the retracted one: the model patches each verdict was rendered on
> are not publicly retrievable. Detail in the blog post amendment.

Read-out from the mirrored `raw/` artifacts and the derived files. What the data tells us, where the methodology is solid, where it isn't, and what the comparison set looks like.

## Headline numbers (verified from heatmap)

| Model | config | pass@1 | pass@4 | Δ |
|---|---|---|---|---|
| gpt-5-5 | xhigh | **0.7005** | 0.8830 | +0.18 |
| gpt-5-4 | xhigh | 0.5555 | 0.7700 | +0.21 |
| claude-opus-4-7 | max | 0.5421 | 0.8584 | **+0.32** |
| claude-sonnet-4-6 | high | 0.3158 | 0.6195 | +0.30 |
| **gemini-3-5-flash** | medium | **0.2832** | **0.5664** | +0.28 |
| claude-opus-4-6 | max | 0.2712 | 0.5044 | +0.23 |
| gpt-5-4-mini | xhigh | 0.2426 | 0.4602 | +0.22 |
| kimi-k2-6 | default | 0.2389 | 0.4867 | +0.25 |
| mimo-v2-5-pro | default | 0.1955 | 0.4513 | +0.26 |
| glm-5-1 | default | 0.1748 | 0.3894 | +0.21 |
| gemini-3-1-pro-preview | default | 0.0988 | 0.2478 | +0.15 |
| deepseek-v4-pro | default | 0.0752 | 0.1858 | +0.11 |
| gemini-3-flash-preview | default | 0.0524 | 0.1504 | +0.10 |
| qwen3-6-plus | default | 0.0274 | 0.0973 | +0.07 |
| claude-haiku-4-5 | default | 0.0024 | 0.0088 | +0.01 |
| minimax-m2-7 | default | 0.0024 | 0.0088 | +0.01 |

The pass@4 column is the load-bearing one. Claude Opus 4.7 hits **86%** of tasks with at least one passing rollout out of 4 — meaning capability is there, consistency isn't. The 32-percentage-point gap from pass@1 to pass@4 is the variance signature.

## Methodology — what's actually disclosed

Pulled from `leaderboard.json` and `summary.json`:

- **Trials per (model, task) pair:** 4 (selection_source string says `4x`)
- **Total rollout attempts:** 7232
- **Total trials post-filtering:** 8852
- **pass@1:** macro-averaged over tasks from each task's scored rollout pass fraction
- **pass@4:** tasks with ≥1 passing rollout / tasks attempted
- **Failure scoring:** context-window failures + agent timeouts ARE scored failures
- **Excluded:** provider/verifier/network errors (these don't count as either pass or fail)
- **Generation date:** 2026-05-20T19:36 UTC
- **Single harness disclosed:** mini-swe-agent across all models, configs per model in `config` field

That's substantially more methodology than I assumed when I told you "I smell fraud." The benchmark is methodologically more rigorous than most ML benchmarks I've seen.

## Methodology — what isn't disclosed

### 1. Denominator handling on missing cells

**gpt-5-5 has no cell for 2 tasks: `goreleaser-retry-publish-auditing` and `opa-rego-rule-profiling`.** The leaderboard's headline pass@1 = 0.70045 is computed over the 111 tasks where gpt-5-5 has rollouts — not the full 113 (which the JSON's `n_tasks_in_set` field explicitly claims).

Verified by direct computation:
```
mean(pass-fraction over 111 cells)      = 0.70045  ← matches headline
mean over 113 (missing → 0)             = 0.68805
```

Counting the missing tasks as fails (the conservative reading) would drop gpt-5-5's headline from 70% to 68.8%. **The 1.2 percentage point gap is not disclosed.** Their footer claims `n_tasks_in_set: 113`; the actual pass@1 division is by 111.

This is the cleanest methodology criticism that survives every other check. Not fraud, but undisclosed denominator handling on missing-rollout tasks. A real benchmark would either rerun until all cells are filled, document the exclusion explicitly, or score missing cells as failures.

### 2. Confidence interval method

Their leaderboard shows ±4% bars on the gpt-5-5 row. We can verify:
- Naive Wilson on n=4×113=452 trials at p=0.70 gives ±~4.2% → matches
- But pass@1 isn't independent at the trial level (it's macro-averaged per task)
- The "correct" CI is some kind of clustered standard error or bootstrap

Not disclosed which they used. The number happens to land in the right neighborhood either way, so this is methodology hygiene rather than a problem.

### 3. The 4 "defectives" disagreement

Our own §6 audit ran `pier run --agent oracle` (apply gold, grade) on all 113 and found 4 failing: `langchain-request-coalescing`, `narwhals-rolling-window-suite`, `prometheus-transactional-reload-status`, `skrub-duration-encoding`.

But their leaderboard shows:

| task | gpt-5-5 | opus-4-7 | flash | total across all 16 models |
|---|---|---|---|---|
| langchain-request-coalescing | 3/4 | 0/4 | 0/4 | **10/64** |
| narwhals-rolling-window-suite | 4/4 | 3/4 | 0/4 | **34/64** |
| prometheus-transactional-reload-status | 0/4 | 0/4 | 0/4 | 2/64 |
| skrub-duration-encoding | 4/4 | 4/4 | 0/4 | **12/64** |

Three of these are passed cleanly by gpt-5-5 (the 4/4 ones) and one (langchain) is hit 10× across all models. **Their grader and our oracle audit disagree on 3 of 4.** Possible causes:

- Our oracle audit ran in a flaky environment (one-time spot instance, possibly mid-state)
- Their grader is slightly more lenient than pier's
- Different gold-patch evaluation paths (their mini-swe-agent submits a model-generated diff that happens to satisfy hidden tests differently than the official gold patch would)
- Our pier 0.2.0 has a version drift from theirs

**Action: re-run our §6 audit and compare task-by-task. If our 4-fail set was flaky, this is information about our setup, not theirs.** The single genuinely-hard one in the set is `prometheus-transactional-reload-status` (2 of 64 across all models = 3.1% pass rate).

## Difficulty distribution (113 tasks)

Buckets by frontier-mean pass-rate (mean across gpt-5-5, opus-4-7, gpt-5-4, sonnet-4-6):

| bucket | range | n | mean | rationale |
|---|---|---|---|---|
| trivial | ≥ 0.875 | 13 | 0.899 | sanity floor; if we miss these, the scaffold is broken |
| easy | ≥ 0.625 | 36 | 0.712 | within frontier's comfort zone; expected scaffold ≥ comparable |
| medium | ≥ 0.375 | 31 | 0.495 | the meat; pass@4 - pass@1 variance is largest here |
| hard | ≥ 0.125 | 27 | 0.251 | gp-5-5 barely passes; scaffold has the most room to add value |
| wall | < 0.125 | 6 | 0.041 | basically nobody passes; reach tasks for any scaffold |

**The 27-task hard slice is where any harness richness claim earns its keep.** Frontier models hit ~25% on this slice; if our scaffold hits ≥50%, that's a real headline.

## The stratified 30-task comparison set

`derived/stratified-30.json` — 30 tasks selected via reproducible RNG seed (20260529) across the buckets:

| bucket | n | purpose |
|---|---|---|
| trivial | 6 | floor check; expected near 100% |
| easy | 8 | competitive range; mid-band variance |
| medium | 8 | the meat — where harness disciplines fire |
| hard | 6 | where scaffold lift should be largest |
| wall | 2 | reach tasks; expected ~0%, but worth observing |

Already-fired (kysely, bandit, happy-dom) deliberately excluded to avoid inheriting tuning bias. The set is paired in the sense that we know per-task gpt-5-5 / opus-4-7 / flash numbers and can compute task-by-task lift.

Cost projection for our paired-30 measurement:
- Our scaffold (Flash + Composer): 30 tasks × 4 trials = 120 trials × ~$0.40 = **~$48**
- Our re-run of mini-swe-agent + Flash: 30 tasks × 4 trials = 120 trials × ~$0.15 = **~$18**
- Total **~$66 + EC2** for the paired publishable comparison

That gives us the harness-lift number on a substrate slice the leaderboard already published their numbers for. If our scaffold-arm pass@1 is 60% on the same 30 where Flash-mini is 28% and gpt-5-5 is 50% (just example numbers), the **harness lift over Flash-baseline is +32 percentage points**, and the **cost per resolved task is ~$1.30 vs gpt-5-5's ~$5+** at xhigh reasoning.

## How this changes the publishable claim shape

Before pulling this data, the publishable claim was:

> Flash+Composer in our scaffold matches SOTA on these task types.

That's vibes-shaped. Now we can write:

> On a stratified 30-task slice of DeepSWE-113, our scaffold with Flash recon + Composer 2.5 craft (mid-tier API models) achieves pass@1 = X% ± Y, compared to:
>   - leaderboard gpt-5-5 [xhigh] at A%
>   - leaderboard opus-4-7 [max] at B%
>   - leaderboard gemini-3-5-flash [medium] at C% — the same model as our recon arm, under a lighter harness
>   - our own re-run of mini-swe-agent + gemini-3-5-flash on the same 30, at D%
>
> The harness-lift (scaffold − Flash-baseline) on this slice is +Z percentage points. Per-task verdicts are published. Cost per resolved task: $V vs leaderboard gpt-5-5 estimated $W.

That's a comparable, falsifiable, methodology-rigorous claim. The leaderboard data we just pulled is what makes it so.

## What I'd flag in the writeup vs the leaderboard

If we go to publish, I'd disclose explicitly:

1. **The denominator finding.** Their pass@1 is over 111 not 113 for gpt-5-5. Document this; don't hide it.
2. **The defective-task disagreement.** Our oracle audit's 4 fails don't match their per-task pass rates. Document our re-check.
3. **The flash baseline as the meaningful comparator.** We use Flash as one half of our scaffold; the natural comparison is "Flash alone in mini-swe-agent" not "gpt-5-5 in mini-swe-agent."
4. **The pass@4 framing.** If our scaffold has lower variance per-task (because the scaffold is more deterministic than single-agent rollouts), our pass@1 might match their pass@4 — and pass@4 is the more comparable metric.

## Open questions for next session

- Whether the per-task pages have trajectories or captured diffs. Worth pulling `/artifacts/tasks/{id}.json` for 3-5 sampled tasks to see what receipts are actually behind the heatmap cells.
- Whether the `trials.json` 16MB file has per-trial outcomes that let us reconstruct rollouts. It looks like yes; we should index it and see what's there.
- The qualitative-analysis section of their blog might disclose more methodology. Worth a full read.

## Cost ledger for this analysis

- $0 model spend
- ~25 min reading + scripting
- 5 raw JSON artifacts mirrored
- 3 derived analysis files
- 1 methodology criticism that survives every other check (denominator handling)
- 1 falsified prior (the "no per-task receipts" worry)
- 1 actionable comparison set (stratified-30) ready to dispatch against
