# Happy-dom build-tools fire — cross-substrate Hₐ₈ transfer (option b)

**2026-05-28 ~22:10.** Dispatched Composer-as-build-tools with the patched skill (Hₐ₈ + Hₐ₉)
against happy-dom-abort-pending-body-reads PRD. ~$0.50, ~2 min wall.

## Generated gate

- 19 tests, 7 describe blocks, 534 lines
- PRD+ tags: 16 (84% coverage)
- PRD- tags: 17 (89% coverage)
- discriminates: 19 (100%)
- crosses PRD: 3 (explicit axis-crossing tests; plus 12 implicit in body-type × shutdown matrix)

## Test organization (describe hierarchy)

1. Request body × shutdown trigger (4 tests — one per shutdown)
2. Response body × shutdown trigger (4 tests)
3. multipart formData() × shutdown trigger (4 tests)
4. preservation when not interrupted (2 tests)
5. discarded page side effects (2 tests — setTimeout + rAF)
6. axis-crossing: overlapping shutdown and consumption rules (3 tests)

**12 tests in the body-type × shutdown matrix** — Composer organized them as the PRIMARY test
structure, not just an axis-crossing category. The PRD's "the same shutdown behavior should
apply" clause was correctly identified as implying systematic matrix coverage.

## Predictions vs reality (from PREDICTION.md committed e383895)

| Prediction (rank, conf) | Outcome | Verdict |
|---|---|---|
| #1 Composer would proxy-green first pass | n/a (haven't fired impl yet) | DEFERRED |
| #2 50% probability of REWARD 0 with named axis-crossing failures | n/a | DEFERRED |
| #3a "navigation × body-type" most likely failure | Composer-as-build-tools wrote EXPLICIT tests for it | PROXY WILL CATCH IF impl misses |
| #3b multipart Response.formData() separate gap | Composer wrote 4 explicit multipart tests | PROXY WILL CATCH |
| #3c Timer cleanup misses page-vs-browser distinction | Composer wrote 2 tests (setTimeout + rAF on discarded page) | PROBABLY PROXY GAP — only 2 of 5 hidden timer tests covered |

## What this teaches

**Hₐ₈ structurally transfers across feature classes (n=2).**
- bandit (compositional/selector grammar) — cross-axis = `all` × operators, region × scope
- happy-dom (additive/abort-wiring) — cross-axis = shutdown × body-type, side-effect × scope

Both received systematic per-cell test enumeration. The discipline isn't tied to:
- Specific feature class (works for additive AND compositional)
- Specific language (Python unittest AND TypeScript vitest)
- Specific PRD wording style (dense compositional PRD AND short additive PRD)

The discipline's input — "PRD + skill file" — produces an output that respects the cross-axis
matrix implicit in the PRD's structure. The PRD-quoting steps (positive + negative) constrained
Composer to attribute each test to specific PRD clauses.

## Notable residue (Composer's "ambiguous" list)

Composer explicitly named what it didn't write tests for:
- Body read "never started" state
- Exact DOMException message
- Every timer kind (setInterval, etc.)
- Timer/rAF cleanup for all four shutdown paths (PRD only ties to "discarded page state")

This is the **Phase 1 triage discipline** working: certain → gate; ambiguous → residue. The
discipline's `# discriminates:` per test + residue-declaration pattern survived to happy-dom.

## What still needs measuring (to close option b end-to-end)

1. Spin up happy-dom container via pier
2. Fire Composer-as-impl on happy-dom PRD + this generated gate
3. Run gate against Composer's resulting impl
4. dsr grade against hidden oracle
5. Compare: does the patched harness produce REWARD 1 first-pass on a 2nd substrate?

Cost: ~$0.50 model + container provisioning + grade. Defer to next step.

## Foundation status

- Hₐ₈ structural transfer: **n=2 confirmed cross-substrate**, on additive AND compositional
- Hₐ₉ boundary discipline: present in output but soundness still gapped (per Hₐ₁₀ already named on bandit)
- The harness patch (build-tools Phase 2 with Hₐ₈ + Hₐ₉ + Phase 4 adversary) is the publishable combination
- Cross-substrate generality is now n=2 measured; we no longer have to caveat "bandit-specific"

## Cost ledger update

- Option (b) build-tools dispatch: ~$0.50 + ~10 min including waiting/dispatch retries
- 1 generated proxy gate (19 tests on a 2nd substrate)
- Confirmed cross-substrate transfer of Hₐ₈

Session total this thread:
- 5 Composer dispatches (kysely impl, bandit impl, bandit-bt v1, bandit-bt v2, happy-dom-bt)
- ~$2 model spend
- 11 grade-green-related datapoints across 2 substrates
- 5 HG nodes added (Hₐ₆, Hₐ₇, Hₐ₈, Hₐ₉, Hₐ₁₀)
- 15 commits
