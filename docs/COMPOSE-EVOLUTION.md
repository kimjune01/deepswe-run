# How the `compose` skill was born — and what it teaches about skill evolution

A retrospective on `skills/compose/skill.md`: the moment it was needed, the architecture choice, the first measurement, the correction that came from running the verification on the verification, and the methodology pattern that generalizes.

Written 2026-05-29, after the partial-run on Flash + Composer 2.5 surfaced that the same methodology applied at the *task* layer (Hₐ₈ axis-crossing discipline born from a bandit fault) also runs at the *skill* layer.

## The moment

It is 2026-05-27 ~23:59. The feature pipeline (`design-doc → build-tools → implement-spec → verify-spec`) had just been patched with `build-tools`' interface-enumeration sub-phase (Hₐ₂) — write one test per PRD-listed element when the PRD enumerates a flat surface. The discipline had worked on kysely (71% breadth substrate, 6/6 mutants caught) and opa (50% path substrate, 6/6 caught via Phase-4.5 iteration filling Hₐ₂'s gaps).

Now a substrate that should *expose* the discipline's limits: `oxvg-structural-selector-preservation`. F₁₂ classified it 40% compositional; the PRD is five sentences of pure prose, no operators, no method lists, no keywords. The blind subagent ran:

```
Subagent output: 9 criteria (7 certain + 2 routed-to-residue for ambiguity)
8 proxy tests; SOUND + LIVE.
0 per-element tests; 0 spurious-enum splits.
```

The interface-enumeration sub-phase had **correctly stayed silent**. There were no PRD listings to expand. The discriminating-test sub-phase (H₈) carried the gate's design — each test atomized one PRD clause and built paired discriminating inputs against a named plausible-wrong impl.

Discipline-gate behavior: correct. The skill's predicate worked exactly as designed.

Then the targeted ablations against the gate:

| Mutation | Class | Proxy catches? |
|---|---|---|
| M-first-child | structural pseudo | MISSED |
| M-nth-child | structural pseudo | MISSED |

Two structural-pseudo mutations slipped past the gate. The agent's surface inference stopped at four combinator axes (descendant, child, adjacent-sibling, general-sibling) — the things the PRD's word "structure-dependent" cued. It never enumerated the structural pseudos (`:first-child`, `:nth-child`, `:last-child`, `:only-child`, `:nth-last-child`, `:empty`) because the PRD never named them. But oxvg's selector engine in `parcel_selectors/parser.rs` *handles them all*. The invariant must hold across them too.

**The gap shape named the missing discipline.** For invariant-shaped PRDs, the surface is not enumerated in the PRD; it has to be inferred from the codebase's existing supported axes. Hₐ₂ enumerates surfaces the PRD already lists. Whatever fills this gap enumerates surfaces the PRD *implies* via the invariant — by reading the codebase to find every axis the invariant must hold across.

The hypothesis was Hₐ₄: there exists a separable discipline for invariant-shaped PRDs that reads the codebase to infer the surface where the invariant must hold.

## Why a separate skill, not a build-tools sub-phase

The choice was deliberate and recorded:

> Per user direction: composer as a separate skill, not a build-tools sub-phase. Reasoning:
> 1. Load-bearing step is structurally different (codebase surface inference vs PRD listing read).
> 2. Sharing Phase 2 with interface-enumeration risks the prose-overload that codex-sniff caught on Phase 4.

The build-tools file at that moment was already carrying H₁ᵦ + H₇ + H₈ + Hₐ₂ + Hₐ₂″ + adversary protocol — five disciplines layered as prose. Stacking a sixth that *reads the codebase* (vs reading the PRD) would dilute the single-axis cognitive frame each sub-phase needs to fire correctly. The right architectural decomposition: two sibling skills with a routing predicate, monoidally composable.

The naming hesitation is in the lineage too — `compose` because it's a sibling of `build-tools`, not because the skill itself composes things. The skill composes *test pairs across an inferred surface*; the meta-property (skills composable in either order, monoidally) came later as Hₐ₅.

## The routing predicate: from abstract to literal

The discipline needed a trigger. Hₐ₃ in the hypothesis graph said "adaptive routing on PRD shape, not canonical-test class." Concretizing it was a single change to `design-doc/skill.md` Phase 5:

```
FEATURE-SHAPE: enum | invariant | mixed
```

