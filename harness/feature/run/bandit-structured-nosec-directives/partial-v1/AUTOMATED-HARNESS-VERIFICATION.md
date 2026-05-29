# Automated harness verification: Composer-as-build-tools with patched skill

**2026-05-28 ~21:00.** Option (a-prime): dispatched Composer (cursor-agent --model composer-2.5)
as the build-tools skill, with the patched skill file (including Hₐ₈ axis-crossing discipline)
as input. The agent had only PRD + skill file — no prior proxy gate, no hidden tests, no
solutions. Cost: ~$0.50, ~10 min wall.

## What Composer-as-build-tools produced

- 740-line `test_proxy.py` with 51 tests in 11 classes
- A dedicated `TestAxisCrossing` class with 6 cross-axis tests
- Every axis-crossing test PRD-quoted with `# crosses PRD: <clause A> × <clause B>`
- Every test has `# discriminates: <plausible-wrong impl>` per discipline
- Self-reported coverage list matches the discipline taxonomy (interface enumeration + discriminating + axis-crossing)

## Verification matrix: 4 corners

| | Composer-original impl | Composer-patched (13-line) impl |
|---|---|---|
| Generated 51-test gate | **9 FAIL** | **7 FAIL** |
| Original 30-test gate | 30 pass | 30 pass |
| Generated 51 ∩ original 30 (subset shared semantics) | 30 pass | 30 pass |
| Oracle (78 hidden tests) | 75/78 (REWARD 0) | 78/78 (REWARD 1) |

**Key signal:** the *patched* impl passes the oracle but FAILS 7 of the generated 51 tests.
Since oracle is the ground truth, those 7 are **SPECULATION tests** (H₁₀ over-spec).

## Breakdown of the 9 fails on original impl

| Test | Class | Failed on patched? | Verdict |
|---|---|---|---|
| test_cross_all_token_with_intersection_not_blanket | AxisCrossing | pass | **REAL bug, discipline-caught (Hₐ₈ landing)** |
| test_cross_next_line_after_skips_and_specific_selector | AxisCrossing | FAIL | SPECULATION |
| test_selector_difference_minus_operator | SelectorOperators | pass | **REAL bug** (this catches the same root cause as test_110 in oracle) |
| test_blanket_suppression_dominates_specific | CombineAndMetrics | FAIL | SPECULATION |
| test_nosec_begin_case_insensitive | DirectiveKeywordCaseInsensitive | FAIL | SPECULATION |
| test_nosec_next_line_case_insensitive | DirectiveKeywordCaseInsensitive | FAIL | SPECULATION |
| test_selector_all_token_is_blanket | SelectorBaseTokens | FAIL | SPECULATION |
| test_selector_empty_is_blanket | SelectorBaseTokens | FAIL | SPECULATION |
| test_selector_omitted_is_blanket | SelectorBaseTokens | FAIL | SPECULATION |

**Real wins (2 of 9):** Composer-as-build-tools caught the *same* sentinel-collision bug at
proxy-author time via `test_cross_all_token_with_intersection_not_blanket` (my hand-written
test_38 equivalent) AND a more granular operator-precision bug via
`test_selector_difference_minus_operator`. That second test is finer than my hand version
— I had test_38 + test_39 (2); Composer-as-build-tools wrote 9 failing on original, 2 of
which are real.

**Speculation (7 of 9):** the discipline's PRD-quoting didn't filter these out. Diagnosed
shape: **the test's INPUT setup contains noise the PRD doesn't require to be suppressed.**

### Example diagnosis: `test_selector_all_token_is_blanket`

```python
src = "import subprocess\n# nosec-begin all\n" + B602_LINE + B105_LINE
issues, totals = run_bandit(src)
self.assertEqual(ids(issues), set())   # ← over-strict
```

The PRD doesn't say "the entire file is suppressed when `all` appears in a region directive."
The region per PRD starts on the LINE AFTER the directive. Line 1's `import subprocess` is
BEFORE the region → B404 should be reported. But the test asserts `set()` — zero issues —
which is stricter than the PRD requires. The patched impl correctly reports B404, and the
test fails on a *valid* impl.

**Pattern:** the discipline asks the author to PRD-quote the rule, but doesn't force the
author to PRD-quote the *negative* (what should NOT be suppressed by this rule). Composer
wrote `# PRD: "The special token all also suppresses all tests"` and then asserted "everything
is suppressed" — but "all tests" in the PRD means "the suppression covers all test IDs,"
not "all lines of the file are in the region."

## What this teaches the harness

1. **Hₐ₈ discipline transfers to Composer automatically.** Composer wrote 6 axis-crossing tests
   with PRD quotes, including 2 that caught real Composer impl bugs. The discipline's
   *structural* output (cross-axis enumeration, PRD-quote tag, discriminator comment) is
   reliably produced by the skill prompt.

2. **The discipline's TEST-FILTER step is incomplete.** Hₐ₈ catches "did you write an axis-
   crossing test?" but doesn't catch "is the test's assertion within what the PRD entails?"
   That's the H₁₀ typed-acceptance check, currently only at Phase 4 (post-adversary). Need
   to MOVE the soundness round-trip to Phase 2 itself, NOT defer it to adversary review.

3. **Specific patch path: build-tools Phase 2 needs a per-test "boundary clause" check.**
   For each test, the author quotes:
   - The rule's POSITIVE clause: "what the PRD says this rule does"
   - The rule's NEGATIVE clause: "what the PRD does NOT extend this rule to"
   The negative clause forces the author to think about over-broad assertions / input noise.
   For `test_selector_all_token_is_blanket`: positive = "all suppresses all test IDs";
   negative = "the suppression is bounded by the region's lineno scope, not the whole file."

4. **The discipline DOES eliminate the proxy-vs-grade gap when its output is sound.** The 2
   real-bug-catching tests reproduce the bandit fault at proxy-author time. If the
   discipline's soundness were tighter, the proxy gate would be a complete pre-oracle
   filter — implement-spec iterating against it would force grade-green at proxy-green.

## Cost ledger update

- Option (a-prime): ~$0.50 + ~10 min Composer-as-build-tools dispatch
- 1 generated proxy gate (51 tests)
- Confirmed structural transfer of Hₐ₈ discipline
- Diagnosed the discipline's soundness gap (negative-clause PRD-quoting missing)
- Discovered 1 additional real Composer bug not in my hand-list (test_selector_difference_minus_operator)
- 7 speculation tests classified and characterized

Total fault-discovery + fix cycle through this point:
- 2 Composer impl dispatches + 1 Composer build-tools dispatch
- ~$1 total model spend
- 9 grade-green-related datapoints
- 3 HG nodes (Hₐ₆, Hₐ₇, Hₐ₈) + meta-finding queued (Hₐ₉ "discipline soundness gap")

## Next step in the c → a-prime → a-prime-fix → b sequence

The new finding queues a-prime-FIX: patch the build-tools skill with the negative-clause
PRD-quoting + per-test soundness round-trip. Then dispatch Composer-as-build-tools again,
expect ≤ 2 speculation tests (vs current 7). Cost: another ~$0.50.

Or skip to (b) — fire happy-dom on the current discipline state, accept some speculation
in the gate, see whether axis-crossing transfer is real on a 2nd substrate before
re-investing in the discipline patch.

Foundation status: firm on the structural transfer; soundness has a named gap with a
specific patch path. The fault-finding loop is producing increasingly precise lessons
per iteration.
