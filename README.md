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
| `WORKLOG.md` | dated development + scored-run trail |
| `agent/` | the recon→craft→audit scaffold driver + the Pier-verifier grading hook |
| `configs/` | frozen Pier job config(s) |
| `results/` | per-trial verdicts ledger + pointer to the published trajectory archive |
| `docs/` | the harness-ablation analysis (scaffold vs single-agent baselines) |

## Reproduce

The bench is the 113 Harbor tasks + each task's own verifier (`tests/`), not any one runner. Grading
is the task verifier, executed unmodified via Pier, identically across all arms.

```bash
git clone https://github.com/datacurve-ai/deep-swe
uv tool install datacurve-pier   # used as the unmodified verifier executor + baseline runner

# scaffold arm: our own driver runs recon->craft->audit in the task image, emits a source-only diff,
# then the task verifier grades it (not pier-driven as the agent):
python -m submission.driver run --tasks deep-swe/tasks

# single-agent baseline arms (the ablation DeepSWE skipped), pier as the faithful runner:
pier run -p deep-swe/tasks --agent claude-code --model claude-sonnet-4-5 --env docker
pier run -p deep-swe/tasks --agent codex --model openai/gpt-5.5 --env docker
```

## Claim, scoped

A claim about **composition under a fixed verifier**, on these 113 tasks: that a recon→craft→audit
loop over Sonnet 4.5 + GPT-5.5 resolves more than either model single-agent, measured with paired
Fisher exact + Wilson intervals. Not a model-superiority claim, not a contamination-clean claim. The
scaffold is disclosed as a confound; the adapter source is in `agent/`.
