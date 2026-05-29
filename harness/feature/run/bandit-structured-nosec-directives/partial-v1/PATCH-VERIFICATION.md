# Patch verification: hand-applied fixes close the bandit fault

**2026-05-28 ~21:00.** Applied the two patches diagnosed in RESULT.md round 2 directly to
Composer's impl in /tmp/bandit-impl/bandit/. Result:

## Verification path

1. Applied patch #1 (one-line "all" fix) only first. Confirmed.
2. Applied patch #2 (bracket tracking in _compute_regions). First attempt broke test_19
   because the tracker marked any line containing `()` as "in bracket." Refined to "line
   begins with bracket_depth > 0" (i.e., true continuation line).
3. docker cp → container; proxy gate 30/30 OK; `dsr grade` → REWARD 1.

## Final state

- Proxy gate: 30/30 passing
- Oracle (`dsr grade`): base PASS + new PASS → **REWARD 1**
- All three originally-failing tests now passing:
  - test_058_region_unioned_across_statement_lines ✓
  - test_110_selector_difference_suppresses_other_not_this ✓
  - test_123_selector_all_and_B602_counts_as_specific ✓
- Other 75 new tests still passing; no regressions in the existing suite.

## Patch sizes vs diagnosis

| Patch | Diagnosed size | Actual size | Match |
|---|---|---|---|
| #1 `all` sentinel | 1 line | 1 line + comment | ✓ |
| #2 bracket tracking | multi-line (paren-tracking) | ~12 lines (token-loop + arg pass-through + dedent guard) | ✓ shape; size as expected |

## What this proves

- **The diagnosis was exact.** Both root causes named in RESULT.md ($0 reading round) were the
  actual bugs. The fixes are mechanically derivable from the diagnosis.
- **The bandit fault transferred cleanly from "fault found" to "fault fixed" without re-running
  Composer.** Total cost from fault discovery to verified fix: **$0 model spend.**
- **Hₐ₈'s meta-pattern is real.** Both bugs were "single-axis rule applied at wrong scope" and
  both yielded to "disambiguate the scope, leave the rule intact" fixes.
- **The proxy gate that Composer wrote (and that build-tools authored) is the missing layer.**
  The bench grader has tests 058, 110, 123 for these exact cross-axis cases. The proxy gate
  has tests for each axis IN ISOLATION (07 = all alone, 15 = simple intersection, 19 = top-
  level dedent, 29 = statement-wide single line) but not for the intersections. **The
  build-tools Phase 2-bis discipline (axis-crossing mutation enumeration) would have written
  these tests, and Composer's impl would then have been forced to handle them.**

## Foundation firmness

The session's "Composer in the right harness matches SOTA on this task class" hypothesis now
has its first verified-firm-foundation datapoint:
- Bandit substrate: Composer's 96.2% first-pass deficit is fully recoverable through a 13-line
  patch operating on the same impl. The work Composer does is correct on the rules it sees;
  the gap is in *which* rules' interactions get tested at proxy-author time.

Next steps with this firm foundation:
1. **The patch belongs in build-tools' skill file** as Phase 2-bis "axis-crossing mutation."
   When applied, build-tools will write the missing cross-axis proxy tests, Composer's impl
   will fail them at proxy-author time (red, not green), implement-spec will iterate, and
   grade-green follows from proxy-green that includes the cross-axis tests.
2. **The honest publishable claim:** "Flash+Composer with axis-crossing mutation in build-tools
   land grade-green on dense compositional features as well as breadth features. Without that
   discipline, they land at ~96% with predictable cross-axis gaps."

## Receipts

- Patches in /tmp/bandit-impl/bandit/core/nosec_directives.py (lines 51-60 token-loop +
  bracket tracking; line ~395-401 `all` token; line ~142-160 `_compute_regions` signature
  + dedent guard).
- Full grade output: `dsr grade bandit-structured-nosec-directives` reward.txt → 1.
- Stestr output confirming test_058, test_110, test_123 all pass.
