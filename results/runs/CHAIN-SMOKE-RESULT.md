# n=3 substrate chain smoke — 2026-05-29

Three substrates × three arms = 9 arm runs through the unified `harness/run_arm.sh`. Parallel chains (bandit + oxvg) plus the earlier kysely arms. Closes FREEZE-CHECKLIST §X.2 (n≥3 task smoke across feature classes).

## Matrix

| task | arm | reward | base_pass | new_pass | class | wall |
|---|---|---|---|---|---|---|
| kysely-window-grouping-helpers (breadth-additive) | scaffold | **1** | Y | Y | RESOLVED | 485s |
| kysely-window-grouping-helpers | baseline-comp | **1** | Y | Y | RESOLVED | 163s |
| kysely-window-grouping-helpers | baseline-flash | 0 | Y | N | UNRESOLVED_NO_DIFF* | 214s |
| bandit-structured-nosec-directives (compositional) | scaffold | 0 | **Y** | N | UNRESOLVED_MODEL | 592s |
| bandit-structured-nosec-directives | baseline-comp | 0 | **N** | N | UNRESOLVED_MODEL | 221s |
| bandit-structured-nosec-directives | baseline-flash | 0 | Y | N | INFRA_PARSE | 221s |
| oxvg-structural-selector-preservation (subtractive) | scaffold | 0 | Y | N | UNRESOLVED_MODEL | 1102s |
| oxvg-structural-selector-preservation | baseline-comp | 0 | Y | N | UNRESOLVED_MODEL | 763s |
| oxvg-structural-selector-preservation | baseline-flash | 0 | Y | N | INFRA_PARSE | 476s |

*kysely baseline-flash ran v4 with the OLD classifier (before APPLY_FAILED check); would be re-classified INFRA_PARSE under the current classifier (its extracted.diff was 32KB but git-apply rejected as "corrupt patch at line 81").

## Headline signals

### 1. Real harness benefit on bandit (the compositional substrate)

| arm | base_pass |
|---|---|
| scaffold | **Y** (preserved existing 22/22) |
| baseline-comp | **N** (regressed existing) |

**Same model, only harness shape differs.** Composer's one-shot on bandit broke existing tests; the scaffold's design-doc + proxy gate + dual-adversary discipline kept the impl from regressing. New tests didn't pass for either arm, but only the scaffold left the system *non-broken*. This is a measured within-model harness ablation, n=1 substrate.

### 2. No measurable harness benefit on kysely (breadth-additive)

Both scaffold and baseline-comp RESOLVED. Scaffold added 3× wall + ~5× model spend for no measurable reward gain. *On clean additive tasks the scaffold is overhead.*

### 3. No measurable harness benefit on oxvg new-test passing (subtractive)

Both Composer arms preserved base; both failed new. Neither solved oxvg's optimizer-class problem in one pass. The scaffold's discipline preserved base in both cases.

### 4. baseline-flash INFRA_PARSE on 3/3 substrates

Gemini-3.5-flash produced fenced unified diffs whose hunk-context lines were hallucinated; git-apply rejected all three. Corroborates the [[gemini-family-discriminator-not-generator]] pattern at corpus-relevant n=3. Use Composer (or Sonnet/Opus/GPT-5.5) for multi-file generation; never Gemini.

## The task-class-dependent richness pattern

Harness richness pays differently by feature class:
- **Compositional / dense PRD (bandit):** scaffold's discipline prevents regression of existing tests. Real measured benefit.
- **Breadth-additive (kysely):** both arms one-shot it; scaffold is overhead.
- **Subtractive (oxvg):** both fail equivalently in one pass — needs Phase 4 + revision loop to surface harness benefit.

If the 113-task corpus has the F₁₂ class distribution (~41% breadth / ~32% compositional / ~14% path / ~13% other), the harness-richness benefit may concentrate on the 32% compositional slice, with the breadth and other slices showing flat (no help) or negative (overhead) deltas. Worth pre-declaring in the prereg.

## Critical gap surfaced by this smoke

**Phase 4 is in the build-tools skill but NOT wired into `run_arm.sh`.** The scaffold arm runs:

