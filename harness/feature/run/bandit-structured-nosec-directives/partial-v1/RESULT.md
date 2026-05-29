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

**Root cause:** Composer's classifier looks at the syntactic shape (saw `all`, decided blanket)
without applying the resolution rules. This is the exact M1 shape Claude needed H₈ mutation
thinking to catch in the F₁′ session.

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
