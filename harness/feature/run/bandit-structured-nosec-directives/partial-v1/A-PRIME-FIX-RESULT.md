# a-prime-fix result: boundary-clause discipline added; soundness still gapped

**2026-05-28 ~21:10.** Patched build-tools/skill.md to add Hₐ₉ boundary-clause discipline,
re-dispatched Composer-as-build-tools. ~$0.50 + ~10 min.

## Generated proxy gate v2

- 48 tests (vs v1's 51)
- 15 classes (vs v1's 11) — including 3 dedicated axis-crossing classes:
  TestAxisCrossingSelectorGrammar, TestAxisCrossingRegionScope, TestAxisCrossingDirectiveInteraction
- 8 cross-axis tests (vs v1's 6) — discipline broadened the crossings considered
- 48 `# PRD-` negative-clause tags (100% coverage, as discipline mandated)
- 40 `# PRD+` positive-clause tags

## Verification

| | Composer-original impl | Composer-patched impl |
|---|---|---|
| v1 gate (no boundary discipline) | 9 fail / 42 pass | 7 fail / 44 pass |
| v2 gate (with boundary discipline) | **12 fail / 36 pass** | **11 fail / 37 pass** |

| Metric | v1 | v2 | Direction |
|---|---|---|---|
| Real-bug catches (failures-on-orig minus failures-on-patched) | 2 | 1 | **WORSE** |
| Speculation count (failures-on-patched) | 7 | 11 | **WORSE** |
| Total tests | 51 | 48 | smaller |
| Cross-axis tests | 6 | 8 | +2 |

**Boundary discipline did NOT close the soundness gap.** It produced more total speculation
than v1, and dropped one real-bug catch. The structural improvements (more cross-axis classes,
100% negative-clause coverage) didn't translate to soundness.

## Diagnosis of why

The persistent failure across both impls illustrates the deeper gap:
`test_cross_begin_inside_multiline_call_persists_past_close_paren` has a *correctly identified*
negative clause:
- `PRD-: Structural close-paren dedent must not end region started on an inner continuation line.`

But Composer's TEST INPUT assumes this negative clause means "region runs forever after the
close-paren." It places a second `subprocess.Popen` at col 0 on the line after the close-paren
and asserts `B602 NOT IN tids(issues)` — i.e., the region still covers that line.

Per the PRD's literal indent rule: auto-end fires when a later line has smaller indentation.
Line 6's col 0 < line 4's col 4 (the directive's column). So auto-end DOES fire at line 6 — at
the actual top-level dedent, just not at the structural close-paren. The region's extent ends
at line 5 (per the patched impl), not at line 7.

**The negative clause was correctly identified but the test author interpreted it more broadly
than stated.** The PRD- said "close-paren is not auto-end"; Composer interpreted it as "no
auto-end happens at all."

## Hₐ₉ refined

The boundary-clause discipline produces:
- 48 negative-clause tags ✓ (100% mechanical compliance)
- Right-shape negative clauses for cross-axis cases (the close-paren observation is correct)
- But: NO mechanism forcing the test's INPUT to actually exercise *only* what the positive
  clause entails, given the boundaries of other still-applicable rules.

The missing step: **enumerate OTHER PRD rules that still apply within this test's input
context.** The author of test_cross_begin_inside_multiline_call_persists_past_close_paren
quoted close-paren-not-dedent but forgot that the real-dedent-on-line-6 rule still applies.
Without an explicit "what other rules still apply here?" step, the author over-interprets
their negative clause.

## What this teaches about the discipline iteration loop

Each iteration of the discipline (Hₐ₈ → Hₐ₈+Hₐ₉) catches some failures and exposes deeper
ones. The shape we're discovering is **"every layer of explicit PRD-quoting catches a layer
of speculation, but speculation has more layers than the discipline does."**

This is the canonical limit of procedural disciplines: they can be iterated to add filters
but each filter has its own discrimination region. Eventually the residue is "be a careful
reader, with full PRD context held in mind" — which can't be proceduralized further.

**Practical conclusion:** stop iterating the proxy-author discipline. Accept that build-tools
will produce some speculation. The Phase 4 adversary review (typed-acceptance: ENTAILMENT /
DISCRIMINATOR / SPECULATION / WRONG) is the right place to filter the remaining speculation,
because the adversary brings a fresh PRD read independent of the author's interpretation.

The discipline progression:
- H₂ + Hₐ₂ (single-axis enumeration) — catches missing per-element tests
- H₈ (discriminator) — catches tests in the agreement region
- Hₐ₈ (axis-crossing) — catches missing crossings → STRUCTURAL TRANSFER WORKS
- Hₐ₉ (boundary clause) — catches over-strict positive assertions → PARTIAL SUCCESS
- H₁₀ (adversary typed-acceptance) — catches remaining speculation → STILL LOAD-BEARING

## Cost ledger

- a-prime-fix dispatch: ~$0.50 + ~10 min
- Pass2 gate generated, verified
- Confirmed boundary discipline transfers structurally but doesn't close soundness gap
- New finding: speculation has more layers than discipline; adversary review remains load-bearing
- Stopping discipline iteration here; remaining speculation deferred to Phase 4

## What's still firm

- Hₐ₈ structural transfer is real (8 cross-axis tests with proper shape, 2 catch real bugs)
- Both bandit fault root causes can be caught by build-tools-with-Hₐ₈ at proxy-author time
- The publishable claim: Flash+Composer with Hₐ₈ build-tools land axis-crossing test coverage;
  remaining speculation is filtered by Phase 4 adversary review (with patch path documented)

## Next step

Per user "one at a time" sequential preference: report this result, await direction on (b)
happy-dom fire or another sub-step.
