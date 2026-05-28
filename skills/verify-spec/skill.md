---
name: verify-spec
description: Verification phase for feature-request (PRD-shaped) tasks (DeepSWE / Harbor format). Runs the proxy gate (the acceptance-criteria tests implement-spec authored) and the project's existing suite (regressions), classifies the result against the design doc's acceptance criteria, and emits a verdict plus a re-entry route. RESOLVED here means proxy-green and regression-clean, explicitly NOT a certified grade-time pass. No edits.
argument-hint: <task-id>
allowed-tools: Read, Grep, Glob, Bash
---

# Verify-spec: Acceptance Verification for PRD Tasks

Run the proxy gate and the existing suite. Check every acceptance criterion. Return a verdict and a route. No edits — verify never mutates the tree.

**This is the feature-task fork of `audit`, and the difference is the gate.** Bug-fix audit runs the real grading suite (FAIL_TO_PASS / PASS_TO_PASS) and certifies RESOLVED. Here the grading suite is hidden until grade time, so verify can only run **the proxy gate implement-spec authored** plus **the project's existing suite**. Therefore:

- A verify **RESOLVED is proxy-green + regression-clean, not a certified pass.** It says "every acceptance criterion this pipeline knows about is met, and nothing visible regressed." It cannot say "the hidden grader will pass." State this honestly in the verdict; never round up to grade-certainty.
- Verify's second job is **coverage**: an acceptance criterion with no proxy test is a hole in the design doc, not a code pass. Catch it and route it back.

## Environment

Code lives in an offline Docker container (the implement edits are live in the working tree). Reach it via the helper the adapter names; it already `cd`s to the repo root — **do not prepend `cd`**.

**There is no real `gate`.** You run two things via the box helper: (1) the **proxy gate** — the acceptance-criteria tests implement-spec wrote (it names their location, or rebuild them from the design doc's criteria if they were removed); (2) the **project's existing test suite** — visible and real, for regressions. You never see the hidden grading tests.

## Input

From the adapter:
- The **design doc's acceptance criteria** (the checklist verify must confirm).
- The location of the **proxy gate** implement-spec authored (or the criteria to reconstruct it).
- The implement-spec graph nodes.

There is no fail-on-base capture and no PASS_TO_PASS list. The regression baseline is the project's existing suite, which you run directly.

## Output

A verdict and a route, printed to stdout. Append the breakdown to the hypothesis graph.

## Process

### Phase 1: Confirm the patch is live
`git diff --stat`. If empty, emit `NOT_RESOLVED — empty patch` / `RE-ENTER: implement-spec` and stop. Never apply anything yourself.

### Phase 2: Map criteria to proxy tests (coverage)
For each acceptance criterion in the design doc, find the proxy test that checks it. A criterion with **no** corresponding proxy test is a **coverage hole** — flag it; it routes to design-doc, because the checklist itself is incomplete.

### Phase 3: Run the proxy gate and the existing suite
Run the proxy gate. Record each criterion's test as PASS / FAIL. Then run the project's existing suite. Any existing test now failing is a **regression** introduced by the feature (the existing suite passed before the patch by definition — it is the pre-feature state).

### Phase 4: Classify
- **Criterion proxy test PASS** → that criterion is met (as far as the proxy can tell).
- **Criterion proxy test FAIL** → the feature does not satisfy that criterion.
- **Criterion with no proxy test** → coverage hole (checklist incomplete).
- **Existing-suite test newly failing** → regression.

### Phase 5: Verdict + route

| Condition | Verdict | Route |
|---|---|---|
| Every criterion has a PASSing proxy test, 0 regressions | `RESOLVED (proxy)` | `RE-ENTER: none` |
| Every criterion has a passing test, 1+ regressions | `NOT_RESOLVED — regressions` | `RE-ENTER: implement-spec` |
| 1+ criterion's proxy test FAILs | `NOT_RESOLVED — criterion unmet` | `RE-ENTER: implement-spec` |
| 1+ acceptance criterion has no proxy test | `NOT_RESOLVED — coverage hole` | `RE-ENTER: design-doc` |
| Empty patch | `NOT_RESOLVED — empty patch` | `RE-ENTER: implement-spec` |

Routing rationale (the outer loop):
- **Regression / criterion-unmet** → the design is right, the implementation is wrong or too broad. Send the failing criterion or regressed test to implement-spec.
- **Coverage hole** → the design doc's acceptance criteria missed a behavior. Send it to design-doc; implement-spec cannot test what was never specified.
- **Criterion unmet AND the design path looks wrong** (implement-spec already tried and flagged DESIGN WRONG) → route design-doc instead, to re-map.

**No-progress escalation.** A regression gets one narrow attempt at implement-spec. If it survives the narrow on the next round, route design-doc — the approach itself conflicts with the existing behavior.

**`RESOLVED (proxy)` is not a grade.** It is the strongest statement this pipeline can make without the hidden tests. Always emit it with the `(proxy)` qualifier so the driver and the operator never mistake it for a certified pass.

### Phase 6: Emit
```markdown
# Verify-spec: <task-id>

## Acceptance criteria
- criterion 1: PASS / FAIL / NO-TEST
- ...

## Regressions (existing suite)
- test: <error>   (or "none")

## Coverage holes (criteria with no proxy test → design-doc)
- criterion N   (or "none")

## Kill report (only if not RESOLVED — routes the loop)
<criterion-unmet / regression: which, the error, the implicated path>
<coverage-hole: which criterion was never tested>

VERDICT: <RESOLVED (proxy) | NOT_RESOLVED — <reason> | PARTIAL>
RE-ENTER: <design-doc | implement-spec | none>
```

## Rules
- **No hidden tests; RESOLVED is `(proxy)`, never a certified grade-pass.** Say so on the verdict line.
- **Coverage is a first-class failure.** A criterion with no proxy test routes to design-doc, not a pass.
- **Never mutate the tree.** No `git stash`, no edits, no applying. The driver captures the patch after you.
- **Regression baseline is the live existing suite** (run it), not a capture — there is no fail-on-base file here.
- **The route is load-bearing.** Criterion-unmet/regression → implement-spec; coverage hole → design-doc. Misrouting wastes an outer-loop iteration.
- **Verdict and route on their own final lines.** The driver greps the last `VERDICT:` and `RE-ENTER:`.
- **Append the graph, never truncate.**
