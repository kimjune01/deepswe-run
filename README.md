# Legible skills + the harness-richness experiment — recon → craft → audit (Sonnet 4.5 + GPT-5.5)

Two goals, neither involving Datacurve as a recipient: **(1)** make the recon→craft→audit scaffold
**legible** — publish every task's trajectory, diff, verifier output, and cost, re-derivable from a
frozen tag; **(2)** **dispel "less prompting is better"** — test whether a richer scaffold resolves
more than minimal single-agent prompting, same models, same tasks, same grader, paired stats.

[DeepSWE](https://github.com/datacurve-ai/deep-swe)'s 113 tasks are used only as a contamination-free
2026 substrate, graded by the unmodified [Pier](https://github.com/datacurve-ai/pier) verifier. Their
leaderboard/recognition/PR are out of scope. See [`PREREGISTRATION.md`](./PREREGISTRATION.md).

## What's here

| path | what |
|---|---|
| `PREREGISTRATION.md` | frozen-on-run methodology, at parity with our SWE-bench Pro prereg |
| `WORKLOG.md` | dated development + run trail |
| `harness/` | the audit scripts: `provision_oracle_ec2.sh`, `box_audit.sh`, `audit_oracle.sh` |
| `results/` | per-task verdict ledgers (`oracle_audit_ec2.jsonl` + the sequential re-confirm) and run logs |
| `docs/` | notes (an early PR draft, now out of scope) |

## The gold-patch audit (complete)

Before any model arm, the most basic check: does each task's own reference solution pass its own
verifier? Run on all 113 tasks (oracle agent, $0 model, one spot box, under a dollar), `deep-swe`
pinned at `2f0f4125`. Result: **109 pass, 4 fail** — `langchain-request-coalescing`,
`narwhals-rolling-window-suite`, `prometheus-transactional-reload-status`, `skrub-duration-encoding`,
each confirmed failing in isolation, cause unresolved. Full per-task verdicts in
`results/oracle_audit_ec2.jsonl`.

```bash
git clone https://github.com/datacurve-ai/deep-swe && cd deep-swe && git checkout 2f0f4125
uv tool install datacurve-pier            # 0.2.0; needs docker + the docker compose v2 plugin
for t in tasks/*/; do pier run -p "$t" --agent oracle --env docker; done
# reward.txt == 1 means the gold passes its own verifier; != 1 flags a defect
```

## The harness-richness experiment (staged, not yet run)

The scaffold arms are not built yet. The plan: our recon→craft→audit driver vs single-agent
`claude-code` (Sonnet 4.5) vs single-agent `codex` (GPT-5.5), on the same 113 tasks, all graded by
each task's own verifier via Pier, paired Fisher exact + Wilson. The bench is the tasks plus their
verifiers, not any one runner; the runner is the variable under measurement. Not a model-superiority
claim, not a contamination-clean claim; the scaffold is disclosed as a confound and its source will
live in `harness/` when built.
