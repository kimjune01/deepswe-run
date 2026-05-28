---
name: build-tools
description: Tooling phase for feature-request (PRD-shaped) tasks (DeepSWE / Harbor). Sits between design-doc and implement-spec. From design-doc's acceptance criteria (SPEC ONLY — hidden grader never consulted), emit a proxy gate (criteria as runnable tests), standalone CLI dev probes (ground-truth oracles for load-bearing deterministic distinctions), and a manifest the post-verify deterministic gate consumes. The proxy gate is a NECESSARY-not-sufficient bar built from high-certainty constraints only.
argument-hint: <task-id>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Build-tools: encode the spec into a deterministic shell

Take the design doc's *certain* acceptance criteria and convert them into deterministic tools the implementer runs. Every distinction that reduces to a deterministic check leaves the prompt and becomes a tool; the residue is implement-spec's LLM judgment.

## Rules (read first)

- **Spec only.** Hidden grader is never read. Peeking is contamination.
- **Necessary, not sufficient.** Failing the proxy ⟹ failing the grade (sound lower bound). Passing the proxy ≠ certified grade pass.
- **Soundness over coverage.** A wrong test (failing a correct implementation) is worse than a missing one. Encode only constraints you'd bet on.
- **Ambiguity → residue, not gate.** Speculative behaviors stay with design-doc alternatives + implement-spec LLM. Never as a proxy test.
- **You will not reproduce the hidden grader.** Pinned behaviors the PRD never states (exact errors, byte-level framing) are ~0% reachable from spec alone. The proxy-vs-grade gap IS the measurement. Build the soundest necessary bar the certain constraints allow; leave the gap visible.
- **Probes are reference oracles, not the feature.** One deterministic distinction each. If the probe *is* the implementation, skip it — nothing to encode.

## Environment

- Repo in offline Docker container; reach via the adapter helper (`box-sh '<cmd>'`); already `cd`s to repo root.
- Write artifacts to `$PROXY_GATE_DIR` (fixed scratch path outside tracked tree; persists for downstream skills; driver excludes from diff).
- `codex` runs locally, not in the container.

## Output (three artifacts at `$PROXY_GATE_DIR`)

1. **Proxy gate** — acceptance criteria as runnable tests in the repo's framework, one test per *certain* criterion. Must fail now (feature absent) for the right reason.
2. **Dev probes** — small standalone CLI tools, one per load-bearing deterministic distinction the implementer would otherwise guess.
3. **Manifest** (`$PROXY_GATE_DIR/manifest.json`) — the `dsr gate` contract. **Schema reflects the monoidal contract** — build-tools and compose each write into their own slice; `proxy_gate.run` runs both slices in sequence; criteria union:

```json
{
  "task_id":          "<id>",
  "feature_shape":    "enum | invariant | mixed",
  "build_tools": {
    "applied":        true,
    "path":           "<test file path written by build-tools>",
    "criteria":       ["C1", "C2", "..."],
    "run":            "<cmd that runs build-tools' tests, exits 0 iff all pass>"
  },
  "compose": {
    "applied":        false,                       // true once compose runs
    "path":           "<test file path written by compose>",
    "criteria":       ["I1:axis-element", "..."],  // axis-tagged
    "run":            "<cmd that runs compose's tests>",
    "surface_matrix": "<path to surface-matrix.md>"
  },
  "proxy_gate": {                                  // the union — what dsr gate / dsr isolate actually run
    "run":            "<build_tools.run> && <compose.run>",  // shell && when both applied; just the applied one otherwise
    "path":           "<both paths if both applied; else the one>",
    "criteria":       ["<union of build_tools.criteria and compose.criteria>"]
  },
  "probes": [
    { "name": "<id>", "run": "<cmd>", "does": "<one line>" }
  ],
  "baseline_cmd":    "<project's existing suite (regressions)>",
  "baseline_fails":  ["<tests already red on clean base, copied from $BASELINE_FAILS file>"],
  "verdict_file":    "<path verify-spec writes>"
}
```

The `build_tools` and `compose` blocks are the slices; `proxy_gate` is their union, refreshed on every emit. `dsr gate` / `dsr isolate` read only `proxy_gate.run` — they don't need to know which slice is which.

Append nodes to the hypothesis graph (never truncate).

