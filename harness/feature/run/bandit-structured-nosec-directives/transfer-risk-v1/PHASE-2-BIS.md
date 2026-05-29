# Phase 2-bis catch-rate analysis (item #3 — proxy-author-time adversary)

Reusing the same artifact as transfer-risk-v1 (`flash-test_proxy.py`) and the two reviews already produced. The question: **on this substrate, how many of the eventual impl-bug-causing axis-crossings would adversary review of the proxy gate alone — before the impl exists — have caught?**

Why this question matters: HYPOTHESIS_GRAPH has an architectural reframe pending. Hₐ₈/Hₐ₉ argue the adversary fires too late at Phase 4 (post-impl). The bandit grade-red was traceable to proxy-author misses, not implementer misses — meaning if the adversary had reviewed the *gate* at author-time, those gaps could in principle have been closed before any impl tokens were spent.

## The three known impl-bug-causing axis-crossings on bandit

From `partial-v1/RESULT.md` and Hₐ₈ in HYPOTHESIS_GRAPH:

| bug | shape | axis crossing |
|---|---|---|
| **test_058** | region union across multi-line statement boundary | `nosec-begin` inside continuation; `end` before finding's reported line |
| **test_110** | selector `-` (difference) precision on non-trivial base set | minus operator + multi-token base set |
| **test_123** | `all & B602` mis-classified as `nosec` not `skipped_tests` | `all` *inside* an intersection expression (rule-applied-at-wrong-scope) |

These were caught only after Composer ran the impl and the hidden tests failed. Question: would either reviewer have surfaced an axis-crossing test at proxy-author time that would have forced the author to encode the missing semantics?

## Composer's 14 unique missing-coverage findings — bug map

| Composer F# | claim | catches test_058? | catches test_110? | catches test_123? |
|---|---|---|---|---|
| F44 | case-insensitive on next-line/end | no | no | no |
| F45 | next-line with selectors | no | no | no |
| F49 | triple stack blanket dominance | no | no | **partial** — if input is `all & B101 & B102`, would exercise classify-by-resolved-set |
| **F50** | **multi-region per multi-line statement** | **YES** | no | no |
| F51 | multiple next-line stacked | no | no | no |
| F52 | nested begin same line | no | no | no |
| F53 | duplicate tokens | no | no | no |
| F55 | finding on begin line itself | no | no | no |
| F56 | malformed begin selectors | no | no | no |
| **F57** | **specific resolved set empty** | no | no | **partial** — adjacent classify-by-resolved-set concern |
| F58 | legacy `# nosec` + new directives | no | no | no |
| F60 | multiple unmatched ends | no | no | no |
| **F61** | **region continuation across inner block exit** | **partial** | no | no |
| F48 (in shared list) | combined applicable suppressions | no | no | **partial** — if test asserts metrics on combined specific + blanket |

## Codex's 9 unique missing-coverage findings — bug map

| Codex F# | claim | catches test_058? | catches test_110? | catches test_123? |
|---|---|---|---|---|
| F36 | all directives under `ignore_nosec` | no | no | no |
| F37 | combined applicable suppressions | no | no | **partial** — same as Composer F48 |
| F38 | name tokens in operators | no | no | no |
| F39 | glob prefix non-match | no | no | no |
| F40 | none combined with another suppression | no | no | no |
| F41 | fallback union not blanket | no | no | no |
| F42 | issue on same line as nosec-end | no | no | no |
| **F43** | **begin inside multi-line stmt + end before finding** | **YES** | no | no |
| F44 | semicolon/ellipsis skip split | no | no | no |

## Score

- **test_058 (multi-line region union):** caught by **Composer F50** AND **codex F43** independently. *Both reviewers surface this at proxy-author time.* If applied, the proxy gate would include a test forcing the author to encode multi-line-statement region semantics — the same semantic Composer's impl got wrong.
- **test_110 (selector minus precision):** **not caught** by either reviewer. Both certify the existing `test_operators_difference` as discriminating. The actual impl bug — operator-precedence interaction with a multi-token base set — is not surfaced at proxy-author time.
- **test_123 (all-inside-expression):** **partials only.** Three findings (Composer F49, F57, codex F37) all gesture at classify-by-resolved-set, but none names the *specific axis crossing* (`all` operand inside `&` operator with a specific token) that the Composer impl got wrong. By the typed-acceptance protocol these are SPECULATION (PRD does not explicitly state behavior of `all` inside an expression) and would route to residue.

**Catch rate at proxy-author time: 1 of 3 clean, 2 of 3 with partial credit.**

## What this means architecturally

1. **Phase 2-bis is worth adding.** It catches a meaningful fraction (1/3 to 2/3) of impl-bug axis-crossings *before any impl tokens are spent*. The cost is one extra adversary dispatch per task (~$0.01 at Composer Standard rates, verified 2026-05-29 against `cursor.com/blog/composer-2-5`). Across 113 × 3 arms = **~$3 added budget**. On the catches it surfaces, it saves a full impl-cycle's worth of tokens (~$0.30 per task) and a re-impl round.
2. **Phase 2-bis does NOT replace Phase 4.** test_110 was not catchable from the gate alone — the axis-crossing is impl-specific (operator precedence inside a particular base-set composition). It needs the impl to exist before the adversary can flag the missing coverage. test_123 is partly catchable but routes to SPECULATION under the typed protocol — meaning it would only be caught at Phase 4 when the impl gives the speculation a concrete shape.
3. **The composition is the architecture.** Phase 2-bis (gate review) catches the multi-line and region-structure class. Phase 4 (impl review) catches the operator-precedence and rule-applied-at-wrong-scope class. Both fire; they catch different things.
4. **Hₐ₁₀'s "speculation has more layers than discipline" is operationally confirmed.** test_123 needed the impl to convert a SPECULATION-typed finding into an ENTAILMENT — the Phase 4 adversary doing exactly that conversion is the load-bearing step.

## Patch path for the build-tools skill

Add Phase 2-bis to `skills/build-tools/skill.md` between Phase 3 (dev probes) and Phase 4 (cross-family adversary review of the impl), or split Phase 4 into 4a (proxy-gate review at author-time, residue→design-doc) and 4b (impl review at impl-time, residue→build-tools re-entry).

Minimal change: add a **Phase 3.5 — adversary on the gate alone**, identical three-ask protocol, route ENTAILMENT/DISCRIMINATOR findings back to Phase 2 augmentation, route SPECULATION to a `RESIDUE.md` carried forward to Phase 4 for impl-time conversion. Phase 4 stays as it is (impl review).

The discipline of carrying SPECULATION forward across phases is what makes the architecture sound: a finding that's speculation at proxy-author time can become entailment at impl-review time when there's a concrete impl to inspect.

## Decision

**Approve Phase 2-bis addition before freeze.** Estimated added cost: **~$3** (at Composer Standard $0.50/M in, $2.50/M out). Estimated saved cost: ~$30 (1/3 catch rate × 113 tasks × $0.30 saved impl rerun). Net heavily favorable. Architectural soundness improves by separating gate-review speculation from impl-review entailment.

**Open follow-ups before freeze:**
1. Edit `skills/build-tools/skill.md` to encode Phase 3.5 as above (~30 min, $0).
2. Re-verify on kysely (breadth-dominant additive) — does Phase 2-bis surface useful catches on a non-compositional substrate, or is it bandit-class-specific? (~$0.05, 5 min wall).
3. Smoke once with the patched skill end-to-end on a fresh substrate, confirm no regression.
