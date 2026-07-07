# DeepSWE v1.1 determinacy audit — findings (2026-07-07)

**Headline: DeepSWE's specs are tight.** An adversarial determinacy audit of all 113 v1.1
tasks — the same instrument that put a proven ~15% underdetermination floor on SWE-bench Pro —
finds an adjudicated floor of **3/111 ≈ 2.7%**: one airtight case and two codebase-plural
cases, each pointer-checkable. This is credit to the task authoring. It is the honest
counterweight to the measurement-vs-marketing critique of the leaderboard: the spec quality is
genuinely good.

See [`PREREGISTRATION.md`](PREREGISTRATION.md) for the protocol fixed before the run.

## What determinacy asks

Per task: does the spec the solver receives determine the behavior the hidden test grades?
Where it does not, the test pins one of several faithful readings, and a correct-but-different
fix scores zero — the score conflates capability shortfall with spec shortfall. The claimable
spine is grep-certified: the agent (codex, gpt-5.5) only proposes; every verdict is settled by
a clone-and-grep a skeptic re-runs. No benchmark execution.

## This is a census, so no confidence intervals

We audited all 113 tasks, not a sample, so there is no sampling process to put a binomial
(Wilson) interval around — the count is exact. The tool prints a Wilson CI by default; it does
not apply here and is not carried. The only real uncertainty is one-sided: a single agent pass
under-counts the spine (it proposes one witness per case), while the grep never certifies a
false one. So the rate is a **lower bound that only grows** as passes union, reported as
"≥ N, each independently verifiable," not "N ± ε." (Slapping a Wilson interval on a census
would be the same misuse we flagged in the leaderboard's own clustered-trial CIs.)

## The raw runs, and why they disagree

| pass | screen (case-level, upper bound) | raw spine (tool output) |
|---|---|---|
| 1 | 38/111 = 34% | 5/111 |
| 2 | 29/111 = 26% | 0/111 |

A single pass is unstable because the agent-driven coverage screen is a noisy funnel: a case
it marks ENTAILED never reaches the grep. The screen's ~30% is a disclosed upper bound (it
over-flags parametrized behaviors and convention-resolved silence). For a set this small the
right method is not more noisy passes but **hand-adjudicating the union of candidates against
prose, codebase, and external convention** — which is what moved the answer from 5 to 3.

## Adjudication of the union (5 raw candidates → 3 certified)

Each certified case was re-verified by an independent clone-and-grep, not the tool's word.

### Certified (the spine)

- **`csstree-shorthand-expansion-compression` — airtight.** The test pins the exact lowercase
  string `currentcolor` for an omitted `border-top-color`. The CSS-canonical spelling is
  `currentColor`, and the codebase uses that camelCase form (`data/patch.json`). A repo-faithful
  serializer emits `currentColor` and fails. Verify:
  ```bash
  git clone https://github.com/csstree/csstree && cd csstree && git checkout 88e3d965
  rg -F -g '!*test*' currentcolor   # absent
  rg -F -g '!*test*' currentColor   # present (data/patch.json) -> the faithful alternative
  ```
- **`anko-default-function-arguments` — codebase-plural.** The codebase parses Anko source two
  live, conflicting ways: `core/core.go:82` (`Scanner.Init` + `parser.Parse`, bypassing
  preprocessing) vs `vm/vmStmt.go:15` (`parser.ParseSrc`, which does the default-argument
  rewrite the task needs). Prose silent on which. A solver following the `core.go` precedent
  fails. Both precedents grep-verified live at `9d2d84bb`.
- **`ipython-session-bundle-replay` — codebase-plural.** Whether a failed cell halts replay is
  made both ways live: `IPython/core/interactiveshell.py:3049` (`not result.success: break`,
  stops) vs `IPython/core/shellapp.py:372` (the `exec_lines` loop continues past failures).
  Prose silent. Both grep-verified live at `0bb317d1`.

### Adjudicated out

- **`httpx-deterministic-cookie-store` — false positive (tool over-certified).** The "constant"
  `"a=1; secure; httponly"` is a test *input* fixture, trivially absent from source. The real
  behavior — case-insensitive cookie-attribute parsing — is fixed by **RFC 6265** (attribute
  names match case-insensitively), an external standard the grep cannot see. Not a free choice.
- **`task-task-graph-export` — mis-tiered to hypothesis.** The "constant" `"root" -> "mid"`
  splices fixture node-names. The genuine question — quote DOT identifiers or not — *is*
  underdetermined (both valid DOT, no codebase precedent), so this stays a disciplined
  hypothesis, not a proven airtight constant.

## Tool bug found and fixed

Both false/mis-tiered cases exposed a real defect in the determinacy tool
([`kimjune01/determinacy`](https://github.com/kimjune01/determinacy)): the airtight gate
certified any agent-proposed constant absent from prose and codebase, but never checked the
constant was a single free *token*. A whole fixture I/O line is trivially absent from non-test
source regardless of determinacy, so certifying on it echoes the fixture.

Fixed in determinacy `05d4d54`: `is_fixture_literal()` downgrades constants that splice
sub-values with structural separators (`;`, `->`, `=>`, `=`) to hypothesis; atomic values
(`currentcolor`, `AIEmbed`, `-1`, a multi-word error message) are kept. Replaying pass-1's own
proposals through the patched gate: httpx and task-graph downgrade, csstree holds. Regression
test added. The docstring also records the complementary blind spot grep cannot close: a
constant fixed by an external standard looks absent but is not free, so airtight stays a floor.

## Bottom line

- **Determinacy floor: ≥ 3/111 ≈ 2.7%** (1 airtight + 2 codebase-plural), each pointer-checkable
  in `cases/`. A lower bound; more passes could union a few more.
- **Coverage screen: ~30%** — a disclosed upper bound, not a claim.
- Contrast SWE-bench Pro's proven ~15% spine on 728 mined-PR tasks. DeepSWE's authored-from-
  scratch specs run several times tighter. That is a real strength of the benchmark, and it is
  the finding.
