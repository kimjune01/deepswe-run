# 5-minute audit via codex (2026-05-29)

Demonstration that the artifact failures documented in the main analysis are
surfaced by a single short prompt against gpt-5.5 via the codex CLI. No
priming on specific issues; the prompt asks a careful generic question.

## What was run

```
codex exec -m gpt-5.5 --skip-git-repo-check "$(cat prompt.txt)" < /dev/null
```

Working directory: `/Users/junekim/Documents/deepswe/deepswe-run` (a git
repo; the `--skip-git-repo-check` flag still required because codex defaults
to refusing untrusted dirs).

## Files

- `prompt.txt` — the 5-line prompt (512 bytes)
- `codex-gpt-5.5-output.txt` — full codex transcript including its tool calls
  (curl against the public artifact endpoints) and final 10-issue summary
  (389 KB)

## What codex found in one shot

Codex's 10 numbered findings, paraphrased to one line each:

1. Public trials universe is larger than leaderboard universe (mixed scopes)
2. Models evaluated on different denominators (gpt-5-5 at 111, not 113)
3. Top model drops two complete tasks (goreleaser, opa-rego-rule-profiling)
4. Excluded-error policy can bias model comparisons (uneven exclusion counts)
5. Confidence intervals treat clustered trials as independent
6. Published `pass_rate` field is easy to misread vs `attempt_pass_rate`
7. Per-trial JSONs say artifacts are linked but do not include the links
8. tasks.json lacks the full prompt, verifier, hidden tests, env, scoring script
9. Some base_commit_hash values are short SHAs or malformed lengths
10. Model configurations are not normalized (different reasoning_effort levels)

Findings 2, 3, 7 reproduce the main analysis. Findings 1, 4, 5, 6, 8, 9, 10 are
additional methodological issues codex caught that the main analysis did not
surface.

Codex did NOT catch:
- The four-defectives disagreement (requires running the oracle audit
  independently against the pinned commit; codex did not do that)
- The author + dossier findings (no prior publication record; vendor-
  customer-investor alignment; cap-table participation by employees at the
  winning lab)

## How long it took

Total wall-clock time for codex to run from prompt-submit to final summary:
about 4 minutes, including its own curl probes against the public JSON
endpoints. Token usage: ~87k tokens. Cost on standard gpt-5.5 pricing: a
few dollars.
