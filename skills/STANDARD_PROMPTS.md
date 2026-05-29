# Standard prompts — frozen prompt forms for the scaffold pipeline

These are the verbatim prompts used by `harness/run_arm.sh` scaffold arm. They live here rather than only inline in the shell script so that:

1. The freeze-hash machinery (`FREEZE-CHECKLIST` §II) covers them — `frozen/HASHES.txt` SHA256s these alongside the skill files.
2. Operators reviewing the scoring run can read what each phase actually asked the model, without having to grep escape sequences in bash.
3. Cross-language reimplementations (Python runner, etc.) can mirror these without divergence.

Substitutions in `${BRACES}` are interpolated by the runner; everything else is literal. The runner's actual string MUST match the byte-equivalent of these (modulo `${...}` substitution and trailing newline). Drift breaks reproducibility.

---

## Phase 1 — design-doc (Composer 2.5 via cursor-agent)

```
Read this PRD and produce a brief design doc using EXACTLY this schema (no other prose outside the schema):

```
FEATURE-SHAPE: <one of: enum | invariant | mixed>
FEATURE-TYPE: <one of: additive | subtractive | transform | filter | selector | optimizer>
BRANCH: <one of: 1 (preserve-existing) | 2 (narrow-the-transform) | 3 (complete-the-isolated-surface) | 4 (never-cross-a-hard-boundary)>

TYPED-INTERFACE-SURFACE:
- <pre-existing types/functions the impl will touch>

PRD-HARD-NEGATIVES:
- <things the PRD plainly forbids — input shapes that must NOT change behavior>

ACCEPTANCE-CRITERIA:
1. <testable behavior, one per line, PRD-quoted where possible>
2. ...

RESIDUE (AMBIGUOUS):
- <PRD clauses that admit multiple readings; build-tools will route these to RESIDUE.md>
```

PRD:
${PRD}
```

**Why this shape:** measured 2026-05-29 n=3 head-to-head, Composer follows this schema cleanly; Flash drifted into conversational prose. BRANCH slot explicitly disambiguates project's decision-tree branch (1-4) from git-branch name (both models defaulted to git-branch reading without the explicit definition).

---

## Phase 2 — build-tools (Composer 2.5 via cursor-agent)

```
You are build-tools. Read this PRD + design doc and emit a proxy gate (test file) that tests the PRD's behaviors. Apply: PRD-quote per test, axis-crossing inputs, boundary clauses, # RESIDUE: at file head for SPECULATION. Output one fenced code block.

PRD:
${PRD}

DESIGN DOC:
${DD_OUT}
```

**Why this shape:** the discipline trio (PRD-quote, axis-crossing, boundary clauses) is encoded in `skills/build-tools/skill.md` Phase 2 §Discipline. Measured 2026-05-29 Composer-as-author unprompted produces `# RESIDUE:` block + helper functions (`ids()`, `count()`) for richer assertion shapes.

---

## Phase 3.5 — dual adversary on the gate (Flash + Composer in parallel)

Both adversaries receive **the same prompt below**. Findings de-duplicate semantically; TYPE-prefix is mandatory (`TYPE: ENTAILMENT | DISCRIMINATOR | SPECULATION | WRONG`). SPECULATION-typed findings carry forward to Phase 5 via `RESIDUE.md` (per §VII of FREEZE-CHECKLIST).

```
Adversary review (3 asks): soundness | discrimination | missing coverage. Number findings F1..; end with COUNT: N.

PRD:
${PRD}

PROXY GATE:
${PG_OUT}
```

**Why dual:** measured 2026-05-29 substantive overlap 37.9% bandit / 11.5% kysely → 62-89% of findings come from one lens but not the other. Flash adds cross-cutting consolidated findings; Composer adds granular per-test soundness. Cost: ~$0.075 per task × 339 phase-3.5 calls ≈ $25 across full ablation (rounding error).

---

## Phase 5 — adversary on impl + RESIDUE re-type (treatment-defining, ENTAILMENT triggers revision)

**Default: Composer-sole** (`$DSR_ADVERSARY_BREADTH_MODEL`). Flash optional second lens via `PHASE5_DUAL=1` env var.

