# DeepSWE v1.1 determinacy audit — preregistration (2026-07-07)

Fixed before the scored run. A determinacy audit asks, per task: does the spec the
solver receives determine the behavior the hidden test grades? Where it does not, the
score conflates capability shortfall (couldn't solve a determinate task) with spec
shortfall (the task didn't determine its answer). This audit measures that, with
grep-certified receipts a skeptic re-runs.

## Subject (pinned)

- Task set: `datacurve-ai/deep-swe` at commit **`3cda4081`** — the v1.1 (node-id) task
  set (task docker tags are `...-v1.1`), 113 tasks.
- Each task ships `instruction.md` (the solver's spec), `solution/solution.patch` (gold),
  `tests/test.patch` (hidden test), and `tests/config.json` `f2p_node_ids` (the graded
  node IDs). Extracted to `tasks.jsonl` by `build_tasks.py` with the field map:
  `problem_statement`=instruction, `gold_patch`=solution.patch, `test_patch`=test.patch,
  `fail_to_pass`=f2p_node_ids, `repo`=repository_url, `base_commit`=base_commit.

## Instrument (pinned)

- Tool: [`kimjune01/determinacy`](https://github.com/kimjune01/determinacy) at commit
  **`28675558`**, tiers 1–2 (`uv run determinacy run deepswe-v1.1.toml --tier 2`).
- Agent: `codex exec … -c model=gpt-5.5` — consulted only to **propose** witnesses.
  Every verdict is settled by a grep against the repo cloned at `base_commit`, never by
  the model's opinion. No benchmark execution: determinacy is grep-certified, so no
  docker, tests, or rollouts are run.

## Protocol

1. Run tier 2 across all 113 tasks.
2. Report two rates, kept separate:
   - **Coverage screen** (behavior-level, agent-proposed, grep-verified GAPs): an
     **upper bound**. It over-flags (parametrized behaviors, convention-resolved
     silence), disclosed as such.
   - **Claimable spine** = `AIRTIGHT` (a graded constant absent from prose and codebase,
     shown by clone+grep) + `CODEBASE-PLURAL` (≥2 conflicting live precedents,
     comparability-refutation-survived): a **lower bound**, each case pointer-checkable.
3. A single pass under-counts the spine (the agent proposes one witness per case); grep
   never admits a false positive. So run **≥2 independent passes and union** the spine,
   reporting the rate as "≥ N, each independently verifiable." Stop when a pass adds
   nothing new.
4. `PROSE-AFFIRMATIVE` / `BORDERLINE` cases (e.g. `adaptix-name-mapping-aliases`, the
   worked example in the blog) are **hypotheses**: labeled, receipted, counted in **no**
   claimable rate. The tool's validation run reproduced adaptix as exactly this — 3 GAP
   behaviors, filed `NOT CLAIMED`.
5. The answer-key tier (gold-passes-own-verifier) is already done in the v1 oracle audit
   (4/113 defectives); not re-run here.

## Reporting

Per-case receipts (`cases/<id>/RECEIPT.md`), `CLAIMS.md` (the spine, one row per
certified witness), `REPORT.md` (tiered rates with Wilson 95% CIs). The determinacy-aware
denominator follows: a raw DeepSWE pass rate should be read against the claimable-spine
floor of underdetermined tasks.

## Prediction (recorded, does not gate the result)

DeepSWE tasks are authored from scratch with detailed instructions, unlike mined GitHub
issues. The first-five validation showed tight specs (one task mapped 63/63 behaviors to
verbatim clauses). So the spine may come in **below** the SWE-rebench floor (~14%). The
audit measures whether that holds across the set; the number is whatever the grep says.
