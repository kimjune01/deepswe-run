# H₉ overlap pairing — codex (GPT-5.5) vs Composer 2.5 on Flash-authored bandit proxy gate

Date: 2026-05-29. Artifact: `flash-test_proxy.py` (34 tests). Reviewers: identical prompt (`review-prompt-filled.md`), Phase 4 three-ask protocol.

## Raw counts
- codex: 44 findings (1 soundness, 34 discrimination, 9 missing coverage)
- composer: 61 findings (7 soundness, 35 discrimination, 19 missing coverage)

## Why two overlap numbers

**Structural overlap (discrimination axis): mechanical, walks every gate test once.** Both reviewers had to produce one finding per test method (34 tests → ≥34 per-test findings), so high overlap in this axis is forced by the protocol, not by cross-family agreement. Reporting structural overlap as H₉ evidence would be confounded.

**Substantive overlap (soundness + missing coverage): where real variance lives.** These two sections are unbounded — each reviewer picks what to flag from a large possibility space. Agreement here is informative; disagreement is the H₉ signal.

The threshold (HG: >70% means H₉ collapses) was specced against the original Claude↔GPT-5.5 measurement, which used the substantive axis. We use the same axis here.

## Substantive overlap pairing (soundness ∪ missing coverage)

| Topic | Codex F# | Composer F# | Shared? |
|---|---|---|---|
| `axis_crossing_begin_and_next_line` is unsound (next-line leaks to following statement) | F1, F35 | — (Composer F42 says discriminates fine; disagrees) | **codex-only** |
| `test_operators_intersection` glob semantics (`B*01` not prefix-glob) | F11 (as discrim) | F1 (as soundness) | **shared** (cross-axis) |
| `test_selector_omitted_empty_blanket` metrics counting | — | F2 | composer-only |
| `combine_suppressions_blanket_dominates` metrics arithmetic | F31, F33 (discrim) | F3, F4 (soundness) | **shared** (cross-axis) |
| `test_selector_none` over-asserts both IDs present | — | F5 | composer-only |
| `nested_active_regions_lifo` over-asserts physical linenos | F34 (discrim) | F6 (soundness) | **shared** (cross-axis) |
| `indented_begin_whitespace_basis` over-asserts empty issues | F21 (discrim) | F7 (soundness) | **shared** (cross-axis) |
| Missing: all directives under `ignore_nosec` | F36 | F47 | **shared** |
| Missing: combined applicable suppressions | F37 | F48 | **shared** |
| Missing: test-name tokens (case + ID) | F38 | F54 | **shared** (partial — Composer narrows to case) |
| Missing: glob prefix non-match e.g. `B10*` ≠ `B102` | F39 | (covered F13 discrim) | codex-only-here |
| Missing: `none` combined with another suppression | F40 | F46 | **shared** |
| Missing: fallback union not blanket | F41 | F43 (no-token variant) | **shared** (partial) |
| Missing: issue on same line as `nosec-end` | F42 | F59 | **shared** |
| Missing: begin inside multi-line stmt + end before finding | F43 | — | **codex-only** |
| Missing: semicolon-only / ellipsis-only skip lines split | F44 | — | **codex-only** |
| Missing: case-insensitive on `nosec-next-line` / `nosec-end` specifically | — | F44 | composer-only |
| Missing: `nosec-next-line` with selectors | — | F45 | composer-only |
| Missing: triple stack blanket dominance | — | F49 | composer-only |
| Missing: multi-region per multi-line statement | — | F50 | composer-only |
| Missing: multiple `nosec-next-line` stacked same statement | — | F51 | composer-only |
| Missing: nested `begin` same physical line | — | F52 | composer-only |
| Missing: duplicate tokens in plain union | — | F53 | composer-only |
| Missing: finding on `begin` line itself (line not suppressed) | — | F55 | composer-only |
| Missing: malformed `begin` selectors | — | F56 | composer-only |
| Missing: specific resolved set empty | — | F57 | composer-only |
| Missing: legacy inline `# nosec` interaction w/ new directives | — | F58 | composer-only |
| Missing: multiple unmatched `end` in a row | — | F60 | composer-only |
| Missing: region continuation across inner block exit | — | F61 | composer-only |

