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
- The adversary CLI (default `gemini`; see `$DSR_ADVERSARY_MODEL`) runs locally, not in the container.

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

### Phase 0 — Self-classify + convergence read (monoidal contract for LLM skills)

LLM output is not bit-stable. The contract isn't strict idempotency but **convergence under iteration** (cf. `/humanize`): each pass narrows the diff against the fixed point; the dampener is acting only on what's still inconsistent, leaving stable parts alone.

**Self-classify on the PRD shape** (don't trust design-doc's FEATURE-SHAPE blindly):

| Shape | Action |
|---|---|
| **applies** — PRD enumerates ≥ 2 surface elements (methods, operators, keywords, formats, variants) | proceed to Phase 1 |
| **partially-applies** — PRD has both listed enumerations AND invariant clauses across unstated surfaces | proceed but write *only* the enumeration slice; leave invariant slice to compose |
| **does-not-apply** — PRD is pure invariant / compositional rule with no listed surface | **identity stub**: write `build_tools.applied: false`, empty `build_tools.criteria: []`; do not touch the proxy gate file; exit. Recoverable misroute. |

Sniff rule (mirror of compose's):
- `enum-count` = PRD listings of ≥ 2 named elements.
- `invariant-count` = PRD "preserve / must hold / when X then Y" clauses across unstated surfaces.
- `applies` if enum-count ≥ 1 AND invariant-count = 0.
- `partially-applies` if both > 0.
- `does-not-apply` if enum-count = 0.

**Convergence read** (handles the LLM-nondeterminism gap):

1. Read existing `manifest.json` if any. If `build_tools.applied == true`:
   - Read each existing test in `build_tools.path` and check its PRD-quote against the current PRD. **Keep tests whose PRD-quote still matches a current PRD clause.** Don't regenerate them.
   - For each kept test, run the discriminating-test check (Phase 2 sub-discipline) once. If the inputs still discriminate against the named plausible-wrong impl, the test is *stable* — no edit.
   - Only ADD tests for PRD criteria not yet covered, and only REMOVE tests that now fail soundness on gold (verify-spec kill report) or that you now type as SPECULATION.
   - Report a `// CONVERGENCE: kept N, added M, removed K` line in the test file header. If `M + K == 0`, this run was a no-op (fixed point reached).
2. If `build_tools.applied != true`: full build as Phase 1+.

This is the dampener: M and K shrink monotonically across runs on the same PRD; after ~2 passes the gate is at fixed point. A re-run on a stable gate emits the header `CONVERGENCE: kept N, added 0, removed 0` and exits without touching tests.

**Manifest merge** (Phase 5 detail, restated here for completeness): read-merge-write; preserve `compose`'s slice; recompute `proxy_gate.{run,path,criteria}` as the union.

The contract: `build-tools ∘ compose ≈ compose ∘ build-tools` on `mixed` (manifests converge to the same fixed point in 1–2 iterations of either order). `build-tools ∘ build-tools ≈ build-tools` (re-run shrinks to zero edits). Identity on wrong-shape input (clean stub).

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

#### Boundary-clause discipline (MANDATORY per test — soundness filter)

The discriminating step (above) catches "my test fails to distinguish wrong impls." The boundary step
catches its dual: "my test asserts a stronger thing than the PRD entails." Both are required.

Hₐ₉ corpus-validated on bandit (2026-05-28, a-prime fire): the Hₐ₈ discipline produced 51 tests
when dispatched to Composer-as-build-tools, but 7 of 9 fails-on-original-impl were SPECULATION
(asserting outcomes the PRD does not require, often because input noise leaked unaccounted-for
observables into the assertion). Example: a test for `nosec-begin all` asserted "all issues
suppressed," but `import subprocess` on line 1 reports B404 BEFORE the region starts — the PRD's
region scope is bounded by lineno after the directive, not the whole file. The test was caught
by oracle-graded patched impl, not by the discipline itself.

For each test, before saving:

1. **POSITIVE clause** — quote the PRD clause(s) the test exercises. (Already required by axis-
   crossing's step 5; now mandatory for every test.) Format: `# PRD+: "<exact quote>"`.
2. **NEGATIVE clause** — quote the *boundary* the PRD places on this rule: what the rule does
   NOT extend to. The boundary is usually a scope qualifier, a precondition, or an explicit
   exception in the PRD. Format: `# PRD-: <what the rule does not cover>`. If no boundary is
   stated in the PRD, write `# PRD-: (no stated boundary; assertion must not exceed what the
   positive clause literally entails)`.
3. **Assertion-vs-boundary check.** Re-read your assertion against the negative clause. Does the
   assertion claim something *outside* the positive clause's scope? If yes, the assertion is
   speculation — narrow it. Common speculation patterns:
   - Asserting `len(issues) == 0` when the input has findings the PRD doesn't require suppressed
     (e.g. test for "region suppression" but input has an issue on a line before the region).
   - Asserting an exact set / list when the PRD only constrains a subset / a count.
   - Asserting a metric counter goes to *exactly* N when PRD only says it "increments" or "is
     at least N."
4. **Input-noise audit.** List every observable your input produces (every line that bandit
   might report, every state transition, every counter increment). For each observable, check
   whether the PRD entails what your assertion says about it. Observables you don't have a
   POSITIVE clause for must be either (a) explicitly excluded by your input setup (e.g., suppress
   them inline with `# nosec`) or (b) excluded from the assertion (assert subsets, not equality).

Failure mode this prevents (a-prime corpus-validated, 2026-05-28): Composer-as-build-tools wrote
`test_selector_all_token_is_blanket` with the assertion `self.assertEqual(ids(issues), set())`.
The PRD positive clause is "The special token `all` also suppresses all tests." The PRD's
negative clause (implicit but locatable): region scope starts on the line after the directive
("the begin takes effect starting on the next line"). With negative clause in hand, the author
must reason: line 1's `import subprocess` is BEFORE the region; B404 from it is OUTSIDE the
positive clause's scope. The correct assertion is `B404` is *the only remaining issue*, not
`set()` is empty. The boundary clause discipline catches this before the test ships.

The boundary clause is **MORE LOAD-BEARING than the discriminator** for soundness. The
discriminator filters tests that don't catch bugs. The boundary clause filters tests that catch
non-bugs.

#### Axis-crossing discipline (MANDATORY when ≥ 2 rules' preconditions intersect)

Single-axis discrimination catches "test the rule on agreement-region inputs" failures. Axis-crossing
discrimination catches a **structurally different** failure: an impl that handles each rule correctly
*in isolation* but collapses two rules' values onto the same sentinel/scope when they intersect.

Hₐ₈ corpus-validated on bandit (2026-05-28): Composer's impl passed every per-axis proxy test
(`all` token alone, simple intersection, top-level dedent) but failed the oracle on cross-axis
inputs (`all & B602` collapsed to blanket sentinel; `nosec-begin` inside multi-line `Popen()` call
hit auto-end-on-dedent because the closing `)` looked like a real dedent). Both failures shared a
shape: **"single-axis rule applied at the wrong scope, ignoring a cross-axis condition."**

For any PRD with two or more rules whose precondition surfaces overlap:

1. **Enumerate rule pairs.** List each pair of rules whose precondition surface elements could
   co-occur in a single input. For bandit-style selector grammar: (single-token, operator) pairs —
   `all` × `&`, `all` × `-`, glob × `&`. For region-style scopes: (indent rule, container scope)
   pairs — auto-end-on-dedent × inside-open-bracket, region-begin × multi-line-statement.
2. **Construct a cross-axis input per pair.** Build a test whose input puts BOTH rules into effect
   simultaneously. The test asserts the resolved-from-both-rules observable, not either rule alone.
3. **Sentinel-collision check.** If either rule produces a value (`set()`, `None`, an empty list,
   a default value) that the implementer might use as a sentinel for *something else* (a top-level
   "blanket" signal, a "no-op" signal, an "uninitialized" signal), write a cross-axis test that
   forces the algebraic value to *equal* the sentinel via a *non-sentinel path*. (Example: `all & X`
   produces `enabled_set ∩ {X} = {X}` — non-empty — but a naive impl that resolves `all` to the
   blanket sentinel `set()` gets `set() & {X} = set()` ≡ blanket. The test asserts `{X}`, not
   blanket.)
4. **Scope-boundary check.** If a rule has an implicit scope (top-level vs nested, outside-brackets
   vs inside-brackets, file-level vs statement-level), write a cross-axis test that places one
   rule's preconditions *inside* another rule's scope where the impl might still apply the outer
   rule. (Example: `# nosec-begin` directive on an indented continuation line of a multi-line
   call; the closing `)` looks like a dedent, but it's structural and the region must persist past
   it.)
5. **PRD quote each cross-axis test.** Quote both rules' clauses in the test source: `# crosses
   PRD: <rule A clause> × <rule B clause>`. This forces you to confirm the PRD actually entails
   the crossing's outcome before locking the test.

Failure mode this prevents (bandit corpus-validated, 2026-05-28): Composer's bandit impl had ZERO
cross-axis proxy tests despite the PRD enumerating selector grammar (5 operators) AND region
auto-end semantics in the same feature. Single-axis tests existed for every individual rule. The
oracle had cross-axis tests (`all & B602` → expect `{B602}`; `nosec-begin` inside multi-line call
→ expect region applies past close-paren). Composer impl passed proxy 30/30, failed oracle 3/78,
hand-patched 13-line fix closed all 3. **The fault was the missing cross-axis tests at proxy-author
time, not the impl.**

A cross-axis test that asserts the *correct* observable distinguishes "impl handles each rule" from
"impl handles their interaction." Adding cross-axis tests forces the implementer to confront
sentinel-collision and scope-boundary at proxy-author time, not at oracle-grading time.

### Phase 3 — Build dev probes
For each deterministic distinction the implementer will hit repeatedly, write a CLI probe returning ground-truth. Keep to one distinction each.

### Phase 3.5 — Cross-family adversary review on the gate alone (typed-acceptance, residue-carrying)

**Added 2026-05-29 per transfer-risk-v1 PHASE-2-BIS analysis** — catches a measured ~1/3 of impl-bug-causing axis-crossings *before any impl tokens are spent*. Same protocol as Phase 4 below, applied at proxy-author time (no impl exists yet), with one structural change: SPECULATION findings are **carried forward to Phase 4 in `$PROXY_GATE_DIR/RESIDUE.md`** rather than dropped.

Why carry forward: Hₐ₁₀ is operationally confirmed — a finding's type can change across phases. A SPECULATION at proxy-author time ("PRD is silent on `all` inside an intersection expression") can become an ENTAILMENT at impl-review time when the impl gives the speculation a concrete shape ("Composer's impl resolves `all & B602` to `{B602}` but counts it as `nosec` — the PRD's classify-by-resolved-set rule plainly applies").

**Step 1 — Send the volley to BOTH adversaries (dual-adversary protocol).** Inputs: PRD + design doc + proxy-gate file (NO impl, NO captured diff). Two adversaries, fired in parallel on identical input:
- **`$DSR_ADVERSARY_MODEL`** (default `gemini-3.5-flash`) — the **soundness lens**. Measured on bandit 2026-05-29: catches 2/2 known soundness bugs at ~$0/call, low-verbosity 14 findings.
- **`$DSR_ADVERSARY_BREADTH_MODEL`** (default `composer-2.5` via `cursor-agent -p -f --model composer-2.5`) — the **breadth lens**. Measured on same bandit artifact: surfaces 19 unique missing-coverage gaps Flash misses, ~$0.05/call.

Three asks to each (same prompt skeleton at `harness/feature/run/<task>/review-prompt.md` if present, else inline):

1. *"Is any current test asserting something the PRD does not plainly require?"* (soundness)
2. *"For each test, name a plausible-but-wrong implementation that satisfies the test's name but violates the rule; if current inputs would NOT detect it, give the input shape that would."* (discrimination)
3. *"Which compositional behaviors stated or implied by the PRD are NOT exercised by the test suite?"* (missing coverage)

Why dual: substantive overlap between the two lenses measured at 37.9% (`transfer-risk-v1/PAIRING.md`) → 62% of findings come from one but not the other. Flash is the cheap soundness catcher; Composer is the combinatorial breadth surfacer; neither alone is the right adversary. **Added cost across the full ablation: ~$3** (339 phase-3.5 calls × Composer Standard at ~$0.01/call + Flash gemini-cli free tier). Cheap insurance.

**Step 2 — Merge findings, then type-classify** per the typed-acceptance table below (Phase 4 §Step 2). De-duplicate semantically equivalent findings across the two lenses (same test method named by both → one entry, type-classified once). Apply ENTAILMENT + DISCRIMINATOR findings to the gate. Drop WRONG findings (log the misread).

**Step 3 — Write `$PROXY_GATE_DIR/RESIDUE.md`** containing every SPECULATION-typed finding verbatim, with: (a) the PRD-silence reason it was typed SPECULATION, (b) the concrete impl-shape that would convert it to ENTAILMENT. This file is the Phase 4 re-test set: when an impl exists, Phase 4 walks RESIDUE.md and re-types each entry against the impl.

**Step 4 — Soundness gate on the augmented set.** Same as Phase 4 §Step 3 below.

**Stop condition for Phase 3.5:** every test has a PRD-quote justification; every Phase 3.5 SPECULATION-typed finding appears in RESIDUE.md.

**Measured catch rate (n=1, bandit, 2026-05-29):** 1/3 of impl-bug axis-crossings caught clean, 2/3 with partial credit. Phase 3.5 does NOT replace Phase 4 — it catches the gate-structural class (multi-region semantics, region continuation) while Phase 4 still catches the impl-structural class (operator precedence, rule-applied-at-wrong-scope). The composition is the architecture. Cost: two adversary dispatches (~$0.05 total per task; Flash free + Composer ~$0.05). Phase 4 still uses single adversary (Flash) unless the task's RESIDUE.md is large enough to warrant dual.

### Phase 4 — Cross-family adversary review with the impl in context (typed-acceptance protocol)

The adversary model (`$DSR_ADVERSARY_MODEL`, default `gemini-3.5-flash`; different family from the build-tools/craft model `$DSR_CRAFT_MODEL`) catches structural gaps same-model iteration + mutation-thinking miss. But the adversary also over-suggests AND can be wrong about rule direction. Treat its output as raw findings to be **typed**, not advice to apply.

**Inputs at Phase 4 (different from Phase 3.5):** PRD + design doc + proxy-gate file + **the implementer's captured diff** + **Phase 3.5's `RESIDUE.md`**. The impl in context is what lets SPECULATION become ENTAILMENT.

**Step 1 — Send the volley.** PRD + design doc + proxy-gate file + impl diff via `$DSR_GEMINI_CMD` (or `codex exec` if you've explicitly swapped back). Four asks (the standard three plus the residue re-type):

1. *"Is any current test asserting something the PRD does not plainly require?"* (soundness)
2. *"For each test, name a plausible-but-wrong implementation that satisfies the test's name but violates the rule; if current inputs would NOT detect it, give the input shape that would."* (discrimination)
3. *"Which compositional behaviors stated or implied by the PRD are NOT exercised by the test suite?"* (missing coverage)
4. *"For each entry in `RESIDUE.md`, given the impl now in context, does the impl exhibit a behavior that converts the speculation to ENTAILMENT? If so, name the test that would catch it."* (residue conversion — Phase 4 only)

**Step 2 — Classify every finding by type** (the load-bearing step — adversary findings are evidence, not edits):

| Type | Definition | Action |
|---|---|---|
| **ENTAILMENT** | the rule is plainly stated or directly entailed by the PRD | add or strengthen the test |
| **DISCRIMINATOR** | the rule is already in the gate but the test's inputs don't distinguish it from a plausible mutant | swap the inputs only; don't add a new criterion |
| **SPECULATION** | the rule is plausible but the PRD is silent / ambiguous on it | residue, NOT gate; document the ambiguity |
| **WRONG** | the adversary got the direction reversed or misread the PRD | drop; log the misread (cross-family is not infallible) |

For each adversary finding, write the type next to it in your working notes BEFORE editing the gate. Tests get added/swapped only for ENTAILMENT and DISCRIMINATOR. Never apply a finding that you haven't typed.

**Step 3 — Soundness gate on the augmented set.** After edits, walk every test once more (original + applied) and ask: *"does the PRD plainly require this?"* If silent/ambiguous → residue.

**Stop condition:** no test in the gate without a PRD-quote justification ("PRD: <quoted clause>") in its source comment.

Failure mode this protocol prevents (F₉ corpus-validated under the previous Claude/GPT-5.5 pair): adversary findings #3 + #7 were SPECULATION but applied as ENTAILMENT → gate ended UNSOUND on gold. Typing first would have routed them to residue. Adversary finding #13 was WRONG (reversed metric direction); the agent caught it ad-hoc — the typing step makes such catches part of the protocol, not luck.

**Pair note (2026-05-28):** under the role-split, build-tools and the adversary are different families (Composer-on-Kimi vs Gemini-Flash). H₉ confidence was measured on Claude↔GPT-5.5; transfer **measured 2026-05-29 on bandit: substantive overlap 37.9%, well below 70% collapse threshold → H₉ stands on the new pair** (n=1 artifact, see `harness/feature/run/bandit-structured-nosec-directives/transfer-risk-v1/PAIRING.md`).

**Residue-conversion note (2026-05-29):** Step 1 ask #4 is the new load-bearing step. Most Phase 3.5 SPECULATION entries will remain SPECULATION at Phase 4 (genuinely ambiguous PRD clauses). The minority that convert to ENTAILMENT are the highest-value adds — they catch impl bugs the proxy-author could not have proactively encoded.

### Phase 5 — Emit manifest
Write `manifest.json` to the schema above. `proxy_gate.run` exits 0 iff the necessary bar passes. `baseline_fails` is copied from the adapter's clean-base capture file.

## Re-entry (from verify-spec coverage hole)
- Coverage hole + criterion is **certain** → add test to proxy gate.
- Coverage hole + criterion turns out **ambiguous** → route to design-doc (spec gap, not tooling gap). Never widen the bar with a test you can't defend.

## Notes
The discriminating-test discipline (Phase 2 step inside the gate) is corpus-validated (HYPOTHESIS_GRAPH.md H₈). Enumerating a compositional criterion ≠ writing a test that discriminates the rule's violation — the test inputs must lie *outside* the agreement region of the rule and its plausible mutants.