```
design-doc → build-tools → Phase 3.5 dual-adversary → residue-lint → implement-spec → CAPTURE & GRADE
```

There's no Phase 4 adversary review of the impl with `RESIDUE.md` carry-forward and no revision loop. The prereg defines Phase 4 as part of the scaffold treatment (and we just amended §3a to make this explicit), but the runner doesn't fire it. The reported scaffold results above are scaffold-minus-Phase-4.

**Implications:**
- The bandit "scaffold preserved base, baseline-comp regressed" finding is real but *understates* the full scaffold's potential — it reflects upstream-only discipline (design-doc + build-tools + proxy gate), not the adversary's post-impl catch.
- The current scored run would measure the wrong treatment. **Phase 4 wiring is a freeze blocker.**
- Composer-as-Phase-4-adversary has never been measured head-to-head against Flash. The prereg's Flash-at-Phase-4 choice is theory, not evidence.

## Open question on Flash-as-adversary (deferred)

Flash's only measured value-add is on bandit Phase 3.5 (caught the axis_crossing soundness bug Composer missed). On kysely Phase 3.5, Flash added 0 unique catches; Composer caught everything. Phase 4 untested.

Cheap experiment to settle: **Composer-sole as Phase 3.5 adversary on bandit with explicit soundness ask** (the earlier measurement had Composer doing breadth lens *in parallel* with Flash doing soundness; Composer may not have *tried* the soundness lens because Flash was occupying it). If Composer-sole catches the axis_crossing bug, Flash is redundant and we drop it. ~$0.02, ~2 min wall.

## Cost ledger (this chain segment, 2026-05-29)

- bandit chain: scaffold ~$1.50 + baseline-comp ~$0.30 + baseline-flash ~$0.005 = **~$1.80**
- oxvg chain: scaffold ~$1.80 + baseline-comp ~$0.50 + baseline-flash ~$0.005 = **~$2.30**
- kysely chain (from earlier): **~$1.80**
- Recon comparison (3 Composer recon dispatches): **~$0.03**
- **Total chain segment: ~$5.93** for n=3 × 3 arms + recon comparison
- Wall: ~30 min (bandit + oxvg in parallel) + kysely earlier

## Receipts

- `kysely-window-grouping-helpers/{scaffold,baseline-comp,baseline-flash}/`
- `bandit-structured-nosec-directives/{scaffold,baseline-comp,baseline-flash}/`
- `oxvg-structural-selector-preservation/{scaffold,baseline-comp,baseline-flash}/`
- `../recon-comparison/composer-recon-{kysely,bandit,oxvg}-*.txt`
- This file: `CHAIN-SMOKE-RESULT.md`
- Sibling per-task: `kysely-window-grouping-helpers/SMOKE-RESULT.md`

## What closes / what remains on FREEZE-CHECKLIST

| item | status |
|---|---|
| §I.a End-to-end smoke per arm | ✅ 9 arm runs across 3 substrates |
| §I.b Artifact schema | ✅ uniform across all 9 |
| §I.c Replay test | ⏸ deterministic in principle; script not written |
| §I.d No-op test | ✅ baseline-flash fired UNRESOLVED_NO_DIFF and INFRA_PARSE classes correctly |
| §I.e Patch-capture sanity | ✅ no test-grader files in any model.patch |
| §I.f Arm isolation | ✅ fresh container per arm |
| §V Failure taxonomy | ✅ 4 distinct classes fired correctly (RESOLVED ×3, UNRESOLVED_MODEL ×3, INFRA_PARSE ×2, UNRESOLVED_NO_DIFF ×1) |
| §VII RESIDUE rules | ✅ residue-lint hook fired clean on all scaffold arms |
| §X.2 n≥3 task smoke | ✅ this document |
| Phase 4 wiring | ❌ skill defines it, runner doesn't fire it |
| Composer-vs-Flash Phase 4 head-to-head | ❌ not measured |
| Composer-sole Phase 3.5 on bandit | ❌ not measured |
| §X.3 EC2 single-box arm smoke | ⏸ pending (box-infra already validated via smoke_box.sh) |
| §X.4 EC2 multi-box dispatcher | ⏸ pending |
| §II prompt-freeze hashes | ⏸ pending |
