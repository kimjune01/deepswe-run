# Kysely transfer-risk-v1 (H₉ n=2)

**Date:** 2026-05-29
**Substrate:** kysely-window-grouping-helpers (breadth-dominant additive, TS/JS, multi-feature PRD)
**Author:** Gemini 3.5 Flash with full discipline (`--approval-mode plan`)
**Reviewers:** Gemini 3.5 Flash + Composer 2.5 (dual-adversary, identical prompt)

## Headline

| metric | Flash | Composer | shared / overlap |
|---|---|---|---|
| Findings | 13 | 45 | ~6 |
| Soundness catches | **0** | **5** | 0 |
| Discrimination | 6 | 25 | ~5 |
| Missing coverage | 6 | 14 | ~1 |
| Harness slips | 0 | **1** (F45: undefined `db` import wiring) | 0 |
| Cost per review | $0 (free tier) | ~$0.01 | — |

**Estimated H₉ overlap on kysely: ~11.5% (6/52).** Much lower than bandit's 37.9%. The two adversaries are *more* complementary on breadth-additive substrates than on compositional ones.

## The substrate-dependent reversal

**On bandit (compositional, dense Python PRD):** Flash beat Composer on soundness (2/2 vs 1/2). Flash's mechanical PRD-scope tracking caught literal over-asserting.

**On kysely (breadth-additive, multi-feature TS/JS PRD):** Composer beat Flash on soundness (5 vs 0). Composer caught the gate over-asserting on dialect-specific quoting (SQLite vs PRD-neutral), empty grouping sets the PRD doesn't require, alias names the PRD doesn't specify, ntile type-generics the proxy can't enforce, and the entire `db` undefined harness slip Flash missed.

Flash on kysely declared "the current tests are highly sound" — got 0/5. Flash's literal scope-tracking didn't catch the **over-scoping** failure mode that dominates on a breadth-additive substrate (assertions adding requirements the PRD doesn't make).

## What this means for the dual-adversary recommendation

It **strengthens** it. The bandit measurement could have been read as "Flash is the soundness catcher, Composer is the breadth surfacer." On kysely the roles flip: Composer is the soundness catcher (over-scoping), Flash is the missing-coverage gap surfacer.

The lens difference is real, but *which lens catches which failure mode is substrate-dependent*. A single adversary is structurally insufficient. The dual-adversary protocol at Phase 3.5 (just added to `build-tools/skill.md`) is more important than the bandit n=1 measurement made it look.

## H₉ catch quality on this artifact

The Flash kysely gate has 3 substantive issues an end-to-end run would have surfaced:
1. **Dialect over-specification** (Composer F2): every `assert.equal(sql, ...)` assumes SQLite quoting (`"identifier"`) and lowercase keywords. PRD specifies clause shapes, not dialect. Catches: Composer ✓, Flash ✗.
2. **Empty grouping set assertion** (Composer F1): test asserts `grouping sets((...), ())` — PRD does not mandate empty entries. Catches: Composer ✓, Flash ✗.
3. **Harness wiring** (Composer F45): file imports `Kysely, SqliteDialect` but never instantiates `db`. The gate will not run as-shipped. Catches: Composer ✓, Flash ✗.

Plus 6 discriminator-gap findings where the test would pass against plausible mutants (ntile/lag/lead missing parameter-array assertions). Catches: both adversaries, redundantly.

## Confidence updates

- **H₉ (cross-family review catches structural blind spots):** strengthened. n=2 across two feature classes (compositional + breadth-additive). The overlap-collapses-to-self-review threshold (>70%) is not approached on either substrate.
- **H₈ on Flash (discipline is load-bearing):** confirmed on kysely too — Flash produced 100% PRD-quoted tests + 3 unprompted RESIDUE entries. The pattern transfers.
- **Hₐ₁₀ (speculation has more layers than discipline):** confirmed in the failure mode — Flash's discipline produced sound-on-the-letter tests but over-scoping on dialect, which is exactly the "missing soundness filter" Hₐ₁₀ names.
- **Dual-adversary at Phase 3.5:** strongly supported.

## H₁ᵦ on Flash (oxvg classify)

Separate sub-fire (`harness/feature/run/oxvg-structural-selector-preservation/transfer-risk-v1/flash-classify-raw.txt`):

Flash classified the oxvg PRD as:
- FEATURE-SHAPE: invariant ✓
- FEATURE-TYPE: optimizer ✓
- BRANCH: 2 (narrow-the-transform) ✓
- Rationale explicitly invoked purpose-over-surface ("narrowly restrict its transformations, protecting only the specific elements ... preventing over-protection")

**H₁ᵦ passes on Flash.** The purpose-over-surface discipline transfers from the Claude pair to Flash. The decision tree's branch-2-wins rule for SUBTRACTIVE/optimizer-purpose features is correctly applied.

## What we did NOT run this batch

- **H₇ (design-doc iteration) on Flash kysely.** Deferred; can fire as cheap follow-up if iteration's value is uncertain after we see kysely impl runs.
- **n=2 H₈ ablation on kysely.** Implicitly covered (Flash with vs without discipline on kysely would mirror bandit pattern), but not directly measured.

## Cost ledger

- Flash kysely author: $0 (free tier)
- Flash oxvg classify: $0
- Flash kysely adversary: $0
- Composer kysely adversary: ~$0.01
- **Total: ~$0.01, ~12 min wall**

## Receipts

- `flash-author-prompt.md` — disciplined Flash author prompt
- `flash-author-raw.txt` / `flash-test_proxy.mjs` — 35-test kysely gate, 3 RESIDUE entries
- `review-prompt.md` — dual-adversary prompt
- `flash-adversary-raw.txt` — 13 findings
- `composer-adversary-raw.txt` — 45 findings
- `RESULT.md` — this file
- Sibling: `../oxvg-structural-selector-preservation/transfer-risk-v1/flash-classify-raw.txt`