Where:
- `enum` → the PRD lists ≥ 2 named elements somewhere (operators, keywords, methods, variants). Route to **build-tools**.
- `invariant` → the PRD has "preserve / must hold / when X then Y" clauses across surfaces it doesn't enumerate. Route to **compose**.
- `mixed` → both. Route to **build-tools** for the named slice, then **compose** for the inferred slice.

Two important properties:

1. **Observable from PRD alone.** No need to peek at the hidden suite. The predicate is locatable on first read of `instruction.md`.
2. **Not load-bearing on the verdict.** The routing is *advisory*. Each skill's Phase 0 re-classifies on the PRD and self-no-ops on wrong-shape input (the monoidal-identity property). Misrouting is recoverable, not fatal.

The earlier predicate guess — gate routing on F₁₂ canonical-test class — was decisively refuted by `opa-rego-rule-profiling`, which F₁₂ classified path-dominant 50% / breadth 0% but whose PRD is enumeration-rich (17 EvalProfile methods + parallel nil-receiver behaviors). The agent ran Hₐ₂ anyway, caught 6/6 mutants. The discipline-trigger predicate is NOT the canonical-test class. It's the PRD's shape — observable from the agent's own first read.

## The build

`skills/compose/skill.md` was written as a six-phase pipeline. The phases mirror build-tools but pivot on a different load-bearing artifact: `surface-matrix.md`.

```
Phase 0 — Self-classify + convergence read (monoidal contract for LLM skills)
Phase 1 — Triage criteria (certain → gate, ambiguous → residue)
Phase 2 — Surface inference (THE LOAD-BEARING STEP)
Phase 3 — Spurious-axis check (sister to spurious-enumeration)
Phase 4 — Build paired control/perturbation tests
Phase 5 — Cross-family adversary review (typed-acceptance protocol)
Phase 6 — Emit manifest
```

The load-bearing artifact:

