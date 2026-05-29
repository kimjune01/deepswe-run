# Bandit fire #1 RESULT — proxy-green / grade-red (the smoking gun)

**2026-05-28 ~20:23-20:29.** Composer 2.5 wrote 5-file impl in ~5.5 min wall.

## Outcomes

- **Proxy gate:** 30/30 passing (Composer's self-claim "all 30 pass when plugins load" verified in container).
- **Oracle (`dsr grade`):** base PASS (regression suite clean) + new FAIL (3 of 78 new tests fail) → **REWARD 0**.
- **Grade-pass rate on the hidden feature gate: 75/78 = 96.2%.**

## Predictions vs reality

| Prediction (rank, conf) | Outcome | Verdict |
|---|---|---|
| #1 Composer proxy-green first pass (60%) | 30/30 | **CONFIRMED** |
| #2 Proxy-green + grade-red possible (50%) | new FAIL | **CONFIRMED** — proxy-vs-grade gap measured |
| #3a selector `&`/`!` precision failure | test_110 `-` (difference) failed | **CONFIRMED** (operator class right, specific op different) |
| #3b path/fixture skip rules (semicolons/ellipsis) | tests 25-27 passed | refuted on this slice |
| #3c metrics classification by RESOLVED set (M1 shape) | test_123 `all & B602` → wrongly counts as `nosec` | **CONFIRMED** — direct hit |

Three of four prediction sub-classes confirmed. The path/fixture one was *covered* in Composer's impl
(skip blank/comment/grouping/semicolon — passes 25-27) so the prediction was right about the shape
but wrong that Composer would miss it. Net: predictions were calibrated; the missing skill is the
classification-by-resolved-set discipline.

## What failed and why

### test_123 — `nosec-next-line all & B602` should count as `skipped_tests`, not `nosec`

The PRD: "Classification is based on the resolved set: if the result is a blanket suppression,
it counts as `nosec`; if it resolves to a non-empty specific set, it counts as `skipped_tests`."

`all & B602` parses to "all tests INTERSECT {B602}" which resolves to `{B602}` — a non-empty
specific set. PRD says count as `skipped_tests`. Composer counted as `nosec` (blanket).

**Root cause (refined post-source-inspection, 2026-05-28 ~20:35):** *sentinel-value architectural
error*, not the "classify by syntactic shape" I predicted. In `bandit/core/nosec_directives.py:
395-396`, `_resolve_single_token` returns `set()` for the token `all`. That same `set()` is the
API sentinel for "blanket" used downstream by `tester.py:87` (`if not nosec_tests_to_skip:
note_nosec()`). When the parser does `set() & {"B602"} = set()` for the intersection, the
empty set is **indistinguishable from the blanket sentinel** — so the tester routes to `nosec`
instead of `skipped_tests`.

**Fix is one line:** return `set(enabled_ids)` from `_resolve_single_token` for "all", letting
`set() & {"B602"} = {"B602"}` propagate correctly. Top-level "all" handling in
`_resolve_selector:264-265` (early-return `set()` when selector text is exactly "all")
preserves the blanket signal at the API boundary.

This is a **precision bug at the algebra/API seam**, closer to H₈-discrimination-at-boundary-
conditions than to M1-by-syntactic-shape. The proxy gate's test_07 (`all` alone) and test_15
(intersection of two literals) both pass — but **no proxy test crosses the seam of "all on one
side of an intersection."** That cross-axis test is exactly what build-tools Phase 2-bis
mutation thinking would write. The patch landing zone is unchanged from prediction; the
specific bug-shape is one architectural layer deeper than predicted.

### test_110 — selector `-` (difference) precision on a non-trivial set

Composer's parser handles `|`, `&`, `-`, `!` (its summary says so) but the precision is off when
the difference resolves to a set the test asserts equality against. Likely a precedence or
left-associativity bug not exercised by the proxy gate's test_16 (which is a simpler case).

### test_058 — region semantics unioned across a multi-line statement

PRD: "If a multi-line statement has any suppressed line, findings for that statement are
suppressed even if a `# nosec-end` appears on a later line within the same statement."

Composer's region logic handles single-line ending correctly (passes test_29) but doesn't
correctly union across a multi-line statement spanning a region boundary. Compositional class.

## What this teaches

1. **Hₐ₆ REFINED.** "Composer first-passes proxy on dense features" stays at n=2 (kysely + bandit
   both 100% proxy-green). But "first-passes oracle" splits: n=1 PASS (kysely 254/254) + n=1 PARTIAL
   (bandit 75/78). The harness gap is at the *proxy author* stage, not the *implementer* stage.

2. **H₈ (mutation thinking) is load-bearing for Composer on compositional features.** Test_123 is
   the exact M1 shape Claude needed H₈ to catch. The proxy gate didn't include this test because
   build-tools wrote it without mutation-thinking applied. **Patch path: build-tools Phase 2-bis must
   write a "classify by resolved set" mutation test for any feature with selector-operator semantics.**

3. **H₉ (cross-family adversary) was non-firing AT PROXY-AUTHOR TIME.** The adversary slot in the
   skill files runs in build-tools Phase 4 / implement-spec Phase 4 — review of the impl's diff.
   But the gap here is *before* either Phase 4 fires: the proxy gate itself lacks the test that
   would catch test_123's shape. **The adversary needs to fire earlier — at proxy-gate authorship,
   not at impl review.** This is a real architectural finding for the harness.

4. **The publishable claim now has its first measured limit.** "Flash+Composer in this harness
   match SOTA on the bench's behavioral contract" is true on kysely but only partially on bandit
   (96.2%). The honest framing: **"this harness with this model pair lands proxy-green on dense
   feature PRDs and matches gold within ~4% on the oracle for compositional/selector tasks. The
   gap is in proxy-author mutation-thinking and is patchable in build-tools."**

5. **Bandit was the right perturbation to fire.** The kysely-only measurement would have produced
   an over-optimistic publishable claim. Firing the F₁₂ compositional anchor surfaced the failure
   mode in 5 minutes of Composer time and three predicted test failures.

## Next steps

- Patch build-tools Phase 2 with explicit "classify by resolved set" mutation test for selector
  features. Re-fire bandit, see if the patched proxy catches test_123 shape at proxy-author time.
- Inspect Composer's `nosec_directives.py` `_classify()` or equivalent to confirm the diagnosis
  (syntactic vs resolved-set classification).
- Pick the next perturbation: a *path/fixture-dominant* substrate (happy-dom or
  opa-template-string-reconstruction) — Hₐ₁ is the unbuilt frontier and Composer's behavior there
  is unmeasured.

## Update 2026-05-28 ~20:45 — cheap learning round 2: gold inspection + root-cause taxonomy

Continued the H₆-economy reading pass ($0 spent total): inspected gold and the failing tests'
sources to refine the diagnosis from "3 failures, 3 unknown causes" → **3 failures, 2 root
causes, 1 meta-pattern.**

### Gold's parser handles "all" correctly via a different scope

Gold at `solution.patch:587-588`:
```python
if low == "all":
    return set(enabled_test_ids), idx + 1
```

Gold made the same architectural choice as Composer (using `set()` as the API blanket sentinel)
but **disambiguates `all`-as-operand from `all`-as-API-input**: inside the parser, the operand
"all" resolves to the actual full enabled-set so `set(enabled) & {B602} = {B602}` correctly.

**Composer collapsed both onto `set()`.** One token-resolution line difference between gold
and Composer. The fix is mechanical.

### Test_110 shares the same root cause

`# nosec-begin all - B602` triggers `_resolve_single_token("all") → set()`, then
`set() - {"B602"} = set()` = blanket sentinel = wrong suppression. **The one-line fix closes
both test_123 AND test_110.**

### Test_058 is a separate root cause: auto-end-on-dedent fires mid-statement

Test body:
```python
import subprocess
subprocess.Popen(
    'x',
    shell=True,  # nosec-begin B602
)
# nosec-end
```

Trace through Composer's `_compute_regions`:
1. Line 4 has `# nosec-begin B602`, indent=4. Push (4, 4, "B602") onto stack.
2. Line 5 is `)`, indent=0. `while stack and indent < stack[-1][1]` fires: 0 < 4 → pop. Region
   recorded as (5, 4) — **inverted/empty range, no suppression**.
3. Line 6's `# nosec-end` doesn't find a region to close (stack empty).

**Composer's bug:** auto-end-on-dedent doesn't track open brackets. Gold likely tracks "are we
inside an unclosed paren" before treating a lower-indent line as a real dedent.

### The meta-pattern across both root causes

Both bugs share the same shape: **Composer applied a clean single-axis rule at the wrong scope,
ignoring a cross-axis condition.**

| Bug | Single-axis rule (correct in isolation) | Cross-axis condition (ignored) |
|---|---|---|
| #1 (tests 110, 123) | "`all` means blanket" | "...but only at top level; as an operand inside an expression, `all` resolves to the actual set" |
| #2 (test 058) | "lower indent ends a region" | "...but only outside open brackets; the closing `)` of a multi-line call is structural, not a dedent" |

### Patch landing zone (now precisely scoped)

The **harness patch** belongs in build-tools Phase 2-bis (mutation thinking at proxy-author time).
Both Composer failures would have been caught if the proxy gate had **cross-axis tests**:
- For selector: a test like `nosec-next-line all & B602 → expect specific {B602}, not blanket`
- For regions: a test like `# nosec-begin mid-paren → expect region applies past the closing paren`

The proxy gate had single-axis coverage (test_07 `all` alone, test_15 simple intersection,
test_19 auto-end-on-dedent at top level) but **no cross-axis tests**. The discipline-patch:
build-tools must enumerate boundary-crossing inputs when the PRD lists multiple rules whose
preconditions intersect.

This is **H₈ at the *proxy-write* phase**, applied to the *axis-crossing* sub-class of mutation
inputs (previously named in HG as "agreement-region" testing on a single axis; now extended to
"axis-intersection-region" testing).

### Cost ledger for this round of cheap learning

- 0 model tokens
- ~10 min reading
- Diagnosis tightened from "M1 by syntactic shape" → "two distinct cross-axis-scope errors with
  shared meta-pattern, both addressable by mutation thinking at proxy-author time"
- The patch landing zone confirmed at the *exact* file and discipline (build-tools Phase 2-bis,
  axis-crossing mutation thinking)

This is the H₆ economy hypothesis paying off: gold-isolate + source inspection narrowed the
search from "fire patches and re-measure" to "we know exactly what to patch and exactly which
tests will verify."
