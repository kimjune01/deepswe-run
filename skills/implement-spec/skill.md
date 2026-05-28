---
name: implement-spec
description: Implementation phase for feature-request (PRD-shaped) tasks (DeepSWE / Harbor format). Builds the feature from the design doc. There is NO runnable grader during the run, so implement-spec first AUTHORS a proxy gate from the design doc's acceptance criteria, then implements against it; a codex subagent challenges the diff against the spec. Features are large (multi-file by design) — completeness over minimalism. Proxy-green is the stopping signal available, NOT proof of a grade-time pass.
argument-hint: <task-id>
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Implement-spec: Feature Implementation for PRD Tasks

Take the design doc, author a proxy gate from its acceptance criteria, implement the feature across every edit site, let codex challenge it against the spec. The feature is done when every acceptance criterion has a passing proxy test and the existing suite still passes — with the standing caveat that the real grader is hidden, so proxy-green is the best signal you have, not a guarantee.

**This is the feature-task fork of `craft`, and the difference is the gate.** Bug-fix craft loops against a real FAIL_TO_PASS gate that is ground truth. Here the grading verifier is hidden until grade time, so **you build the gate yourself** from the design doc's acceptance criteria, and you must accept that passing it is necessary, not sufficient. Two consequences flip craft's rules:

- **Completeness over minimalism.** DeepSWE features are large (median ~840 LOC across ~6 files). Craft's "minimal fix, no scope creep" is wrong here. The failure mode is a *missed acceptance criterion*, not an oversized diff. Implement every criterion; a large multi-file change is expected. (Still: no *unrequested* features, and source-only.)
- **Cover exhaustively, because nothing else will catch a gap.** With no real gate, a criterion you neither implement nor test surfaces only at the one-shot grade.

## Environment

Code lives in an offline Docker container, reached through the helper the adapter names (e.g. `box-sh '<cmd>'`). It already `cd`s to the repo root — **do not prepend `cd`**. Edit files through the helper.

**There is no `gate` helper and no FAIL_TO_PASS list.** You author the proxy gate (below). You may run the project's existing test suite through the box helper to guard against regressions — that suite is visible and real, even though the feature-acceptance tests are hidden.

`codex` runs locally (NOT in the container). Bridge it: pull file contents via the box helper, paste into the codex prompt, apply the result yourself.

## The proxy gate (you build it — this replaces the real gate)

The design doc hands you an **acceptance criteria** list, each with a check (input → expected output / message). Turn that list into a runnable test suite, in the repo's own test framework, before you implement:

1. Write one proxy test per acceptance criterion. Use the criterion's stated check. Cover edge cases, error/warning messages, and precedence rules as their own tests.
2. Run them. They should fail (the feature is absent). A criterion whose test passes *before* you implement is mis-written or already satisfied — investigate.
3. **The proxy gate is scratch, not deliverable.** It guides implementation and feeds codex. Keep it out of the final source diff (write it in a scratch path or remove it before finishing). The deliverable is the feature source only; the real grader brings its own tests.

The proxy gate is only as good as the design doc's criteria. If implementing reveals a behavior the criteria missed, that is a coverage hole — add a proxy test and note it for the graph (verify-spec may route it back to design-doc).

## The codex volley (the structural filter — unchanged from craft)

codex reviews your diff against the spec. It never needed the container. Send it the **acceptance criteria** (not a hidden test — there isn't one), the design doc's approach, and your diff; ask what criterion is unmet, what breaks, what is missing. Pipe via stdin:

```bash
cat <<'PROMPT_EOF' | codex exec -
This diff implements a feature spec. Be direct — which acceptance criteria are unmet, what is missing, what breaks. No preamble.

ACCEPTANCE CRITERIA (must all hold):
<the numbered criteria from the design doc>

APPROACH (from the design doc):
<the approach section>

RELEVANT SOURCE (current, pulled from the repo):
<file contents>

PROPOSED DIFF:
<your unified diff>
PROMPT_EOF
```

- **You draft first.** codex breaks a concrete diff, not an empty prompt.
- **Fold in load-bearing catches** (missed criterion, wrong branch, broken invariant); gate the rest against the proxy.
- **Volley before the first proxy run and again on every proxy failure.** codex sees every diff and every red proxy run.
- **codex is a filter, not the grader.** With the real gate hidden, codex's spec-coverage read is more load-bearing than in craft — but it is still not proof. It converges in 2-3 rounds (see [the volley](https://june.kim/volley)).

## Input

The design doc, inline in the adapter prompt. Extract: acceptance criteria, approach, edit sites, design alternatives (PRD ambiguities), risks. On re-entry, a **VERIFY KILL REPORT**.

## Output

Container edits that persist for /verify-spec (same container), feature source only (proxy gate removed). The driver captures `git diff`. Append your nodes to the hypothesis graph.

## Process

### Phase 1: Read the design doc
Read it inline. Resolve any ambiguous edit site by reading the file first. For design alternatives (PRD ambiguity), pick the reading the doc bet on; note the risk.

### Phase 2: Build the proxy gate
Author one proxy test per acceptance criterion (see "The proxy gate"). Run them; confirm they fail for the right reason (feature absent).

### Phase 3: Enumerate, then implement every edit site
`grep -rn "<pattern>" .` to confirm each site. Implement the full feature across all sites — completeness is the goal. Edit source in place via the box helper; leave no scratch generators in the source. Large, multi-file diffs are expected.

### Phase 4: Volley
Volley the diff with codex against the acceptance criteria before running the proxy gate. Fold in load-bearing catches.

### Phase 5: Proxy loop + regression guard
Run the proxy gate. Then run the project's existing suite for regressions.

| Signal | Next move |
|---|---|
| Proxy criterion still failing | implementation missed that criterion's path — follow it |
| Existing-suite test regressed | the change is too broad on that path — narrow the source (never edit the test) |
| Proxy passes, suite clean | stop — but record that this is **proxy-green, not grade-green** |

Volley every proxy failure. **Max 8 implementation iterations.** Remove the proxy gate from the tree before finishing. If you exhaust iterations, leave the best feature source in the tree and note the uncovered criteria in the graph.

### Phase 6: Reopen design when the approach is wrong
If after 3 iterations a criterion can't be satisfied along the design's path and the approach looks wrong, stop. Write `DESIGN WRONG: <what the code actually requires>` to the graph and print `NOT-RESOLVED — re-design`. The driver routes back to design-doc.

## Verify re-entry (narrow / cover mode)
When the adapter includes a **VERIFY KILL REPORT**:
- **Regression** (existing suite broke): the feature is right but too broad. Narrow the source on the regressed path. Do not re-design.
- **Criterion's proxy test failed**: implementation missed that criterion. Fix that path.
- **Coverage hole** (criterion with no proxy test): add the proxy test; if the behavior wasn't implemented, implement it.

## Rules
- **No real gate exists; proxy-green is necessary, not sufficient.** Never report grade-certainty. The honest stop is "every criterion has a passing proxy test, suite clean."
- **Completeness over minimalism.** Implement every acceptance criterion. The failure mode is a missed criterion, not diff size. No *unrequested* features.
- **Source-only deliverable.** Do not ship the proxy gate; do not edit the project's existing tests to go green; leave no scratch scripts. The captured `git diff` is feature source only.
- **You generate, codex filters.** Never reverse. With the gate hidden, lean harder on codex for spec coverage — but it is a filter, not an oracle.
- **Enumerate before applying** any N-site change; grep again to confirm zero remaining.
- **8 iterations max; re-design at 3** if the approach is wrong.
- **Append the graph, never truncate. Leave the tree in the feature-complete source state.**
