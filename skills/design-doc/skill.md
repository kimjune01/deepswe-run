---
name: design-doc
description: Read-only design phase for feature-request (PRD-shaped) tasks (DeepSWE / Harbor format). The task spec is a PRD; this produces the design doc that answers it. There is NO runnable grader during the run — the verifier is hidden until grade time — so this does not reproduce a failure. It maps the PRD to the codebase and emits a design doc whose acceptance-criteria section becomes implement-spec's proxy gate. Correction comes from the verify→design loop, not a real grader. No edits, no external access.
argument-hint: <task-id>
allowed-tools: Read, Grep, Glob, Bash
---

# Design-doc: PRD → Design for Feature Tasks

The task spec is a PRD. Read it, map it to the codebase, and write the design doc that an engineer would write before touching code: context, acceptance criteria, approach, implementation plan, risks. No edits — design is read-only. Every claim about current behavior cites code you can quote.

**This is the feature-task analogue of bug-fix `recon`, and the difference is the gate.** In the bug-fix pipeline the gate (FAIL_TO_PASS) is ground truth the agent can run and cannot see-edit. Here the grading verifier is **hidden until grade time** (Harbor applies `test.patch` only when grading), so during the run there is no real gate, the work is effectively **one-shot**, and the only proxy is a gate `implement-spec` will *author from the acceptance criteria in this doc*. A proxy gate cannot test a criterion you never wrote down. So the bug-fix rule "be falsifiable, not exhaustive, the loop will catch you" is inverted: **the acceptance criteria must be exhaustive**, because a missed requirement surfaces only at the one-shot grade, where it is too late.

## Environment

Code lives in an offline Docker container, reached only through the helper the adapter names (e.g. `box-sh '<cmd>'`). The helper already `cd`s to the repo root — **do not prepend `cd`**. There is no internet, no `gh`, no `codex`, no external fetching.

**There is no failing-test list and no gate helper.** The input is a prose PRD (`instruction.md`) describing behavior to add. The grading tests are not in the working tree. Do not look for a FAIL_TO_PASS list; there isn't one.

## Output

Print the design doc to **stdout** as a markdown block starting with `# Design doc:`. The driver captures stdout and feeds it to /implement-spec. Also append your nodes to the hypothesis graph the adapter names (it accumulates across the outer loop — never truncate it).

The load-bearing section is **Acceptance criteria**: an exhaustive, atomized list of every required behavior in the PRD. implement-spec turns it into the proxy gate. A criterion you omit is a behavior nobody tests until grade time.

## Process

### Phase 1: Acceptance criteria (atomize the PRD)

The PRD is the source of truth. Read `instruction.md`, re-read it, and decompose it into the smallest checkable requirements.

1. Feature PRDs bury requirements in subordinate clauses ("Non-map elements and elements missing the merge key are preserved", "Null user values delete the key", "the `global.` prefix is stripped"). Catch them all.
2. Write each requirement as a numbered, atomic criterion: one observable behavior each. Split compound sentences. Capture edge cases, error/warning conditions, precedence rules, and naming/interface requirements as their own criteria.
3. For each criterion, state the check: input → expected output / side effect / message substring. This is what implement-spec needs to write the proxy gate.
4. Flag ambiguous criteria explicitly — where the PRD underspecifies, the reference solution and the hidden test resolved the gap somehow, and you must guess. Note the guess and its risk.

### Phase 2: Context (map criteria to current behavior)

For each criterion, find where the behavior lives or must live.

1. Trace the relevant path: where does the analogous existing behavior happen? (e.g., "arrays are currently replaced wholesale at `coalesce()` in `pkg/chartutil/coalesce.go`").
2. Grep the identifiers, functions, config keys, interfaces the PRD names. Find every site.
3. Read blame for the suspect region: `git log --oneline -10 -- <file>`. A deliberate design has different weight than a default.
4. Classify each criterion: **already satisfied** (check — don't reimplement), **partially present** (extend an existing path), or **absent** (new code). The gap is partial + absent.

### Phase 3: Approach (the design)

1. State how each criterion is realized: which function, which new branch, which new file, which interface change. This is the design.
2. Quote the current code each criterion attaches to (file:line).
3. Classify confidence by reasoning mode: **deduction** (read the code, the attachment point is unambiguous → 95-99%), **induction** (ran a read-only probe to confirm current behavior → 90-95%), **abduction** (inferred the design from the PRD, code not yet confirmed → 60-85%). PRD ambiguity caps confidence at abduction.
4. Where the PRD admits two readings, present both as design alternatives — but note that **the proxy gate cannot arbitrate between them the way a real gate would**, so state which reading you'd bet on and why.

### Phase 4: Implementation plan (edit sites)

For each criterion in the gap, enumerate every location that must change:

1. `grep -rn "<pattern>" .` — enumerate ALL occurrences. Never reconstruct from memory.
2. For each edit site: file path, line range, the criterion(s) it implements, plain-language description.
3. Check callers, subclasses, interface implementers, and config/annotation parsers the change must also touch.

### Phase 5: Emit the design doc

Print to stdout:

```markdown
# Design doc: <task-id>

## Acceptance criteria (exhaustive — implement-spec builds the proxy gate from this)
1. <atomic requirement> — check: <input → expected output / message>
2. ...
(mark ambiguous: AMBIGUOUS — <the two readings, which you'd bet on>)

## Context (current behavior)
<2-4 sentences: how the relevant path works now, why the feature is absent>
Supporting evidence:
- `file:line` — <quote>

## Approach (criterion → design)
- Criteria 3,4: `path/file.go` lines 10-40 — <what to add and how>
- ...
Confidence: <deduction/induction/abduction> — <percentage>

## Implementation plan (edit sites)
- `path/file.go` lines 10-20 (criteria 3,4): <what to change — specific enough that implement-spec acts without re-reading>

## Design alternatives (PRD ambiguity — proxy gate can't fully arbitrate)
- Reading A: <design> — bet: <yes/no, why>
- Reading B: <design>

## Risks / coverage gaps
- <criteria you are least sure the proxy gate will catch>
```

Do not include code patches. The implementation plan is a specification, not a diff.

## Re-entry (outer loop — proxy gate, not a real one)

When the adapter includes a **VERIFY KILL REPORT**, the prior attempt failed against the *self-authored proxy gate* or a criterion check. The signal is weaker than a real gate: a proxy-gate kill means "the patch failed a test implement-spec wrote from my criteria," only as trustworthy as the criteria. Treat it as a new observation:

- If a criterion's proxy test failed: the implementation missed that criterion's path. Re-map from there (Phase 2 for that criterion).
- If verify reports a **criterion with no test**: that is a coverage hole in *my* acceptance criteria, not a code failure. Add the criterion, hand it back.
- **Do not re-propose a killed design.** It's a dead node in the graph.
- If re-design converges on the same approach, say `FIXED POINT: re-design converged`. The driver halts the loop.

## Rules

- **Read-only.** No edits. Reads, greps, shell observations only.
- **Exhaustive on acceptance criteria.** Unlike the bug-fix recon, completeness is the priority: there is no ground-truth gate to catch a criterion you skipped. Atomize fully.
- **Quote the code.** Every claim about current behavior cites file:line.
- **Enumerate before asserting.** `grep -rn` before "the only site is X."
- **Confidence tracks mode, and PRD ambiguity caps it.** An inferred design is abduction, not deduction, no matter how clean it reads.
- **The acceptance criteria are load-bearing.** implement-spec's proxy gate is only as good as this list. A missed criterion is an untested behavior.
- **Append the graph, never truncate.**
- **Stdout is the handoff.**
