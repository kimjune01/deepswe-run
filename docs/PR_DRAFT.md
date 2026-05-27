# PR draft — datacurve-ai/deep-swe

**Status: STAGED, not opened.** Open only once the scored run is complete and trajectories are
published (PREREGISTRATION §7). An empty PR is a claim with nothing behind it — exactly the inversion
this submission exists to refute. Fork ready at `kimjune01/deep-swe`.

---

**Title:** Add a fully-published external run: recon→craft→audit (Sonnet 4.5 + GPT-5.5), Pier-graded

**Body:**

DeepSWE ships the tasks and the harness but, as far as I can find across the org, no run data, no
procedures, and no repro steps behind the leaderboard or the harness-comparison claim. This is an
external submission that publishes all of it.

What this adds (under `submissions/recon-craft-audit/`):

- **The agent**: a recon→craft→audit composition over Sonnet 4.5 + GPT-5.5, as a Pier
  `--agent-import-path` adapter (source included, inspectable).
- **A scored pass over all 113 tasks**, graded by the unmodified Pier verifier. Headline resolve rate
  with a Wilson 95% interval; honest denominator (eligible = 113 − documented defects, listed).
- **Every trajectory** (ATIF v1.7), captured diff, verifier output, and per-trial cost — published as
  a release archive, re-derivable from a frozen tag (`deepswe-sub-v1`).
- **The harness ablation**: scaffold vs single-agent claude-code (Sonnet 4.5) vs single-agent codex
  (GPT-5.5) on the identical eligible set, paired, Fisher exact + Wilson. The "lighter harness wins"
  question, with data and intervals instead of n=2.

Scoped honestly: this is a claim about composition under a fixed verifier on these 113 tasks, not a
model-superiority or contamination-clean claim. The scaffold is disclosed as a confound; base commits
may predate the models' cutoffs (same caveat as every Verified-style entry).

Pre-registration, worklog, and the full methodology travel with the submission. Refutation welcome —
that's the point of publishing the runs.

---

**Reviewer-facing note (why a PR even if it's unlikely to merge):** the repo documents no submission
path. The PR is the channel of record regardless of outcome: it makes the run, the data, and the
ablation public against the canonical repo, where anyone evaluating DeepSWE's claims can see them.