## Process

### Phase 0 — Self-classify (monoidal contract)

**Don't trust design-doc's FEATURE-SHAPE blindly.** Read the PRD yourself and classify:

| Self-classification | Action |
|---|---|
| **applies** — PRD enumerates ≥ 2 surface elements (methods, operators, keywords, formats, variants) | proceed to Phase 1 |
| **partially-applies** — PRD has both listed enumerations AND invariant clauses across unstated surfaces | proceed but write *only* the enumeration slice; leave invariant slice to compose |
| **does-not-apply** — PRD is pure invariant / compositional rule with no listed surface | **no-op identity**: emit a manifest stub with `build_tools.applied: false` and empty `build_tools.criteria: []`, do not touch the proxy gate file, exit clean. Operator may have routed wrong; recoverable. |

Sniff rule (mirror of compose's):
- `enum-count` = PRD listings of ≥ 2 named elements (operators, methods, keywords, formats).
- `invariant-count` = PRD "preserve / must hold / when X then Y" clauses across unstated surfaces.
- `applies` if enum-count ≥ 1 AND invariant-count = 0.
- `partially-applies` if both > 0.
- `does-not-apply` if enum-count = 0.

**Idempotency.** Phase 5's manifest emit is a *read-merge-write*, not an overwrite:
- Read existing `manifest.json` if any.
- If `build_tools.applied == true`: exit clean (identity on re-invocation).
- Else: write the `build_tools` slice; preserve any existing `compose` slice; recompute `proxy_gate.{run,path,criteria}` as the union of the two slices (`<build_tools.run> && <compose.run>` when both applied, single side otherwise; `path` becomes a comma-joined list or the single path; `criteria` is the union with axis-tag preservation).
- Write back.

The contract: `build-tools` ∘ `compose` = `compose` ∘ `build-tools` (commutes on `mixed`), and `build-tools` ∘ `build-tools` = `build-tools` (idempotent).

### Phase 1 — Triage criteria by certainty
Per design-doc criterion: **certain** (PRD plain) → proxy gate · **ambiguous** (design-doc flagged) → residue. Gate built from certain set only.

### Phase 2 — Build the proxy gate
- One test per certain criterion at `$PROXY_GATE_DIR`, in the repo's test framework.
- Use the criterion's stated check (input → expected output / message).
- Run them; confirm they FAIL because the feature is absent. A test green pre-implementation is mis-written or the criterion is already satisfied — investigate.
- Cover only the *certain* edge cases / error messages / precedence rules; each as its own test.

#### Interface-enumeration discipline (MANDATORY when criterion lists ≥ 2 surface elements)

A criterion that names a flat enumeration (operators / keywords / method variants / separator
characters / accessor names / modifier set) is **not one criterion** — it is N criteria, one per
element. The corpus's largest miss class (Hₐ₂; F₁₂ ~41% weighted) is exactly this: agents condense
an enumeration into a single "supports the surface" test and miss per-element behavior.

For each certain criterion whose statement enumerates a set:
1. List every element the PRD names (operators, method names, keywords, characters — whatever the
   enumeration unit is). Count = N.
2. **Spurious-enumeration check (MANDATORY before fanning out).** Re-read the PRD per element.
   Is every element governed by the *same shape* of rule? Or does the PRD describe one of them
   as a tri-state ladder / multi-clause case-split / nil-receiver-special-case where the others
   are single-clause? If non-uniform: that element is **not one test**, it's M (M ≥ 2), one per
   PRD-listed case. Common spurious-enumeration patterns:
   - Identity/equality methods that distinguish nil-vs-nil, nil-vs-non-nil, structural cases.
   - Merge/combine methods where both-nil, one-nil, both-non-nil are separately stated.
   - Methods whose nil-receiver behavior is enumerated separately from their non-nil behavior.
   - "Pattern X also accepts Y" elements that re-enter the discrimination axis.
3. Write **N tests** (or N+extras for non-uniform elements), one per element-case, each PRD-quoting
   the listing it came from.
4. If two elements are claimed to compose (e.g. "starters complete with andX/andY"), the cross
   product is *also* an enumeration — write tests across the cross product unless the PRD
   plainly says they share semantics.
5. If an element's behavior is ambiguous from the PRD alone, route it to residue, not the gate
   (a per-element test still beats one bundled test).

Failure mode this prevents (F₁₂ corpus-validated): one test "supports `eb.fn.rowNumber/rank/denseRank/
percentRank/cumeDist/ntile`" — passes on an implementation that wires only `rowNumber`. The other
five never run. Six per-element tests force the agent to confront each element.

A bundled "matrix" test (one input exercising many elements at once) is in the agreement region of
"all work" and "only N-1 work." Per-element is the discriminating shape.

#### Discriminating-test discipline (MANDATORY per test)
For each test, before saving:
1. State the criterion's rule in one sentence.
2. Name one plausible-but-wrong implementation that satisfies the criterion's *name* but violates its rule. (Comment it in the test source: `# discriminates: <wrong impl>`.)
3. Verify your test inputs make the wrong impl produce a *different observable* than the correct impl. If they don't, change the inputs — your test is in the *agreement region*.
4. For compositional/nested rules: components must differ (different specific selectors, distinct content); identical-blanket inputs are agreement-region by definition.

### Phase 3 — Build dev probes
For each deterministic distinction the implementer will hit repeatedly, write a CLI probe returning ground-truth. Keep to one distinction each.

### Phase 4 — codex cross-family review (typed-acceptance protocol)

Codex (gpt-5.5; different model family) catches structural gaps same-model iteration + mutation-thinking miss. But codex also over-suggests AND can be wrong about rule direction. Treat its output as raw findings to be **typed**, not advice to apply.

**Step 1 — Send the volley.** PRD + design doc + proxy-gate file. Three asks:

1. *"Is any current test asserting something the PRD does not plainly require?"* (soundness)
2. *"For each test, name a plausible-but-wrong implementation that satisfies the test's name but violates the rule; if current inputs would NOT detect it, give the input shape that would."* (discrimination)
3. *"Which compositional behaviors stated or implied by the PRD are NOT exercised by the test suite?"* (missing coverage)

**Step 2 — Classify every finding by type** (the load-bearing step — codex's findings are evidence, not edits):

| Type | Definition | Action |
|---|---|---|
| **ENTAILMENT** | the rule is plainly stated or directly entailed by the PRD | add or strengthen the test |
| **DISCRIMINATOR** | the rule is already in the gate but the test's inputs don't distinguish it from a plausible mutant | swap the inputs only; don't add a new criterion |
| **SPECULATION** | the rule is plausible but the PRD is silent / ambiguous on it | residue, NOT gate; document the ambiguity |
| **WRONG** | codex got the direction reversed or misread the PRD | drop; log the misread (cross-family is not infallible) |

For each codex finding, write the type next to it in your working notes BEFORE editing the gate. Tests get added/swapped only for ENTAILMENT and DISCRIMINATOR. Never apply a finding that you haven't typed.

**Step 3 — Soundness gate on the augmented set.** After edits, walk every test once more (original + applied) and ask: *"does the PRD plainly require this?"* If silent/ambiguous → residue.

**Stop condition:** no test in the gate without a PRD-quote justification ("PRD: <quoted clause>") in its source comment.

Failure mode this protocol prevents (F₉ corpus-validated): codex finding #3 + #7 were SPECULATION but applied as ENTAILMENT → gate ended UNSOUND on gold (gold-failing tests). Typing first would have routed them to residue. Codex finding #13 was WRONG (reversed metric direction); the agent caught it ad-hoc — the typing step makes such catches part of the protocol, not luck.

### Phase 5 — Emit manifest
Write `manifest.json` to the schema above. `proxy_gate.run` exits 0 iff the necessary bar passes. `baseline_fails` is copied from the adapter's clean-base capture file.

## Re-entry (from verify-spec coverage hole)
- Coverage hole + criterion is **certain** → add test to proxy gate.
- Coverage hole + criterion turns out **ambiguous** → route to design-doc (spec gap, not tooling gap). Never widen the bar with a test you can't defend.

## Notes
The discriminating-test discipline (Phase 2 step inside the gate) is corpus-validated (HYPOTHESIS_GRAPH.md H₈). Enumerating a compositional criterion ≠ writing a test that discriminates the rule's violation — the test inputs must lie *outside* the agreement region of the rule and its plausible mutants.
