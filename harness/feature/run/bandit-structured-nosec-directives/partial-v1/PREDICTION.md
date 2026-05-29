# Pre-flight prediction for bandit fire #1 (2026-05-28 20:23)

Composer is mid-run on bandit-structured-nosec-directives (PID 84032). Recording these predictions
BEFORE the result lands so we can't post-hoc them.

## Predictions (rank-ordered by my confidence)

1. **Composer will proxy-green on first pass (60% confidence).** The 30-test proxy gate is dense
   but each test isolates one rule. Bandit is the densest PRD in the partial-run suite (12+ rules)
   but Composer's track record on kysely (57/57 first pass) suggests instruction-following carries it.

2. **If proxy-green, Composer may NOT grade-green (50% confidence).** The proxy gate lacks
   M1 (blanket-dominance-under-nesting) and M3 (LIFO-end-pop-with-different-selectors) coverage —
   these were dropped at proxy-author time (Claude's F₁′ targeted them via mutants). The hidden
   test.patch likely includes equivalents of the canonical test_017/test_018. If Composer writes
   a "name-shaped" LIFO implementation that uses identical-blanket logic, it passes the proxy
   but fails the oracle.

3. **If Composer fails (40% confidence at any phase):**
   - Most likely failure: **selector grammar `&` (intersection) or `!` (negation) on a non-trivial
     test set.** Selector parsing has a fallback rule ("if expression cannot be parsed, treat as
     plain union") that Composer might over-apply, silently turning ill-formed operator expressions
     into unions and passing tests it shouldn't.
   - Second-most-likely: **the `nosec-next-line` skip rule for grouping-only / semicolon-only lines.**
     PRD: "skip blank lines, comment-only lines, and lines containing only grouping tokens ((, ),
     [, ], {, }), semicolons, or ellipsis literals (...)." This is path/fixture-shaped (Hₐ₁).
     Composer may handle blank+comment but miss semicolons or ellipsis without explicit grepping.
   - Third: **metrics classification by RESOLVED set.** PRD: "Classification is based on the
     resolved set: if the result is a blanket suppression, it counts as nosec; if it resolves
     to a non-empty specific set, it counts as skipped_tests." Composer may classify by the
     directive's *syntactic shape* (the selector text) rather than the *resolved set after
     intersection/negation/glob expansion*. This is the M1 shape and is what Claude missed.

## What outcomes teach us

| Outcome | Lesson |
|---|---|
| Proxy-green + grade-green (REWARD 1) | Hₐ₆ strengthens (Composer first-passes compositional too); harness-richness story shrinks. Loop is the cost-quality lever; the harness's old disciplines are Claude-specific. |
| Proxy-green + grade-red | **The smoking gun.** Concrete H₈-on-Composer measurement; the proxy-vs-grade gap is REAL on this pair. Patch path: enforce mutation-thinking at proxy-author time on compositional features (build-tools Phase 2-bis). |
| Proxy-red on first pass | Adversary loop fires; Flash's blind-spot vs Composer becomes measurable. H₉ overlap can be computed. |
| Composer aborts / structural error | Operational gap (env, prompt size, tooling). Re-fire with diagnostics. |

Recording at 2026-05-28 20:23. Result lands when PID 84032 exits.
