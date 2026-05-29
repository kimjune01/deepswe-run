# Harness patch verification: Hₐ₈ discipline catches Composer's bugs at proxy-author time

**2026-05-28 ~21:35.** Tested option (a) of the c→a→b sequence: encode Hₐ₈ axis-crossing
discipline into build-tools/skill.md, hand-apply it to write 2 missing cross-axis tests for
bandit's proxy gate, verify they catch Composer's original bugs.

## Verification chain (each step costs $0 model)

### Step 1: encode the discipline
Patched build-tools/skill.md Phase 2 to add "Axis-crossing discipline (MANDATORY when ≥ 2
rules' preconditions intersect)" — 5 explicit steps, PRD-quoting requirement on each cross-
axis test, sentinel-collision + scope-boundary checks. Commit 7e05e02.

### Step 2: apply the discipline by hand (the proxy author would do this)
Wrote test_38 (`all & B602` sentinel-collision check) and test_39 (region-begin inside
multi-line statement scope-boundary check). Verified against the *patched* impl: 32/32 pass.

### Step 3: caught a real bad test via PRD-quoting
First attempt at test_39 conflated "auto-end-on-dedent" with "statement-wide propagation."
Per PRD's literal indent rule, my test assertion would have contradicted the PRD. The
discipline's step 5 ("PRD-quote each cross-axis test from both rules' clauses") forced me
to re-read and find that the actual cross-axis case is statement-wide rule × region-begin
scope, not bracket-tracking × dedent. Rewrote test_39 with explicit PRD quotes for both
clauses. **The discipline caught its own author's drift in real time.**

### Step 4: verify the augmented proxy catches Composer's *original* bugs
Reverted my hand patches (returned `_resolve_single_token` and `_compute_regions` to
Composer's exact original state). Re-ran the augmented proxy: **2 failures (test_38 +
test_39).** Original 30 tests still pass. So the augmented gate REDS exactly where Composer's
impl has its real bugs and GREENS everywhere else.

### Step 5: confirm patched impl + augmented gate is consistent
Re-applied hand patches → 32/32 proxy pass → `dsr grade` → REWARD 1 (base pass, new 78/78).
The chain holds end-to-end.

## What this proves

1. **The Hₐ₈ discipline produces the right tests** when applied by a careful proxy author.
   The cross-axis tests fall out mechanically from listing rule pairs whose preconditions
   intersect (selector tokens × operators; region-begin × statement-span).

2. **PRD-quoting is the protective step.** My initial test_39 had a wrong assertion; the
   PRD-quoting requirement made the bad test visible. The "speculation" failure mode that
   typed-acceptance (H₁₀) catches at the adversary phase is also caught earlier here by the
   discipline's own internal check.

3. **The augmented proxy gate would force implement-spec to fix Composer's bugs at proxy-
   author time.** If we re-fired Composer with this gate, the impl loop would iterate until
   both cross-axis tests passed; grade-green would follow from proxy-green at first verify.
   No hand-patching, no oracle peek.

4. **The harness patch is automatable.** The discipline is mechanical (enumerate pairs,
   construct inputs, PRD-quote, sentinel/scope check). Build-tools dispatched against any
   compositional PRD applies the same recipe.

## Cost ledger for option (a)

- 0 model tokens spent
- ~25 min total (writing discipline, writing the 2 tests, catching the bad test, fixing it,
  verifying against both impl states)
- Discipline encoded, verified to catch the bandit fault, verified to land on patched impl
- Foundation firm for option (b): fire happy-dom with this harness patch in place; if
  build-tools writes its proxy gate using the new discipline, expect Composer to first-pass
  proxy + grade if the discipline writes the right cross-axis tests.

## What remains uncertain

The verification above was done with *me* as the proxy author hand-applying the discipline.
A full automated verification requires:
- Dispatching the build-tools skill (now patched) against the bandit PRD from scratch
- Confirming the dispatched skill writes test_38 + test_39 equivalents on its own
- Letting implement-spec run against the resulting proxy

That would be ~$0.50-1.00 of model tokens. Option (b) (firing happy-dom on the patched
harness) tests a related but different question (cross-substrate transfer). The pure-
automation verification of option (a) on bandit is a worthwhile extra step if we have
budget.

## Provenance

- build-tools skill patch: commit 7e05e02
- augmented proxy gate: /tmp/bandit-impl/test_proxy.py classes AxisCrossing
  (test_38_all_intersect_specific_resolves_to_specific,
   test_39_region_begin_mid_multi_line_statement_suppresses_whole_stmt)
- impl revert + patched cycle: this file
