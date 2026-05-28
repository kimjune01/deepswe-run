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
3. **Manifest** (`$PROXY_GATE_DIR/manifest.json`) — the `dsr gate` contract:

```json
{
  "task_id": "<id>",
  "proxy_gate": {
    "run":      "<cmd that exits 0 iff the necessary bar passes>",
    "path":     "<test file path>",
    "criteria": ["1","2", "..."]
  },
  "probes": [
    { "name": "<id>", "run": "<cmd>", "does": "<one line>" }
  ],
  "baseline_cmd":    "<project's existing suite (regressions)>",
  "baseline_fails":  ["<tests already red on clean base, copied from $BASELINE_FAILS file>"],
  "verdict_file":    "<path verify-spec writes>"
}
```

Append nodes to the hypothesis graph (never truncate).

## Process

### Phase 1 — Triage criteria by certainty
Per design-doc criterion: **certain** (PRD plain) → proxy gate · **ambiguous** (design-doc flagged) → residue. Gate built from certain set only.

### Phase 2 — Build the proxy gate
- One test per certain criterion at `$PROXY_GATE_DIR`, in the repo's test framework.
- Use the criterion's stated check (input → expected output / message).
- Run them; confirm they FAIL because the feature is absent. A test green pre-implementation is mis-written or the criterion is already satisfied — investigate.
- Cover only the *certain* edge cases / error messages / precedence rules; each as its own test.

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