```
You are the cross-family adversary reviewing an IMPLEMENTATION against the PRD it was supposed to satisfy. You also receive the design-doc the author worked from, the proxy gate that defined the necessary bar, and a RESIDUE.md of SPECULATION-typed findings from earlier (pre-impl) review.

Soundness is the load-bearing axis. Catch PRD violations the impl introduced.

Answer 4 numbered asks. For each finding, prefix with one of: TYPE: ENTAILMENT | DISCRIMINATOR | SPECULATION | WRONG. ENTAILMENT findings will trigger an impl revision pass — be honest about whether something is plainly PRD-violating or merely your aesthetic.

## 1. Soundness (PRD violations in the impl)
Cite the file + line range; quote the impl; quote the PRD clause it violates.

## 2. Discrimination (impl looks right but a mutant would pass the same tests)
Name the mutant; give an input shape that would surface it.

## 3. Missing coverage (PRD behaviors NOT implemented)
Quote the PRD clause; describe what the impl is missing.

## 4. RESIDUE conversion — re-type each RESIDUE entry against the impl
For each RESIDUE entry, does the impl exhibit a behavior that converts it from SPECULATION to ENTAILMENT? If yes, name the new ENTAILMENT finding and describe the conversion. If still ambiguous, mark as REMAINS-SPECULATION.

End with COUNT: N.

---

PRD:
${PRD}

DESIGN DOC:
${DD_OUT}

PROXY GATE (truncated to first 5KB):
${PG_TRUNC}

RESIDUE.md:
${RESIDUE_CONTENT}

IMPL DIFF (current model patch):
${IMPL_DIFF}
```

**Why soundness-emphasis:** measured 2026-05-29 — the generic 3-ask prompt left Composer doing only breadth-shaped work and missing axis-crossing soundness bugs. With the soundness-emphasis frame ("the load-bearing axis"), Composer-sole catches what Flash caught at Phase 3.5 (e.g. the bandit `test_axis_crossing_begin_and_next_line` over-assertion). The prompt is half the model.

---

## Revision pass — fired iff Phase 5 ENTAILMENT count > 0 (bounded one-shot)

```
Your previous implementation has the following PRD-violation findings from cross-family adversary review. Revise the impl in this workspace to address each ENTAILMENT-typed finding. Keep code that was not flagged.

ENTAILMENT findings:
${FEEDBACK}
```

`${FEEDBACK}` is the `grep -B1 -A8 'TYPE: ENTAILMENT'` extract from `phase5-adversary.txt` (and from `phase5-adversary-flash.txt` if `PHASE5_DUAL=1`). The revision is bounded one-shot — no further iteration regardless of whether subsequent grading passes.

**Why bounded:** the prereg names exactly how much "richer than single-shot" the scaffold is. Unbounded iteration confounds "scaffold richness" with "more model time" — the McNemar comparison would not isolate harness shape from compute budget. One revision pass keeps the comparison clean.

---

## Baseline-comp arm — single-agent cursor-agent (composer-2.5)

```
Implement the feature from this PRD. Edit files in this workspace directly. The workspace is a git repo at base ${BASE_SHA} — only source files should be modified.

PRD:
${PRD}
```

---

## Baseline-flash arm — direct Gemini API (NOT gemini-cli — workspace exploration takes 17+ min on large repos)

```
Implement the feature from this PRD. Output a SINGLE unified git diff against the current workspace, wrapped in one fenced ```diff block. Use 'a/' and 'b/' path prefixes as git produces. Modify only source files; do not touch tests/, configuration files, or generated artifacts. No prose outside the block.

PRD:
${PRD}
```

Diff is extracted by regex (`r'```diff\n(.*?)\n```'`) and applied with `git apply --whitespace=nowarn`. Apply failures → `INFRA_PARSE` classification per FREEZE-CHECKLIST §V.

---

## Receipts of measurements that shaped these prompts

- Phase 1 (design-doc) — Composer-vs-Flash n=3: `results/recon-comparison/composer-recon-*.txt` vs `results/runs/*/scaffold/audit/design-doc.md`
- Phase 5 soundness-emphasis — Composer-sole on bandit with new prompt: `harness/feature/run/bandit-structured-nosec-directives/composer-sole-adversary/composer-sole-raw.txt` (60 findings, F12 = axis_crossing soundness bug catch)
- Phase 5 Flash with same prompt: same dir, `flash-same-prompt-raw.txt` (13 findings, F2 = same axis_crossing catch)
- baseline-flash diff-output mode (vs gemini-cli explore-mode): `results/runs/*/baseline-flash/responses.jsonl`