> ## Axis: structural selector kind
> - descendant combinator (\` \`) — file.rs:120 match arm
> - child combinator (`>`) — file.rs:121 match arm
> - adjacent-sibling (`+`) — file.rs:122 match arm
> - general-sibling (`~`) — file.rs:123 match arm
> - :first-child — file.rs:380 match arm
> - :last-child — file.rs:381 match arm
> - :only-child — file.rs:382 match arm
> - :nth-child(...) — file.rs:386 prefix-match arm
> - :nth-last-child(...) — file.rs:387 prefix-match arm
> - :empty — file.rs:383 match arm

The matrix is intentionally heavy. It makes surface inference *legible*. The operator, adversary, or a re-entry pass can audit "did we look in the right place?" by reading one file. Without it, surface inference is invisible and ungrounded — exactly the F₁₆ failure mode on oxvg, where the agent did infer four combinators but had no artifact saying "and here are the axes we considered and excluded," so the missing pseudos weren't even visible as gaps.

Each axis element gets a **confidence mark**: deduction (the implementation visibly handles it) or abduction (PRD invariant implies it should hold but no implementation pin yet). Deduction axes go straight to the gate; abduction axes need an extra sanity check before becoming gate tests.

Each test in the gate is **paired**: a CONTROL input where the invariant holds trivially, and a PERTURBATION input where, if the invariant fails for this axis element, a different observable appears. The pair structure makes mutation thinking explicit — the "perturbation" IS the plausible wrong shape. Discriminating-test discipline (H₈) applies per pair: a paired test that doesn't distinguish a plausible-wrong impl is dead weight.

## First measurement: machinery works

F₁₆′ ran the new skill on the originating substrate.

```
First blind compose run on oxvg-structural-selector-preservation:
- FEATURE-SHAPE = invariant (chosen correctly)
- Surface matrix: 6 axes, 28 elements with provenance to
  parcel_selectors-0.28.2/parser.rs (combinators, NthType variants
  including all 11 structural pseudos, functional pseudos, attribute
  operators, external anchor, locality)
- Initial draft: 28 paired tests
- Phase 3 trim: 8 SOUND+LIVE tests
  (agent dropped 20 axes because gold-vs-pre-fix produced behaviorally
  equivalent outputs on those axes)
```

The agent inferred a 28-element surface from one file in the codebase, then trimmed 20 axes whose semantics produced behaviorally-equivalent gold-vs-pre-fix outputs. Phase 3's spurious-axis check fired correctly.

Then the gate against the originating mutants:

| Mutation | Compose proxy catches? |
|---|---|
| M-first-child | MISSED |
| M-nth-child | MISSED |

The same two mutations the build-tools gate missed. First reading: "compose's Phase 3 trimmed too aggressively." Hₐ₄'s case looked broken.

## The correction: experimenter's H₈

Before recording the case as broken, a verification step nobody had thought to run on the original gap claim:

> Run the candidate mutations against the canonical suite first.

Result: canonical (10 hidden tests) also passes both mutations 10/10. The "mutations" don't observably change canonical behavior. Gold's `is_structure_sensitive_selector` isn't reached by canonical's selector shapes. The mutations are **inert at the canonical level**.

That changes everything. The compose gate's "miss" wasn't a coverage gap — there was nothing to catch. Phase 3's trim was correct soundness logic. The original "Hₐ₄ gap on oxvg" was a phantom; the mutations were inert from the start; nobody had verified.

This is the **experimenter's H₈** — the same discrimination-on-the-experiment-itself the discipline asks the agent to apply to its tests, now caught at the meta-layer. The discipline says: *for each test, name the plausible-wrong impl and ensure inputs distinguish it.* The corresponding meta-rule: *for each ablation, ensure the mutation observably changes canonical behavior on the canonical suite, not just on a hand-built test.*

This was the second occurrence in the session. The first was opa M4 (`HotRules []` instead of `nil`) which was a no-op in Go's nil-slice semantics. Both times the "gap" wasn't real because the mutation wasn't observable. Both times the verification on the verification caught it.

What was preserved after the correction:

- Compose machinery confidence: **~82** (skill produces structurally correct surface-matrix.md + manifest + paired tests + SOUND+LIVE gate on first try, on a representative invariant-shape PRD)
- Compose case confidence: **~30** (the oxvg gap claimed previously was inert mutations; the composer is built but its load-bearing necessity hasn't been earned on this substrate)

The honest residue: *machinery built, case unfound*. Don't overclaim. Hₐ₄'s evidence base must be re-found on a task where invariant-axis mutations are actually canonical-load-bearing. oxvg is not that task.

## The monoidal contract (Hₐ₅)

A few hours after compose was built, an audit pass tightened the skill family into a monoidal contract:

```
build-tools ∘ compose ≈ compose ∘ build-tools   (on mixed-shape inputs)
compose ∘ compose ≈ compose                       (idempotent re-run)
build-tools ∘ build-tools ≈ build-tools           (idempotent re-run)
On wrong-shape input: identity (clean no-op)
```

Each skill gained a **Phase 0 self-classify**:

> Sniff rule (symmetric across skills):
> - enum-count = PRD listings of ≥ 2 named elements.
> - invariant-count = PRD "preserve / must hold / when X then Y" clauses across unstated surfaces.
> - applies if invariant-count ≥ 1 AND enum-count = 0.
> - partially-applies if both > 0.
> - does-not-apply if invariant-count = 0.

Each skill's emit phase rewrote from "write manifest" to "merge manifest" — detect the other skill's slice via `*.applied: true` and merge into a shared `proxy_gate.criteria` list. The manifest schema gained two slices (`build_tools` and `compose`) plus a union `proxy_gate` that downstream tooling (`dsr gate`, `dsr isolate`) reads agnostically.

The motivation: the original session had operator-level routing (RUNBOOK + design-doc hint) and skills that couldn't be composed safely. Running compose on an enum PRD would produce noise; running build-tools on an invariant PRD would silently under-discriminate (the oxvg pattern). The monoidal contract makes the pipeline composable — dispatch both in either order, get the same manifest. The first skill applies its slice and writes its slice key; the second skill applies its slice and merges; redundant runs no-op.

The audit covered every skill in the pipeline:

| Skill | Identity | Idempotency | Merge | Patches applied |
|---|---|---|---|---|
| design-doc | violates | partial | violates | Phase 0 identity via PRD sha256; emit tags; graph append dedupe |
| build-tools | prose-only | prose-only | violates | manifest schema with slices; Phase 0 + Phase 5 read-merge-write |
| compose | prose-only | prose-only | prose-only | manifest schema reference; Phase 0 + Phase 6 read-merge-write |
| implement-spec | violates | implicit | n/a | Phase 0 identity: if green on entry, exit clean |
| verify-spec | honors | honors | n/a | no change |

Notable: the asserted contract was — and remains — *not measured*. Hₐ₅ is open. The first task in the corpus that's plausibly `mixed`-shape is httpx. A clean test would dispatch build-tools then compose on a fresh httpx run, then re-dispatch compose then build-tools on a parallel fresh run, and verify the two manifests are equivalent up to ordering. The contract is written; it is not yet earned.

This is exactly the same shape as the experimenter's H₈ correction: writing "monoidal" in skill prose doesn't make the implementation behave that way. A skill that says "merge" but actually overwrites would silently violate the contract; only an end-to-end double-dispatch test catches it. The corpus-validated machinery confidence is *prose-only* until a measurement.

## What the compose skill currently knows about itself

Current HG state:

```
Hₐ₄ composer discipline for no-enum PRDs
    ENCODED · monoidal — skills/compose/ + build-tools self-classify in
    Phase 0; safe to compose in either order; identity on wrong-shape inputs
    open · machinery built; case unfound
    machinery: 82 (skill written + monoidal contract added)
    case for needing it: 30 — original oxvg "gap" refuted by canonical also
    passing the mutations 10/10
```

The skill exists. It runs. Its first measured run produced a structurally correct artifact pipeline. Its claimed-originating gap turned out to be a phantom from un-verified ablations. Its monoidal contract is asserted in prose, not verified by double-dispatch. **The skill is built but it has not yet earned the right to exist on the corpus.**

That residue is in the graph, in the lessons log, in the worklog. It is not in the README. The discipline is to keep the gap visible — to not let "the skill exists" silently become "the skill is necessary" without measurement.

## The methodology pattern (what generalizes)

The compose skill's story is one instantiation of a pattern that recurs across this project. Naming it:

### 1. Failure-driven skill genesis

A skill is born from a *specific named failure mode* on a specific substrate, not from architectural foresight. The originating failure carries the discipline's name (Hₐ₄ from F₁₆'s "no-list invariant surface inference"). The genesis is recorded in the hypothesis graph before the skill file is written. If the genesis can't be stated as a specific failure, the skill probably shouldn't be built — the discipline doesn't have a measurable trigger yet.

### 2. Architectural choice is decision-recorded

"Should this be a separate skill or a sub-phase?" is a decision made *with rationale*, recorded in the lessons log, with the falsifiable claim ("the load-bearing step is structurally different from the sibling skill's load-bearing step"). The rationale is referenceable later; if the architecture is wrong, the recorded reason narrows what to revise.

### 3. Routing predicate is observable from the agent's own first read

Skills that fire conditionally need their trigger to be locatable without privileged access. Hₐ₃'s concretization — `FEATURE-SHAPE: enum | invariant | mixed` from a single PRD read — moves the routing predicate out of "operator decides" into "agent self-classifies." The agent can't see the canonical test class; it CAN see the PRD's shape. Build the predicate on what the agent can see.

### 4. Routing is advisory; self-classify is load-bearing

Each skill's Phase 0 re-classifies on the PRD and self-no-ops on wrong-shape input. The routing hint from the upstream skill is a suggestion, not a contract. The monoidal-identity property — "on wrong-shape input, exit clean without editing" — makes misrouting recoverable. The cost of a wrong route is a no-op, not a corrupted manifest.

### 5. Load-bearing artifact ≠ load-bearing skill

The artifact that makes the skill's work *legible* is its load-bearing component. For compose: `surface-matrix.md`. The test file is the output; the surface matrix is the receipt. Without the receipt, surface inference is invisible and ungrounded — which is exactly what failed on F₁₆. The discipline's auditability depends on the receipt artifact, not the test file.

### 6. First measurement on the originating substrate

The first blind run goes on the substrate that named the discipline. It either confirms the gap-the-skill-was-built-to-close, or it doesn't. The confirmation/refutation must distinguish *machinery soundness* from *case necessity*. A skill can produce structurally correct output on a substrate where it wasn't needed.

### 7. The verification on the verification

Before recording a gap as real, run the candidate mutation against the canonical suite. If canonical passes too, the mutation is inert and the gap is illusory. This is the experimenter's H₈, applied at the meta-layer to ablation experiments. It costs ~30 seconds per ablation; it has caught two phantom gaps in this project (opa M4, oxvg pseudos).

### 8. Honest residue beats overclaimed confidence

Split confidence into machinery and case. Machinery confidence is what the skill produces structurally; case confidence is whether the substrate proved the skill was necessary. Compose currently sits at machinery-82 / case-30. The case-30 is *load-bearing for the project's honesty* — without it, "we built compose" silently becomes "we proved compose is necessary," which the evidence doesn't yet support.

### 9. Contract assertions are prose-only until measured

Hₐ₅'s monoidal contract is in skill prose. It is not yet verified. Writing "monoidal" doesn't make the implementation behave that way; a `merge` that actually overwrites is silent until an end-to-end double-dispatch test runs. Same shape as the experimenter's H₈ at the experimenter layer: don't trust your own claim about your own skill until you've run the measurement that would falsify it.

### 10. The skill is published as built + as not-yet-earned

The deliverable is the skill *plus* its honest residue. Compose ships with: a 184-line skill file, a monoidal contract spec, a confidence split (82 machinery / 30 case), an explicit "case for needing it: 30 — original oxvg gap refuted by canonical also passing the mutations 10/10," and a named open frontier (find a substrate where invariant-axis mutations are canonical-load-bearing). A reader who would otherwise overclaim from "skill exists" is corrected by the graph's own self-report.

## What this teaches about the partial-run work

The partial-run on Flash + Composer 2.5 (kysely + bandit + happy-dom) produced a parallel instance of the same pattern at the *task* layer:

- **Failure-driven skill genesis:** Hₐ₈ axis-crossing discipline born from bandit's 96.2% grade-pass on cross-axis tests like `all & B602`.
- **Architectural choice recorded:** added as a sub-phase in build-tools Phase 2, not a separate skill (the load-bearing step — enumerating rule pairs — is the same shape as Hₐ₂'s PRD-listing read).
- **First measurement on the originating substrate:** Composer-as-build-tools w/ patched skill produced 51 tests including 6 axis-crossing tests, 2 of which caught the same Composer impl bugs that the hidden suite caught.
- **Verification on the verification:** ran the patched gate against patched impl, found 7 of 9 fail-on-original tests were SPECULATION (oracle agrees the patched impl is correct, so those tests catch non-bugs).
- **Honest residue:** Hₐ₉ named (discipline needs negative-clause filtering); Hₐ₁₀ named (procedural disciplines converge slowly; full speculation elimination via prose alone is infeasible).
- **Cross-substrate verification:** Hₐ₈ structurally transfers to happy-dom (additive feature class, TypeScript, short PRD) at n=2 — same discipline produces the body-type × shutdown-trigger matrix.

The same pattern applies at both layers — the per-task discipline iteration and the per-skill architectural decomposition both run on hypothesis-graph + receipt-artifact + verification-on-verification + honest-residue.

## Closing

The compose skill is, as of this writing, a worked example of the methodology more than of itself. Its machinery is sound. Its case is honestly unfound. Its monoidal contract is asserted, not measured. Its existence-in-the-pipeline is the residue of a hypothesis registered, a discipline built, a first measurement run, a phantom gap caught at the meta-layer, and a refusal to overclaim despite the architectural work being done.

If a future operator finds a substrate where invariant-axis mutations are canonical-load-bearing — where the codebase supports an axis the PRD never names AND the hidden test actually exercises that axis — compose's case confidence will move from 30 to evidence. Until then, the residue stays in the graph and the README stays quiet.

The methodology's promise is that the project's confidence is bounded by what's been measured, not by what's been written. Compose is the cleanest example because its case-vs-machinery split is widest. Every other skill in `skills/` should be readable through the same lens: what's the machinery confidence, what's the case confidence, where's the evidence, what's the open frontier.

## Provenance

- Originating failure: `harness/feature/build-tools-lessons.md` 2026-05-27 23:59 (oxvg run, "F₁₆ honest negative")
- Skill build: `harness/feature/build-tools-lessons.md` 2026-05-28 (F₁₆′ entry: skill encoded, monoidal added)
- Skill file: `skills/compose/skill.md`
- HG state: `harness/feature/HYPOTHESIS_GRAPH.md` (Hₐ₄ row)
- Routing predicate: `skills/design-doc/skill.md` Phase 5 (FEATURE-SHAPE line) + `skills/build-tools/skill.md` Phase 0 + `skills/compose/skill.md` Phase 0
- Monoidal contract audit: `harness/feature/build-tools-lessons.md` (Hₐ₅ audit entry)
- Same pattern at task layer this session: `harness/feature/run/bandit-structured-nosec-directives/partial-v1/RESULT.md` + `AUTOMATED-HARNESS-VERIFICATION.md` + `A-PRIME-FIX-RESULT.md`
