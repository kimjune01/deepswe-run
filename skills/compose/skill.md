---
name: compose
description: Tooling phase for feature-request (PRD-shaped) tasks whose PRD is a transform invariant / compositional rule with no flat enumeration to fan out (sibling of build-tools, routed by design-doc's FEATURE-SHAPE hint). Reads the codebase to *infer* the surface across which the invariant must hold — the surface the PRD doesn't list — and emits paired control/perturbation tests across that inferred matrix. Same manifest contract as build-tools so `dsr gate` / `dsr isolate` work unchanged.
argument-hint: <task-id>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Compose: encode an invariant into a discriminating shell

Take the design doc's invariant criteria — clauses that hold *across* a surface the PRD never enumerates — and convert them into deterministic paired tests. **The load-bearing step is reading the codebase to find the surface.** Hₐ₂ enumerates surfaces the PRD lists; compose enumerates surfaces the PRD *implies* via the invariant.

## When to invoke compose vs build-tools

Routed by design-doc's `FEATURE-SHAPE:` line (Hₐ₃ predicate):

| FEATURE-SHAPE | What the PRD looks like | Skill |
|---|---|---|
| `enum` | flat lists of operators/methods/keywords/variants; PRD names the surface | **build-tools** |
| `invariant` | prose rules ("X holds when Y"; "must preserve Z"); surface is *implied* by the invariant, not named | **compose** |
| `mixed` | both — enumerated surface AND invariant clauses across an unstated wider surface | **both** in sequence: build-tools for the named surface, then compose for the inferred axes |

If the operator routed wrong, the first sign is the manifest's test count and SOUND/LIVE shape:
- compose on a `enum` PRD: produces few tests because the invariant statement is shallow.
- build-tools on an `invariant` PRD: produces SOUND+LIVE but the gate has a coverage hole on
  inferred axes (the oxvg pattern: 4 combinators tested, 6 structural pseudos missed).

## Rules (read first)

- **Spec + codebase only.** Hidden grader is never read. The codebase IS the second source — that
  is the whole point. Reading source to enumerate axes is mandatory, not optional.
- **Necessary, not sufficient.** Failing the proxy ⟹ failing the grade. Passing ≠ certified pass.
- **Soundness over coverage.** A wrong test (fails a correct impl) is worse than a missing one.
- **The PRD doesn't list the surface — the codebase does.** When the PRD says "structure-
  dependent rules" without listing what counts as structure-dependent, the existing parser/
  evaluator/transformer in the codebase IS the list. Read it.
- **Ambiguity → residue, not gate.** Surface elements whose invariant-behavior is ambiguous from
  the PRD alone stay in design-doc residue + implement-spec LLM. Never as a proxy test.

## Environment

- Repo in offline Docker container; reach via `box-sh '<cmd>'`; already `cd`s to repo root.
- Write artifacts to `$PROXY_GATE_DIR` (fixed scratch path, persists for downstream skills).
- `codex` runs locally, not in the container.

## Output (three artifacts at `$PROXY_GATE_DIR`, same as build-tools)

1. **Proxy gate** — paired control/perturbation tests in the repo's framework.
2. **Surface matrix** (`$PROXY_GATE_DIR/surface-matrix.md`) — the inferred surface, with provenance per axis (file:line). This is the load-bearing artifact: review-able, attackable, the receipt that surface inference actually happened.
3. **Manifest** (`$PROXY_GATE_DIR/manifest.json`) — same schema as build-tools (so `dsr gate` / `dsr isolate` work unchanged).

Append nodes to the hypothesis graph (never truncate).

## Process

### Phase 0 — Self-classify + convergence read (monoidal contract for LLM skills)

LLM output is not bit-stable. The contract isn't strict idempotency but **convergence under iteration** (cf. `/humanize`): each pass narrows the diff against the fixed point; the dampener is acting only on what's still inconsistent, leaving stable parts alone.

**Self-classify on the PRD shape** (don't trust design-doc's FEATURE-SHAPE blindly):

| Shape | Action |
|---|---|
| **applies** — PRD has ≥ 1 invariant clause whose surface the PRD does not enumerate | proceed to Phase 1 |
| **partially-applies** — PRD has both invariant clauses AND listed enumerations | proceed; write *only* the invariant slice; leave enumeration slice to build-tools |
| **does-not-apply** — PRD is pure flat enumeration with no unstated-surface invariants | **identity stub**: `compose.applied: false`, empty `compose.criteria: []`; do not touch the proxy gate file; exit. Recoverable misroute. |

Sniff rule (mirror of build-tools'):
- `enum-count` = PRD listings of ≥ 2 named elements.
- `invariant-count` = PRD "preserve / must hold / when X then Y" clauses across unstated surfaces.
- `applies` if invariant-count ≥ 1 AND enum-count = 0.
- `partially-applies` if both > 0.
- `does-not-apply` if invariant-count = 0.

**Convergence read** (handles the LLM-nondeterminism gap):

1. Read existing `manifest.json` if any. If `compose.applied == true`:
   - Read existing `surface-matrix.md`. Re-run Phase 2 surface inference against the current codebase. **Keep axes whose provenance file:line still exists and still matches.** Add axes only if the codebase has gained a kind the matrix omits; remove axes only if the codebase has dropped a kind the matrix lists.
   - Read each paired test. Re-run the Phase 4 step 6 observable-divergence check. **Keep test pairs that still discriminate the named plausible-wrong impl.** Add pairs only for new axes; remove pairs only on verify-spec soundness kill.
   - Report `// CONVERGENCE: axes-kept N, added M, removed K; pairs-kept P, added M', removed K'` in the test file header. If `M + K + M' + K' == 0`, fixed point — no-op.
2. If `compose.applied != true`: full build as Phase 1+.

The dampener: M, K, M', K' shrink monotonically across runs on the same PRD + codebase; after ~2 passes the gate is at fixed point. The surface matrix is the legible artifact making the dampener visible — operator can audit "what changed across runs" by diffing `surface-matrix.md`.

**Manifest merge** (Phase 6 detail, restated): read-merge-write; preserve `build_tools`'s slice; recompute `proxy_gate.{run,path,criteria}` as the union.

The contract: `build-tools ∘ compose ≈ compose ∘ build-tools` on `mixed` (converge to same fixed point). `compose ∘ compose ≈ compose` (re-run shrinks to zero edits). Identity on wrong-shape input (clean stub).

### Phase 1 — Triage criteria

Per design-doc invariant criterion:
- **certain invariant clause** (PRD plainly requires X across some surface) → goes to compose gate.
- **ambiguous extent** ("how broadly does X apply?") → residue, not gate. Soundness > coverage.

If the criteria contain BOTH listed enumerations AND invariant clauses, the routing was probably `mixed` — return to design-doc to confirm, then run build-tools on the enumerations first, compose on the invariants second. Both emit into the same `$PROXY_GATE_DIR` (compose appends to the proxy gate file; manifest unions criteria).

### Phase 2 — Surface inference (the load-bearing step)

For each invariant clause, ask: **across what set of values / configurations / kinds must this hold?** The PRD does not list this set. The codebase does.

Read the codebase as follows:

1. **Locate the implementation surface.** Grep for the data structures or functions the invariant operates on. (`is_structure_sensitive_selector`, `SelectorParser`, `Combinator`, `RuleSet::matches`, ...)
2. **Enumerate the existing supported axes** the implementation handles. Each `match` arm, each `if`-chain branch, each enum variant is an axis element.
3. **Catalog the axes** into `surface-matrix.md` with provenance:
   ```
   ## Axis: structural selector kind
   - descendant combinator (` `)  — file.rs:120 match arm
   - child combinator (`>`)  — file.rs:121 match arm
   - adjacent-sibling (`+`)  — file.rs:122 match arm
   - general-sibling (`~`)  — file.rs:123 match arm
   - :first-child  — file.rs:380 match arm
   - :last-child  — file.rs:381 match arm
   - :only-child  — file.rs:382 match arm
   - :nth-child(...)  — file.rs:386 prefix-match arm
   - :nth-last-child(...)  — file.rs:387 prefix-match arm
   - :empty  — file.rs:383 match arm
   ```
4. **Cross-product axes if the invariant ranges over multiple dimensions.** ("preserve matching" ranges over selector-kind × element-position × parent-relationship-after-rewrite.) Trim spurious crossings whose semantics collapse — leave a comment why.
5. **Confidence-mark each axis element** as deduction (the implementation visibly handles it) or abduction (PRD invariant *implies* it should hold but no implementation pin yet). Deduction axes go straight to the gate; abduction axes need an extra sanity check before becoming gate tests.

Failure mode this prevents (F₁₆ oxvg-validated): agent reads PRD's "structure-dependent" cue, infers combinators (`>`, `+`, `~`), stops. Misses structural pseudos (`:first-child`, `:nth-child`, ...) because the PRD never named them — but the codebase's selector engine handles them and the invariant must hold across them too. Codebase reading would have caught all 6 pseudo families.

### Phase 3 — Spurious-axis check (sister to spurious-enumeration)

Before fanning out an axis into N tests, re-read the invariant per axis element. Is every element governed by the *same* invariant mechanic? Or does one element have a sub-case the others lack?

Common spurious-axis patterns:
- **Combinator with functional-pseudo content** (`g:is(.foo + bar)`) — the combinator inside `:is(...)` may need separate handling.
- **Pseudo-class with argument** (`:nth-child(2n+1)` vs `:nth-child(0)`) — the argument's expression may need its own perturbations.
- **Attribute selector with operator** (`[x=y]` vs `[x~=y]` vs `[x^=y]`) — each operator is its own sub-axis.

If non-uniform, expand the axis element into M tests (M ≥ 2), one per mechanic.

### Phase 4 — Build paired control/perturbation tests

For each (invariant-clause, axis-element):

1. **State the invariant clause** in one sentence, PRD-quoted.
2. **Name the axis element** (`:first-child`, `+` combinator, `[attr^=...]`, ...).
3. **Construct the CONTROL input** — a configuration where the invariant *should* hold trivially.
4. **Construct the PERTURBATION input** — the same configuration with one structural change that, if the invariant fails for this axis element, produces a different observable.
5. **Name the plausible-wrong impl** that would distinguish control from perturbation incorrectly. Comment it in the test: `// perturbs: <wrong impl shape>`.
6. **Verify observable difference.** If control and perturbation produce the same observable under the *correct* impl, the test is in the agreement region — change the inputs until they diverge.

Discriminating-test discipline (Hₐ₈) applies per test: a paired test that doesn't distinguish a plausible-wrong impl is dead weight. The pair structure makes mutation thinking explicit — the "perturbation" IS the plausible wrong shape.

### Phase 5 — codex cross-family review (typed-acceptance protocol)

Same as build-tools Phase 4. Codex (gpt-5.5) reviews the design doc + surface-matrix.md + proxy-gate. Three asks:

1. *"Is any current test asserting something the PRD invariant does not plainly entail?"* (soundness)
2. *"For each test pair, is the perturbation actually outside the agreement region of the named plausible-wrong impl?"* (discrimination)
3. *"What surface elements does the codebase support that the surface matrix omits?"* (the question Hₐ₄ was built to ask — the codebase-surface check is the structural complement to build-tools' missing-coverage ask)

Classify every finding with the typed-acceptance table (ENTAILMENT / DISCRIMINATOR / SPECULATION / WRONG) before applying. Re-run soundness on the augmented gate (Phase-4 round-trip from H₁₀).

Skip codex if no internet — note in lessons; the surface-matrix.md artifact is the partial substitute (it's reviewable post-hoc; the operator can ask codex offline against it later).

### Phase 6 — Emit manifest

Write `manifest.json` with the same schema as build-tools (`task_id`, `proxy_gate.{run, path, criteria}`, `probes`, `baseline_cmd`, `baseline_fails`, `verdict_file`). `proxy_gate.run` exits 0 iff the necessary bar passes.

`criteria` IDs should include the axis element so it's traceable: `C3:first-child`, `C3:nth-child`, ... not just `C3`.

## Re-entry (from verify-spec coverage hole)

- Hole + invariant clause is certain + axis element is in surface matrix → add test pair.
- Hole + axis element NOT in surface matrix → **surface inference miss**; re-read Phase 2 source
  for what was missed (you likely stopped at the first level of match arms; deeper enums often
  hide axis elements). Patch the matrix, then add the tests.
- Hole + axis element is in surface matrix BUT no plausible-wrong impl distinguishes it → the
  invariant doesn't actually constrain that element; route to design-doc as a spec ambiguity.

## Notes

The surface-matrix.md artifact is intentionally heavy. It makes surface inference *legible*: the
operator, codex, or a re-entry pass can audit "did we look in the right place?" by reading one
file. Without it, surface inference is invisible and ungrounded — exactly the F₁₆ failure mode on
oxvg (the agent did infer 4 combinators but had no artifact saying "and here are the axes we
considered and excluded," so the missing pseudos weren't even visible as gaps).

The composer's discipline is corpus-grounded once (oxvg, n=2 pseudo mutations missed) and is
predicted to close the largest unbuilt slice of the corpus: oxvg-shaped pure-invariant PRDs
(F₁₂ compositional-dominant tasks where the PRD lacks enumeration).