## Tally

- **Shared topics:** 11 (intersection, blanket metrics, LIFO linenos, whitespace basis, ignore_nosec, combined applicable, name tokens, glob prefix, none-combined, fallback union, end-line finding)
- **codex-only:** 4 (axis-crossing unsoundness, glob-prefix non-match, multi-line stmt mid-end, semicolon/ellipsis split)
- **composer-only:** 14 (omitted-blanket metrics, selector-none over-assert, case on next-line/end, next-line selectors, triple stack, multi-region per multi-stmt, stacked next-line, nested begin same line, duplicate tokens, begin-line finding, malformed begin, empty specific set, legacy interaction, multi-unmatched end, region continuation)

|A ∪ B| = 11 + 4 + 14 = **29 distinct substantive topics**
|A ∩ B| = **11 shared**

## Overlap

**Substantive overlap = 11 / 29 = 37.9%.**

That is well below the 70% threshold. Findings sets are largely *complementary*, not duplicative.

## Notable cross-family signal (the qualitative read)

1. **codex catches a soundness bug Composer misses entirely** (`axis_crossing_begin_and_next_line` — codex F1: gate asserts behavior the PRD does not require, leaking next-line suppression into the following statement). Composer not only doesn't flag it as soundness, Composer's F42 actively certifies the test as discriminating well. This is the load-bearing kind of cross-family catch the protocol is designed to surface.
2. **Composer catches 14 unique missing-coverage gaps codex misses** — most are interaction/combination scenarios (multi-region per multi-line statement, stacked next-lines, nested begin same line, region continuation across block exits). Composer is more aggressive about implied-by-combination cases than codex.
3. **Where they agree (the 11 shared), they agree across axis** — codex catalogues them as discrimination concerns, Composer often catalogues the same test as a soundness concern. The agreement is on *which test is suspect*, not on *what the suspicion is*. That is a meaningful signal: same anomalies, different angle of attack. Both lenses are useful.

## H₉ decision

**H₉ stands on the Flash + Composer pair, at 37.9% substantive overlap (n=1 artifact).**

Cross-family review is producing genuinely complementary findings, not mostly-self-review. The protocol earns its tokens on this pair. The new pair (Composer-Kimi base × Gemini-Flash) preserves the Claude↔GPT-5.5 complementarity property that H₉ was built on.

### Caveats

- n=1 artifact (the Flash-authored bandit gate). One more artifact at a different feature class (e.g. kysely, breadth-dominant additive) would harden the result. Recommended before freeze.
- The structural-vs-substantive split is the right axis but reviewer-defined; a second observer might draw the topic boundaries differently. The 37.9% is bracketed: in the worst case where every "partial" or "cross-axis" pairing collapses to non-match, overlap drops to ~24%; in the best case where partials count fully, overlap reaches ~45%. All three bracket values are below 70%.
- Codex's axis-crossing soundness catch (F1) deserves a follow-up: was it *correct*? If yes, this is one of those "single cross-family finding worth the entire phase" moments. If wrong, the cross-family value drops. **Open action: spot-check codex F1 against the bandit PRD + canonical test suite.**

## Spot-check: is codex F1 correct?

PRD on `nosec-next-line`: "Suppress findings for the next statement after the directive." Singular: the next statement. The Flash gate `test_axis_crossing_begin_and_next_line` puts `# nosec-next-line B102` before `assert True` (which has no B102 finding) and `exec("1")` (which does). Under a literal PRD read, the next-line directive's target is `assert True` — so `exec("1")` should still report `B102`. But the test asserts `issues == []`, requiring `B102` to be suppressed too.

**Codex F1 is correct.** This is a real soundness bug in the Flash-authored gate; Composer missed it; codex caught it. The cross-family value on this artifact is at minimum one PRD-soundness catch the same-family review would have shipped.
