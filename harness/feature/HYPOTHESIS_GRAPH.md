# Hypothesis graph: feature-task pipeline on DeepSWE

## What this is

This file is a **hypothesis graph (HG)** in the sense of [Internal Reasoning of Prose Compiler](https://june.kim/internal-reasoning-of-prose-compiler): *"prose-shaped so a human can audit it, graph-shaped so a machine can traverse it. Nodes are perturbations, edges are evidence trajectories, leaves carry e-value classifications with provenance back to the artifact each claim came from."*

This deepswe-run pipeline is a **third prose compiler**, sibling of [sweep](https://github.com/kimjune01/sweep) and [immune](https://github.com/kimjune01/immune), and **upstream of sweep**:

| Pipeline | Compiles | Position |
|---|---|---|
| this (spec compiler) | `Spec → Issue or PR` | upstream of sweep |
| sweep | `Issue → PR` | contributor side |
| immune | `PR → verdict / merge` | maintainer side |

The output is bimodal: a spec that admits a clean implementation emits a PR (proxy-green patch); a spec that hits a coverage hole or rejects emits an Issue (the kill report — which is structurally what sweep then consumes). Same IR shape (HG), same six-stage Natural Framework substrate, different transport (a benchmark task list / local PRD, not a GitHub Issue/PR pair).

Two layers, both using HG as IR:

| Layer | What it compiles | IR (HG instance) | Passes (skills) | "Build event" |
|---|---|---|---|---|
| **Object** (per task) | Spec → Issue or PR | per-run design doc + manifest + `$PROXY_GATE_DIR` + this graph's task-scoped nodes | design-doc, build-tools, compose, implement-spec, verify-spec | RESOLVED → PR-ready patch · NOT_RESOLVED/REJECTED → Issue (kill report) |
| **Meta** (cross-session) | "the compiler should behave like X" → skill-file change | this graph (cross-task nodes) + `build-tools-lessons.md` | investigate, sweep, codex-sniff, fan-out, retro | (Issue) → PR → merged on `skills/*/skill.md` |

The meta layer's build event is the same shape as sweep/immune's: an issue (a measured behavior gap on the compiler itself), a PR (a skill patch), a merge gated by measurement (graph node moves from open → confirmed/refuted, with confidence + provenance). The skill files are the compiler source; this graph is the in-flight reasoning between Issue and merge.

## HG node grammar (canonical)

Per the post: nodes = perturbations · edges = evidence trajectories · leaves = e-value classifications with provenance back to the artifact each claim came from. This file's instantiation, per [/investigate](https://june.kim/the-hypothesis-graph): node = claim + null + perturbation +
[trajectory shape](https://june.kim/evidence-has-a-trajectory) + kill condition + edge + reasoning
mode + confidence + provenance. Trajectory: **divergent** (monotone evidence) / **convergent** (rises
then settles) / **oscillatory** (modes visible — split) / **chaotic** (perturbation doesn't isolate —
redesign). Confidence ceilings: deduction 95-99 · induction 90-95 · abduction 60-85.

---

## ⚠ OVERFIT — session was train+test on the same axis (named 2026-05-27)

**Diagnosis (after F₁₁ + user observation):** the entire patch lineage trained and tested against
compositional rules:

1. H₀ anchored on httpx (closed-negatives + compositional edges) — single feature shape.
2. Bandit deliberately chosen *because* it was corpus-confirmed SUBTRACTIVE/filter — same axis.
3. The two probe mutants (M1 nested blanket-dominance, M3 LIFO end-pop) are both compositional.
4. Every patch (H₁ᵦ purpose-over-surface, H₇ iteration, H₈ mutation thinking, H₉ cross-family,
   H₁₀ typed acceptance) targets compositional gaps.
5. F₉ saturation validated against the same compositional signal.
6. F₁₁ surfaced the bias: 42% of the canonical surface (path/fixture + breadth) doesn't sit in the
   compositional axis.

The skills work on the axis they were built for; their generalization is **not earned**. Confidence
numbers on every compositional-targeted H should reflect this — they validate the patch on its training
distribution, not on the population.

**Required next step (corpus replication, F₁₂):** re-measure on a feature task with a *different*
class distribution (e.g., an ADDITIVE task with predominantly breadth misses, or a fixture-heavy
task) BEFORE trusting any of H₁ᵦ-H₁₀ at the population level.

**Confidence haircut applied below** (each is now ON-AXIS confidence; OFF-AXIS / population
confidence is significantly lower until F₁₂).

## H₀′ — **REFUTED (corpus, F₁₂).** Breadth/interface is the dominant class, not compositional.

**F₁₂ (wider sweep)** classified canonical test miss-classes across 6 tasks (n=224 tests):

| Task | n | comp% | path% | breadth% | plain% | baseline% | DOMINANT |
|---|---|---|---|---|---|---|---|
| bandit | 77 | **42** | 25 | 17 | 14 | 3 | compositional |
| opa | 4 | 25 | **50** | 0 | 25 | 0 | path/fixture |
| httpx | 36 | **33** | 19 | 22 | 25 | 0 | compositional (mild) |
| happy-dom | 19 | 21 | 5 | **63** | 5 | 5 | breadth |
| kysely | 78 | 24 | 0 | **71** | 5 | 0 | breadth |
| oxvg | 10 | **40** | 20 | 30 | 0 | 20 | compositional (mild) |

**Aggregate (weighted, n=224):** breadth **41%** · compositional 32% · path 14% · plain 12% · baseline 2%
**Aggregate (unweighted average across tasks):** breadth 34% · compositional 31% · path 20% · plain 12% · baseline 5%

**Findings:**
- Breadth/interface is the most common dominant class across the corpus (3 of 6 tasks, weighted majority).
- Compositional dominates only 2 of 6 (bandit, oxvg); bandit was the session's anchor — *literally an outlier*.
- Per-task variance is high (breadth ranges 0%→71%). No single discipline captures the corpus.
- **Feature type does NOT predict dominant class:** kysely (subtractive transform) is 71% breadth; happy-dom (additive) is 63% breadth; opa (additive) is 50% path/fixture. The mapping is task-specific.

**Implications for the session's patches:**
- H₁ᵦ/H₇/H₈/H₉/H₁₀ all target compositional (32% of weighted corpus). They address the second-largest class.
- Breadth/interface (41% — the *largest* corpus class) has **no dedicated skill discipline.** Hₐ₂ was named abductively before F₁₂; F₁₂ confirms it is the highest-priority unbuilt component.
- Path/fixture (14%) — also untouched; Hₐ₁ candidate.
- The skill stack as built handles roughly 32% of the corpus by surface; the other 58-68% is uncovered.

**Status:** **REFUTED in the strong form.** The session's emphasis was on the second-largest class
because the anchor (bandit) was an outlier. Confidence in the compositional-targeting patches' POPULATION
relevance drops further. They are real and helpful on compositional tasks (bandit, oxvg) but represent
~1/3 of the corpus by surface.

**Mode/conf:** induction (6-task sample) → 80% on the refutation; 70% on the breadth-dominant claim
(small sample, but consistent direction across half the tasks).

**Provenance:** F₁₂ wider sweep 2026-05-27; 5 parallel opus subagents on httpx/opa/happy-dom/kysely/oxvg
+ F₁₁ bandit anchor. Shared log at `harness/feature/run/wider-sweep.md`.

## ~~H₀′ — Compositional rules are the LARGEST class, but NOT dominant~~  (superseded by F₁₂ above)
- **claim (original):** compositional/residual-rule coverage is the *dominant* failure mode.
- **claim (refined):** compositional is the *largest single* class but not overwhelmingly dominant.
  Path/fixture and breadth/interface are co-equal in aggregate. Effective coverage requires patches
  for all three classes; the session's patches target only compositional.
- **null (refined):** the classes are uniformly distributed; no class deserves disproportionate
  attention.
- **perturbation (F₁₁) executed 2026-05-27:** classified all 77 canonical tests of bandit:
  | class | count | % | what it is |
  |---|---|---|---|
  | compositional | 32 | 42% | nested regions, region+inline interactions, dominance, metric resolved-set, multi-rule combinations |
  | path/fixture | 19 | 25% | line-shape edges (Windows newlines, midline directives, comment-trailer, multi-line calls, blank/comment/ellipsis/grouping skip-rules, indent boundaries) |
  | breadth/interface | 13 | 17% | selector operators (\|, &, -, !, parens, glob, fallback), separators, whitespace variants, case-insensitivity |
  | plain/atomic | 11 | 14% | per-directive isolated behaviors |
  | baseline/regression | 2 | 3% | ignore_nosec disabling, legacy `# nosec` preservation |
- **trajectory:** divergent · partially refuting the strong claim. Compositional IS the largest
  single class (42%), but **path/fixture (25%) + breadth (17%) = 42% combined** — equal to
  compositional. The session's emphasis was correctly weighted on the largest class but missed two
  others of roughly equal aggregate weight.
- **second-order finding:** the patches H₁ᵦ/H₇/H₈/H₉/H₁₀ all target compositional. They are
  **necessary but not sufficient** for a complete proxy. Two more skill axes are open:
  - **path/fixture discipline:** does my test setup actually exercise the rule's code path? (Codex
    finding #1 in F₈ was exactly a path/fixture issue — syntactically invalid input prevented the
    expected finding from being generated. The pattern recurs.)
  - **breadth/interface completeness:** have I covered every operator/separator/whitespace variant
    the PRD lists? A separate discipline from compositional coverage — closer to interface contract.
- **status:** **PARTIALLY REFUTED · refined.** Compositional patches are warranted but incomplete.
  Two further discipline axes (path/fixture, breadth/interface) are now named open frontiers.
- **mode/conf:** induction (one-task classification, but the classes are corpus-grounded distinctions
  not bandit-specific) → 75%
- **provenance:** F₁₁ corpus classification 2026-05-27 on bandit; codex sniff finding #4 was the
  abduction; F₁₁ classification was the measurement.

## H₀ — Closed-negative coverage → "bias to slightly overbuild" (httpx anchor)
- **claim:** canonical negatives are closed/enumerated → underbuild fails reliably, overbuild costs
  only against the few enumerated negatives → bias to slightly overbuild.
- **depends on:** H₀′ (compositional rules are the dominant gap; if other classes dominate, the
  bias question is differently shaped)
- **null:** negatives are open/exhaustive; overbuild penalized broadly.
- **perturbation:** read canonical tests for `httpx-streaming-json-iteration`; count `raises` (19) and
  rejected-input enumeration (5 closed types).
- **trajectory:** divergent (httpx alone)
- **status:** **REFINED → H₁** (corpus fan-out refuted it as a flat rule; it holds only for additive
  features)
- **mode/conf:** abduction → induction; 75% before fan-out
- **provenance:** outer-loop canonical analysis, build-tools-lessons.md `outer-loop/canonical-analysis`

## H₁ — Build bias is conditional on FEATURE TYPE (refined H₀, codex-filtered)
- **claim:** classify by effect on the residual set:
  - **additive** (isolated new method/flag/input, no default-path effect) → complete the full stated
    surface; extra is free except against stated hard negatives
  - **subtractive/transform/filter/optimizer/selector** → the preserved/residual set IS the spec;
    over-acting (over-removal, over-suppression, over-protection) is a graded failure
  - **typed interface** → keep signatures as narrow as the spec allows
  - **modifies-existing-for-existing-inputs** → preserve residual first; minimal targeted change
- **null:** flat "bias to overbuild" holds across all feature shapes.
- **perturbation:** fan-out over 13 stratified tasks (Py/TS/Go/Rust/JS), per-task analysis of canonical
  tests + PRD + gold; codex adversarial filter on the proposed rule.
- **trajectory:** divergent — 9/13 additive HOLD, 4/13 subtractive REFUTE; codex named the real
  invariant (monotonicity against the grader's observable contract); rule converged
- **status:** **CLASSIFICATION FAILED, OUTCOME OK · oscillatory — splits into H₁ₐ/H₁ᵦ.** F₁ replication
  on bandit (a corpus-confirmed SUBTRACTIVE/filter task) classified as **ADDITIVE** by the blind agent
  (surface view of "three new directive keywords"), yet still produced SOUND+LIVE because hard-negative
  discipline carried it. The decision-tree label was wrong; the outcome was fine. Two modes visible:
- **mode/conf:** induction (corpus measurement) → 90% on the rule existing; classification reliability
  open
- **provenance:** corpus-fanout.md (13 tasks); codex round 1; encoded 2026-05-27; F₁ bandit replication
  showed misclassification 2026-05-27

### ~~H₁ₐ — Hard-negative-locking discipline does the heavy lifting; classification is decorative~~
- **status:** **KILLED 2026-05-27** by F₁′ mutant M1 (blanket-dominance under nesting): proxy MISSED;
  canonical caught (test_017_region_blanket_overrides_specific, test_018_region_lifo_close_reveals_outer_set).
  If discipline were sufficient, the agent's "metric classification by resolved-set blanketness" claim
  would have caught nested blanket-dominance — it didn't. Discipline catches what the agent SEES; the
  classification directs *what the agent looks for*. Pruned to log.

### H₁ᵦ — Classification matters; decision tree's ordering invites surface-view mismatches
- **claim:** the tree's branch 3 ("isolated new method/flag/input") fires too eagerly for features
  whose new methods' *purpose* is in branch 2's verb list (suppress / select / optimize). Surface-view
  classification on a purpose-SUBTRACTIVE feature loses the preservation-semantics emphasis that
  catches over-action.
- **null:** classification is reliable as-written; bandit miss was idiosyncratic.
- **perturbation (F₁′):** five targeted mutants on bandit gold (M4 inconclusive — informative null):
  | M | what | class | prediction | proxy | canonical | result |
  |---|---|---|---|---|---|---|
  | M1 | blanket-dominance under nesting killed | compositional | DISAGREE | PASS | FAIL (test_017+018) | ✓ DISAGREE |
  | M2 | `nosec-begin` retroactive (`line` not `line+1`) | per-directive | AGREE | FAIL | FAIL (test_082+) | ✓ AGREE |
  | M3 | LIFO end-pop → FIFO (`stack.pop()` → `stack.pop(0)`) | compositional | DISAGREE | PASS | FAIL (test_018) | ✓ DISAGREE |
  | M4 | auto-end-on-dedent disabled | compositional | DISAGREE | PASS | PASS | **inconclusive null** |
  | M6 | `re.IGNORECASE` removed from DIRECTIVE_RE | per-directive | AGREE | FAIL | FAIL (test_098+) | ✓ AGREE |
- **trajectory:** divergent · **4/4 informative mutants match the predicted pattern**. Agent catches
  **simple per-directive PRD negatives** (M2, M6) but misses **compositional/nested resolution rules**
  (M1, M3). M4's mutual PASS is the residue agreement at the *tail* — the agent flagged criterion 20
  (auto-end on dedent for blank/comment lines) as residue and canonical agrees by omission, which is
  the predicted residue boundary holding from *both* sides.
- **status:** **CONFIRMED · skill patched** (implement-spec decision tree now has a precedence rule
  "purpose over surface" + branch 2 wins over branch 3 on conflict; design-doc's Feature-type emit
  block mirrors)
- **mode/conf:** induction (5 mutants, 4 informative, all match prediction; deterministic) → **95%**
- **provenance:** F₁′ mutants M1-M2 + M3-M6 2026-05-27; build-tools-lessons.md `ABDUCTION · F₁′`

## H₂ — Spec-vs-test gap is UNDERSPECIFICATION, not contradiction
- **claim:** the residue (behaviors the canonical pins down that the PRD doesn't state) is
  underspecification — winnable via residue/completeness judgment. Genuine spec-test **contradiction**
  (spec says X, test requires ¬X) would be unwinnable under binary+no-peek → KNOWN_BAD reject.
- **null:** several corpus tasks have spec-test contradiction → many unwinnable.
- **perturbation:** examine each subagent-flagged contradiction; verify the PRD wording against the
  test directly.
- **trajectory:** divergent — every claimed "contradiction" examined so far was refuted on direct
  reading; the apparent contradictions are subagent over-reads, not real
- **status:** **CONFIRMED (so far) · KNOWN_BAD set EMPTY**
- **pruning:** dasel `implicitCloseBarrier` (B3-go subagent claimed PRD contradicts test) **killed** —
  PRD's "same-type siblings" + "block-level closes p" rules, read precisely, produce the test's tree.
  Subagent confabulated. The verify gate caught it before publication.
- **mode/conf:** deduction (re-reading PRD against test) → 95%
- **provenance:** dasel-html-document-format verification 2026-05-27; build-tools-lessons.md
  `CONVERGED · corpus fan-out`

## H₃ — Encoded skill produces SOUND+LIVE proxy on first blind run
- **claim:** after the H₁ patches, a blind agent reading only PRD + source produces a proxy gate that
  is SOUND (gold passes it) and LIVE (base fails it) on first try.
- **null:** the proxy gate is unsound or dead on first blind run; needs an iteration.
- **perturbation:** dispatched general-purpose opus subagents with hard read-forbids on tests/, gold,
  and corpus-fanout/lessons logs. Ran on httpx (ADDITIVE) and bandit (SUBTRACTIVE per corpus, ADDITIVE
  per agent — see H₁).
- **trajectory:** divergent — SOUND+LIVE on first try for both tasks. httpx: 50/62/correct-label.
  bandit: 30/30/wrong-label-but-sound-anyway. Independent of classification accuracy.
- **status:** **CONFIRMED (n=2, distinct feature shapes)**; population estimate firmer.
- **mode/conf:** induction → 92% for the population (was 70% at n=1)
- **provenance:** blind-inner-loop httpx 2026-05-27; bandit 2026-05-27; build-tools-lessons.md

## H₄ — Proxy misses are exactly the underspecification residue
- **claim:** the canonical behaviors a SOUND+LIVE proxy fails to catch are the underspecified ones
  the skill teaches to leave to the LLM residue — not bugs in the proxy.
- **null:** the proxy misses include behaviors the spec plainly states; the skill is teaching the
  wrong residue boundary.
- **perturbation 1:** semantic name-mapping of 62 proxy tests vs 36 canonical tests on httpx →
  ~30/36 covered (~83%); 6 misses identified.
- **perturbation 2:** targeted mutant `gold − BOM-after-start guard` → proxy 82/82 PASS, canonical
  1 FAIL (`test_iter_json_document_bom_inside_array_is_error` at test_json_stream.py:113). **Localized
  the gap to ONE canonical test by mutation.**
- **trajectory:** divergent · supporting — name-mapping + targeted mutation converge: the missed
  behaviors are all in the residue the skill names (exact error semantics, cross-format edges,
  not-stated implicit negatives)
- **status:** **CONFIRMED for one miss (n=1 mutant)**; 5 more residue behaviors are open frontier edges
- **mode/conf:** induction (mutation testing, deterministic) → 95% on the measured one
- **provenance:** dsr isolate + dsr inner; targeted mutant 2026-05-27;
  build-tools-lessons.md `ABDUCTION · targeted mutant on gold`

## H₅ — The bench is engineering, not science
- **claim:** DeepSWE's grader pins behaviors a competent engineer-of-this-repo *would have done* but
  the PRD doesn't state; passing requires engineering-convention agreement with the gold author, not
  spec-faithful derivation. Single-run binary verdicts + no controlled variables = engineering
  measurement, not scientific. Therefore our scope-of-claim must stay engineering ("our pipeline on
  this substrate") and never overreach to scientific claims about agent capability.
- **null:** the bench supports scientific claims about agent capability.
- **perturbation:** observed PRD-vs-test gap pattern across 13 tasks; observed mid-80s expected
  pass-rate carried by LLM residue (judgment), not proxy gate (encoded constraints).
- **trajectory:** divergent — every gap we found was underspecification recovered by convention; the
  numerical residue (~15%) is exactly where convention fails to align
- **status:** **CONFIRMED · encoded as scope-of-claim discipline (WORKLOG, PREREGISTRATION §0)**
- **mode/conf:** abduction → 85% (philosophy claim; concretely supported)
- **provenance:** session reframe 2026-05-27

## H₁₀ — Cross-family findings need a soundness round-trip; H₈ inside ≠ H₁₀ outside
- **claim:** mutation thinking has TWO complementary forms with different roles. **H₈ (inside agent):**
  "would my test reject a *plausible-wrong* impl?" — ensures DISCRIMINATION. **H₁₀ (boundary):**
  "would my test reject a *known-good* impl?" — ensures SOUNDNESS. Cross-family review (H₉) can
  over-suggest, and applied findings can introduce over-specification that no same-pass soundness ask
  will catch. The fix is **round-trip the soundness ask on the AUGMENTED gate** — not just on the
  original.
- **null:** the Phase-4 soundness ask runs once, before applying findings, and that's sufficient.
- **perturbation (F₉) executed 2026-05-27:** saturation run — full skill stack (H₁ᵦ + H₇ + H₈ + H₉)
  with no override. Results:
  - Feature-type: **SUBTRACTIVE/SELECTOR** (H₁ᵦ fires correctly without override)
  - 36 tests, 31 fail on clean base (LIVE)
  - M1: **CAUGHT** (`test_combination_blanket_dominates_specific`)
  - M3: **CAUGHT** (`test_nested_regions_lifo_end_pops_inner`)
  - Gold: **2 of 36 tests FAIL** → **UNSOUND**: codex-suggested `test_next_line_skips_blank_comment_and_grouping_only_lines` (over-specified on the agreement-region of grouping tokens) + `test_multiline_statement_with_end_inside_statement` (codex finding #7 — over-specified the multi-line + mid-statement-end interaction)
  - Codex itself made a soundness error on its own finding #13 (reversed metric direction) which the
    agent correctly caught and dropped — *cross-family doesn't make codex right*; it makes codex's
    blind spots different. The agent must filter codex too.
- **trajectory:** divergent — the stack catches the *named* discriminators but drifts unsound on the
  *added* tests. Cross-family expands the surface (good) AND introduces speculative tests (bad if
  unfiltered).
- **architectural finding:** the soundness check in `dsr isolate` (gold-passes-proxy) is the OUTER
  loop's role — the blind agent cannot run it without contamination. So **UNSOUND-on-gold must route
  back to build-tools as a kill report** identifying the failing tests, asking the agent to weaken or
  pull them.
- **status:** open · F₉ data established the asymmetry; skill patch & route patch queued
- **mode/conf:** induction (one decisive perturbation; 2 specific over-spec tests identified) → 80%
- **provenance:** F₉ saturation run 2026-05-27; build-tools-lessons.md `ABDUCTION · F₉`
- **proposed patches:**
  1. build-tools Phase 4: after applying codex findings, **re-run the soundness ask on the
     AUGMENTED gate** — for each NEWLY-ADDED test, "does the PRD plainly require this? If not, move
     to residue, don't keep in the gate." Round-trip until stable.
  2. dsr / verify-spec: a new verdict route — `NOT_RESOLVED — proxy-unsound` (gold-passes-proxy
     fails) routes to **build-tools** (not implement-spec; the gate is wrong, not the implementation)
     with the failing test names attached.

## H₉ — Adversarial cross-family iteration beats self-iteration on the same gaps
- **claim:** an iteration loop that brings in a **different model family** (codex / gemini)
  adversarially reviewing the design doc + proxy gate catches gaps a single-model self-iteration (H₇)
  or self-discipline (H₈) cannot, because architectural and training-corpus differences produce
  different blind spots. Claude misses test_35's identical-blanket flaw the way it misses everything
  Claude misses; a different family's read on the same artifact finds what Claude is structurally
  blind to.
- **null:** cross-family review just produces louder/slower self-review; same blind spots, more
  tokens.
- **rationale (theory):** [Make No Mistakes](https://june.kim/make-no-mistakes) — "peer review across
  model families is genuinely better; catches different errors per family. Still misses what both
  families miss." The skill ecosystem (codex, gemini, bug-hunt, qa) all encode this: claude generates,
  codex filters. The pattern is consistent. H₉ tests whether it transfers cleanly to the
  design-doc/build-tools layer, where the artifact is a *spec + test suite* not a fix diff.
- **relation to H₇ / H₈:** three different levers on the same compositional gap. H₇ = more passes,
  same model. H₈ = better discipline, same model. H₉ = different model, same discipline. Likely
  STACKABLE — each catches a different blind-spot class. The clean experimental design is the 2×2:
  | | self-discipline | cross-family review |
  |---|---|---|
  | single pass | F (original blind run) | F₉ (this case) |
  | iterated | F₆ (H₇ alone) | F₈ (H₇+H₉) |
- **perturbation (F₈) executed 2026-05-27:** sent F₇'s design-doc + proxy gate (the most-disciplined
  Claude artifact: iteration + H₈ mutation thinking) to codex (gpt-5.5) for adversarial review.
  Codex returned 18 concrete findings, each with a discriminating input shape. Applied just **one**
  (#16: blanket region + inline `# nosec` → resolved-set classification → metric counts `nosec`,
  not `skipped_tests`) as a supplementary test. Decisive cross-table:
  | proxy | M1 (blanket-dominance metric) | M3 (LIFO nesting) |
  |---|---|---|
  | F₆ iteration alone | CAUGHT | MISSED |
  | F₇ iter + mutation-thinking | MISSED | CAUGHT |
  | **F₇ + codex supp (1 finding)** | **CAUGHT** | **CAUGHT** |
- **trajectory:** divergent supporting. Cross-family review closed the complementary single-model gap
  with a single applied finding. Gold still SOUND (26/26 pass). The other 17 codex findings target
  gaps neither M1 nor M3 surface (operator coverage `|`/`&`/`!`/parentheses, selector-grammar
  fallback, multi-line statement edges, comment/semicolon/ellipsis skip rules) — cross-family
  *expands the surface*, doesn't just close the named gap.
- **status:** **STRONGLY CONFIRMED.** Cross-family adversarial review catches structurally what
  same-model disciplines do not, and finds gaps the local kill-condition perturbations don't even
  name. The bug-hunt/qa pattern transfers cleanly to the design-doc/build-tools layer.
- **mode/conf:** induction (one decisive 2×2-closing perturbation) → 90%
- **provenance:** F₈ codex review 2026-05-27; build-tools-lessons.md `ABDUCTION · F₈`
- **encoded:** build-tools should add an explicit codex-volley step on the proxy gate (find tests that
  don't discriminate; find compositional behaviors the design doc missed). Patch queued.

## H₈ — Enumerating a criterion ≠ writing a discriminating test (mutation-thinking gap)
- **claim:** the test-construction skill is distinct from the criterion-enumeration skill. A
  combinational criterion can be correctly named yet tested with an input shape where the rule and a
  plausible mutation produce the *same* observable output. The missing skill is **mutation thinking**
  at test-design time: for each criterion, ask *"what is the simplest plausible implementation that
  satisfies the criterion's name but violates the rule? Does my test setup distinguish it?"* — and
  iterate the input shape until the answer is yes.
- **null:** enumerating the criterion is sufficient; tests built from the criterion's textual statement
  generally discriminate.
- **evidence (from F₆ inspection):** the iterated agent enumerated criterion 35 ("Nested regions
  follow LIFO") and wrote `test_35_nested_regions_lifo` — but with **identical blanket regions**
  (both `# nosec-begin` no selector). Under LIFO, first end closes inner → outer blanket still
  suppresses. Under FIFO (M3 mutation), first end closes outer → inner blanket still suppresses. Same
  effective output either way: the test cannot distinguish by construction. Canonical's
  `test_018_region_lifo_close_reveals_outer_set` uses *different specific selectors* on outer/inner
  (the name says it: "reveals outer SET" — different sets is the whole point).
- **mechanism named:** the agent's test was built from the *name* of the rule ("LIFO") rather than
  from the rule's *observable consequence* (LIFO causes a *different residual set* than FIFO when
  selectors differ). Property: testing for a rule that distinguishes between alternatives requires
  inputs in which the alternatives observably diverge. Identical-blanket inputs are in the
  *agreement region* of LIFO and FIFO.
- **perturbation (F₇) executed 2026-05-27:** dispatched blind subagent with H₈ mutation-thinking
  discipline + iteration + surface-view override. Result vs F₆:
  | | F₆ (iteration only) | F₇ (iteration + mutation thinking) |
  |---|---|---|
  | M1 (blanket-dominance metric) | **CAUGHT** (test_41) | MISSED |
  | M3 (LIFO end-pop, different selectors) | MISSED | **CAUGHT** (test_regions_nest_lifo_with_different_selectors) |
- **trajectory:** divergent, but **the two disciplines catch DIFFERENT subsets of the compositional
  gap**. The H₈ agent wrote `test_regions_nest_lifo_with_different_selectors` with outer B404 / inner
  B602 — exactly the discriminating shape — and caught M3 cleanly. But its blanket-dominance/metric
  test (criterion 27) was input-setup-insufficient on M1 (probably no findings actually generated by
  the test fixture, so the resolved-set difference is unobservable).
- **status:** **CONFIRMED as a real lever, but does not subsume iteration.** Mutation thinking
  surfaces discriminating *inputs* for an enumerated rule; iteration surfaces enumerated *rules*.
  Each agent's focus introduced a different blind spot.
- **second-order finding:** even with mutation thinking, the test's input must actually *exercise*
  the rule's code path (generate the relevant findings). H₈ closes the agreement-region gap but not
  the path-coverage gap — a third skill exists.
- **mode/conf:** induction → 80% (one decisive perturbation: M3 caught where F₆ missed)
- **provenance:** F₇ blind subagent 2026-05-27; build-tools-lessons.md `ABDUCTION · F₇`
- **encoded:** build-tools Phase 2 now mandates per-test discriminating-test discipline (name a
  plausible-but-wrong impl, ensure inputs distinguish it).

## H₇ — Iteration helps translate PRD → design spec (the inner-encoding-loop hypothesis)
- **claim:** the design-doc → proxy-gate translation improves when the agent **iterates at the design
  phase** (draft from PRD → re-read PRD critically against the draft, asking *"what behaviors emerge
  from combinations of these rules that I haven't enumerated?"* → revise). The first pass extracts
  obvious per-directive PRD rules; the second pass surfaces the **compositional/nested behaviors**
  that arise from rule *interactions*. The mid-80s grade-pass target (from earlier analysis) is partly
  bounded by how well an agent translates spec to criteria — iteration moves that ceiling.
- **null:** single-pass design-doc is operationally sufficient; iteration doesn't change which
  criteria the agent enumerates, just polishes prose.
- **connection to H₁ᵦ:** complementary. H₁ᵦ catches combinational rules via correct *classification*
  (SUBTRACTIVE branch directs attention there); H₇ catches them via explicit *iteration* even when
  classification fires wrong. Both target the per-directive→compositional gap; either mechanism alone
  may suffice. Whether both stack additively is its own sub-question.
- **connection to the trilogy:** the encoding loop ([Encoding Expertise](https://june.kim/encoding-expertise))
  applied *inside* the design-doc phase as a sub-cycle, not just across pipeline runs. Each iteration
  is a sample → evidence → revise; observed PRD behaviors that didn't fit the first criteria-set
  become new criteria.
- **perturbation (frontier · F₂):** re-run a blind subagent on bandit with an EXPLICIT design-doc
  iteration phase — (1) draft from PRD, (2) re-read PRD with the draft in hand asking the
  combinational question, (3) revise. Then re-run the M1 mutant (blanket-dominance under nesting). If
  the iterated proxy catches M1, **H₇ confirmed**; if it still misses, the gap is deeper than design-
  phase iteration can reach (classification or expressivity, not effort).
- **predicted trajectory:** divergent supporting on the strong reading (iteration catches M1);
  oscillatory if it catches some compositional rules but not others (in which case H₇ refines into a
  "which combinational rules are reachable from iteration alone" sub-question).
- **perturbation (F₆) executed 2026-05-27:** dispatched a blind subagent with **EXPERIMENTAL OVERRIDE
  (use surface view, not purpose-over-surface)** + **mandatory iteration phase** (draft v0 → re-read
  PRD asking the combinational question → revise to v1). Single variable: iteration. Results:
  | | original blind run (v0) | iterated blind run (v1) |
  |---|---|---|
  | Feature-type | ADDITIVE (surface) | ADDITIVE (held by override) |
  | criteria | 30 | 48 (+14; agent self-rated 10 load-bearing / 4 polish) |
  | M1 (blanket-dominance under nesting) | MISSED | **CAUGHT** (test_41_blanket_dominance_for_metric_classification) |
  | M3 (LIFO end-pop nesting) | MISSED | MISSED (#35 "nested LIFO" criterion enumerated but its test didn't exercise M3's path) |
  | SOUND+LIVE | yes | yes (25 fail on base, 8 sound-already-green; gold passes) |
- **trajectory:** OSCILLATORY — iteration catches some compositional rules (M1) but not others (M3).
  Refines into: iteration *adds* combinational criteria the agent recognizes as deserving runnable
  tests (criterion 41 was load-bearing), but whether the *test* for an enumerated criterion actually
  exercises the right code path is a second skill problem (criterion 35 was enumerated but didn't
  discriminate M3). Two failure modes visible at the design-doc-iteration layer.
- **status:** **PARTIALLY CONFIRMED.** H₇ is a real lever (caught a load-bearing compositional rule
  classification alone wouldn't have). Not a complete substitute for H₁ᵦ.
- **H₁ᵦ + H₇ relationship:** **COMPLEMENTARY, not redundant.** They catch overlapping but non-
  identical subsets of the compositional gap. Best practice: keep both. Skill patch proposed —
  design-doc gets an explicit Phase 4.5 (combinational re-read).
- **mode/conf:** induction (1 perturbation, 2 informative mutants split — 1 caught, 1 missed) → 70%
- **provenance:** F₆ subagent 2026-05-27; build-tools-lessons.md `ABDUCTION · F₆ iteration`

## H₆ — Economy of search: golden patch substitutes for implement-spec
- **claim:** in the inner loop, **apply gold → run verify-spec on the proxy gate** isolates
  build-tools quality without paying the expensive implement-spec search.
- **null:** measurement requires running implement-spec end-to-end.
- **perturbation:** `dsr isolate` and `dsr inner` run gold through the proxy gate in seconds; no
  implementation generated.
- **trajectory:** divergent — measurement happens at zero implementation cost
- **status:** **CONFIRMED · operational**
- **mode/conf:** deduction (the golden patch is correct-by-construction) + induction (loop runs in
  seconds) → 95%
- **provenance:** dsr.py `cmd_inner` + `cmd_isolate`; first run 2026-05-27

---

## Frontier edges (open hypotheses; each is the next perturbation)

- ~~**F₁ — replication on a transform-type task.**~~ **CLOSED (oscillatory).** Ran bandit; trajectory
  split H₁ into H₁ₐ/H₁ᵦ. SOUND+LIVE confirmed (H₃ n=2), but classification mis-fired. The new
  frontier edge is **F₁′ — distinguish H₁ₐ vs H₁ᵦ** via 2-3 over-suppression-targeted mutants on
  bandit (predicted classification: divergent — proxy catch-rate near canonical confirms H₁ₐ; many
  misses confirm H₁ᵦ).
- **F₂ — per-behavior mutant sweep on httpx.** Build the remaining 5 mutants (ndjson_bom_after,
  document_invalid, streaming_chunks, ndjson_non_utf8, json_seq_non_utf8); run `dsr vary` on each;
  tally proxy-vs-canonical agreement → a per-behavior discriminating-power map. *Predicted: all
  DISAGREE with proxy-PASS / canonical-FAIL — the residue is residue.*
- **F₃ — is KNOWN_BAD truly empty across the 113?** Sample more tasks and verify each subagent-claimed
  "spec contradicts test" against the actual PRD; pattern is dasel-shaped over-reads. *Predicted:
  empty or very small (≤ 2/113).*
- **F₄ — SOUND+LIVE first-try rate across N tasks.** H₃ replicated to a population. *Predicted:
  high for additive (~80%+), unknown for subtractive.*
- **F₅ — name-mapping coverage rate vs grade-green pass-rate.** Does ~83% name-coverage track with
  the mid-80s grade-pass prediction? Run a full inner-loop pipeline (with implement-spec) once and
  measure both numbers on the same task. *Predicted: yes within ~5%.*
- **F₆ — H₇ test: iterated design-doc on bandit.** Blind subagent with explicit iteration phase
  (draft → re-read PRD for combinational rules → revise), then re-run M1 mutant. *Predicted: M1
  caught → H₇ confirmed; M1 still missed → gap is deeper than iteration can reach.*

- **F₁₂ — H₀′ corpus replication.** Repeat the F₁₁ classification on httpx and 2 more tasks. Predict
  the proportions are stable (compositional ≈ 40-45%, path/fixture ≈ 20-30%, breadth ≈ 15-20%). If
  proportions shift dramatically across tasks, the class distribution is task-dependent and a
  different organizing axis is needed.

- **F₁₃ — path/fixture discipline (open hypothesis Hₐ₁).** For each proxy test, the agent must
  verify the input setup actually generates findings the rule's code path touches; not just *names*
  the rule. Per-test "what observable change does this trigger? does my fixture produce it?" Add to
  build-tools as a Phase-2-bis check. *Predicted: closes the path/fixture 25% slice partially —
  see how many of the unencoded canonical tests fall once this is applied.*

- **F₁₄ — breadth/interface discipline (open hypothesis Hₐ₂).** When the PRD enumerates an interface
  surface (operator set, keyword variants, separator characters), the proxy must include a test per
  element of the enumeration. Add to build-tools as an explicit "interface enumeration" sub-phase.
  *Predicted (after F₁₂): closes the largest corpus class (41% weighted); the highest-priority
  unbuilt component.*
  - **Pre-registration (2026-05-27, before run):** substrate = `kysely-window-grouping-helpers`
    (corpus-classified 71% breadth, 78 canonical tests, subtractive transform). Single-variable
    perturbation: add a mandatory "interface enumeration" sub-phase to build-tools Phase 2 — *for
    each PRD enumeration of operator/keyword/method/variant surfaces, write one test per element,
    PRD-quote per test.* No other changes. Pipeline: design-doc → build-tools (patched) →
    `dsr isolate` for SOUND+LIVE → `dsr compare` for breadth-slice catch-rate.
  - **Kill conditions** (decided before measurement):
    - **CONFIRMED** if proxy breadth-slice catch-rate ≥ 50% on the enumerated surfaces named in
      kysely's PRD (groupBy variants, single-bound shorthands, two-sided starters × completers,
      exclusion modifiers, ranking accessors, value accessors, respect/ignoreNulls), AND
      gold-passes-proxy holds (SOUND).
    - **REFUTED** if proxy breadth-slice catch-rate < 25% (the discipline isn't doing the work) OR
      gold-fails-proxy (the discipline drives over-specification — same failure shape as F₉).
    - **OSCILLATORY** between 25–50% → enumeration is helpful but the slice has compositional
      sub-structure the discipline alone doesn't reach; refines into a sub-question about which
      enumerations are reachable from the PRD's surface listing.
  - **What would refute Hₐ₂ as a class:** if catch-rate is high but gold fails, breadth-as-discipline
    is over-counting — the PRD enumerates the *interface* but the residue is some elements'
    *semantics*. That's a structurally different finding than the H₁₀ over-specification failure
    and would split Hₐ₂.
  - **Result (2026-05-27, post-run):** **CONFIRMED on-axis.** Blind subagent produced proxy gate
    with **43/57 tests (75%) per-element** for enumerated surfaces. `dsr isolate` reported
    SOUND+LIVE. Targeted-ablation catch-rate **6/6** mutants:
    | M | what | class | proxy | mechanism |
    |---|---|---|---|---|
    | M1 | rename `excludeTies()` method | breadth | CAUGHT (1 fail) | per-element test #36 |
    | M2 | rename `cumeDist` impl | breadth | CAUGHT (build fail) | TS interface check |
    | M3 | rename `groupByGroupingSets` impl | breadth | CAUGHT (build fail) | TS interface check |
    | M4 | `cume_dist` → `cume_distt` string typo | breadth (behavior) | CAUGHT (1 fail) | per-element test #44 asserts emitted SQL |
    | M6 | invert `hasOrderBy` in default-frame detection | compositional | CAUGHT (3 fail) | preserve-set per-element tests |
    | M7 | over-strip ROWS/GROUPS frames | compositional | CAUGHT (2 fail) | preserve-set per-element tests (#12, #13) |
    No gold-fails (no H₁₀-shape over-specification this run, unlike F₉ on bandit).
  - **Mode/conf:** induction (1 task, 6 mutants, 6/6 caught + SOUND) → **on-axis 78** (kysely is
    the breadth-anchor task; this is the discipline's natural training distribution). Population
    confidence **unearned** until cross-task replication on a *non*-breadth-dominant task. Status
    matches H₁ᵦ's discount logic: on-axis confidence is real; off-axis claims wait for F₁₂-shape
    replication.
  - **Second-order finding:** the preserve-set in the SimplifyFramePlugin section of the PRD reads
    as compositional ("preserve any extent that uses ROWS, GROUPS, exclusion, non-default bounds,
    expression offsets") but the agent encoded it as an enumeration — one test per preserve
    category. That re-encoding turned **compositional preservation into per-element coverage**,
    and M6/M7 were caught by those same tests. Hypothesis Hₐ₂′ (new frontier): a class of
    compositional rules whose preservation conditions are listed as an enumeration are reachable
    from the breadth discipline, not the compositional one. Predicted overlap → F₁₂-style
    reclassification of the corpus once this lens is applied.
  - **What didn't get tested:** path/fixture slice (Hₐ₁, F₁₃) is still untouched. Kysely has ~0%
    path-slice per F₁₂; happy-dom/opa are the substrates that would actually stress that axis.

- **F₁₄′ — off-axis replication of Hₐ₂ on opa.** Substrate:
  `opa-rego-rule-profiling`. **METHODOLOGY CORRECTION (post-run):** F₁₂'s "opa 50% path" entry was
  for `opa-template-string-reconstruction`, a *different* task. opa-rego-rule-profiling was never in
  F₁₂. So this isn't actually an off-axis test against F₁₂; it's a second on-axis run on an
  unclassified task whose PRD happens to be enumeration-rich. The substantive findings still hold
  (Hₐ₂ caught 6/6, spurious-enum identified, F₁₂-class vs PRD-shape separation observed) but the
  cross-axis claim is unearned until a *truly* F₁₂-classified non-breadth task is run. Question: when the PRD
  doesn't lay out a flat enumeration, does the interface-enumeration sub-phase (a) sit silent
  because no enumerations trigger it, (b) over-fire and inflate the gate with irrelevant per-element
  tests (gold-fails → unsound), or (c) help unexpectedly because some path/fixture rules are
  phrased enumeratively in the PRD (Hₐ₂′-shaped reachability)?
  - **Pre-registration:** same single-variable setup; only build-tools differs from F₁₄.
  - **Kill conditions:** **CONFIRMS Hₐ₂′ generality** if the patched stack produces SOUND+LIVE with
    ≤ 30% of tests being per-element (the discipline self-suppressed because the PRD lacked
    enumerations to expand). **REFUTES the patch's neutrality** if gold fails (over-specification:
    the discipline over-counted enumerations not actually flat). **OPENS Hₐ₃** if per-element tests
    cover some-but-not-all path/fixture canonical tests at < 30% catch-rate on path-class mutants —
    discipline didn't hurt but also didn't help, motivating an adaptive gate.
  - **Result (2026-05-27, post-run):** **OUTCOME mixed-(a)/(c) — discipline fired and helped, but
    F₁₂'s class label didn't predict its firing.** opa's PRD is enumeration-shaped (17 EvalProfile
    methods + parallel nil-receiver behaviors) despite F₁₂ classifying its CANONICAL tests as
    path-dominant. The agent produced 38/53 per-element tests (72%); SOUND+LIVE; 6/6 mutants
    caught. **Discipline-credit breakdown** (who wrote the test that caught each mutation):
    | M | mutation | class | who caught |
    |---|---|---|---|
    | M1 | Stat nil-receiver guard removed | breadth | Hₐ₂ per-element |
    | M2 | SuccessRate zero-evals guard removed | spurious-enum tri-state | Phase 4.5 (H₇) |
    | M3 | Merge both-nil guard removed | breadth × tri-state | mixed (Equal/Diff) |
    | M4 | HotRules `[]` instead of `nil` | breadth post-condition | Hₐ₂ per-element |
    | M5 | Skip Evals++ on EnterOp | path/fixture (state-machine) | Phase 4.5 (H₇) |
    | M6 | Packages skip sort+dedup | breadth post-condition | Hₐ₂ per-element |
    Hₐ₂ ≈ 50% (3/6), Phase 4.5 ≈ 33% (2/6), mixed 17% (1/6). Complementary, not redundant. The
    path/state mutation (M5) was caught by H₇ Phase 4.5, not Hₐ₂ — the disciplines split the work.
  - **Three new findings ranked by importance:**
    1. **F₁₂ classifies canonical tests, Hₐ₂ fires on PRD shape — these are different axes.** opa
       was F₁₂-classified path-dominant 50% / breadth 0%, but its PRD is enumeration-rich. The
       discipline-trigger predicate is NOT the F₁₂ class. **This refutes the version of Hₐ₃ that
       gates on canonical-test class.** Hₐ₃'s real predicate is "PRD enumerates a flat set" —
       observable from the PRD alone, which is good (no peek).
    2. **Spurious enumeration is a real failure mode.** Three methods on opa (Merge, Equal,
       RuleStat.SuccessRate) look enumerable but have tri-state PRD semantics. The agent caught
       this in Phase 4.5; if Hₐ₂ fired alone (no Phase 4.5), the gate would have under-
       discriminated. **Patch needed:** build-tools interface-enumeration sub-phase should ask
       "are all elements semantically uniform?" before fanning out — and route non-uniform ones
       to per-case expansion. Bank as F₁₄″.
    3. **Mutation thinking applies to the experimenter.** First M4 was a no-op mutation (Go nil-
       slice + `var result []string` + no appends = nil regardless of the explicit guard). The
       proxy "missed" it but it didn't mutate. Real M4 was caught instantly. **Lesson:** before
       claiming a coverage gap, verify the mutant changes observable behavior on the canonical
       suite first.
  - **Mode/conf:** induction (1 second task, 6 mutants, mixed-discipline credit) — joint
    on-axis confidence for Hₐ₂ ↑ **82** (n=2 tasks, 12 mutants, 12/12 caught net of methodology
    error). **Population: still discounted to 60** — 2 tasks both have enumeration-heavy PRDs;
    a PRD-WITHOUT-enumeration task (e.g., bandit's compositional anchor or any state-machine
    feature) hasn't been run with the new patch yet. The honest negative test is still pending.

- **F₁₆ — composer skill for transform-invariant PRDs (Hₐ₄).** oxvg blind run produced SOUND+LIVE
  with 8/8 tests but missed 2/2 structural-pseudo mutations (`:first-child` removal, `:nth-child`
  removal — gold supports 6 structural pseudos: first/last/only-child, nth-child, nth-last-child,
  :empty; proxy covers none of them). The agent inferred 4 combinator axes from PRD's "structure-
  dependent" cue but did NOT enumerate pseudos because the PRD never names them. **The composer's
  job is exactly this:** given an invariant-shaped PRD, *enumerate the surface where the invariant
  must hold* — including surface elements the PRD does not name, by reading the codebase's existing
  supported axes. Distinct from Hₐ₂: Hₐ₂ enumerates surfaces the PRD already lists; Hₐ₄ enumerates
  surfaces the PRD *implies* via the invariant statement.
  - **Proposed shape:** separate skill (per user direction), routed by Hₐ₃'s PRD-shape predicate.
    PRD has flat enumeration → build-tools (Hₐ₂/H₈). PRD is transform invariant / compositional
    rule → composer skill. Both share the typed-acceptance protocol and discriminating-test
    discipline; composer adds *codebase-surface enumeration* as its load-bearing step.
  - **Contract (sketch):** input = design doc with invariant criteria. Output = paired control/
    perturbation tests across an *inferred* surface matrix (combinator × pseudo × attribute-
    selector × ... × invariant-clause). Each test must (a) state the invariant clause, (b) name
    the surface element under test, (c) name a plausible-wrong impl that violates only this
    element, (d) build inputs where the wrong impl produces a *different* observable.
  - **Why a separate skill, not a build-tools sub-phase:** the load-bearing step (surface inference
    from codebase) is structurally different from Hₐ₂'s PRD-listing read. Sharing Phase 2 with
    interface-enumeration would create the same prose-overload F₉/codex-sniff caught in build-tools
    Phase 4. Cleaner separation: routing predicate + separate skill, both with the same testing-
    discipline siblings.
  - **What this would close:** the oxvg-shaped slice of the corpus — F₁₂'s compositional-only
    tasks (oxvg 40%, bandit 42% partial, opa-template 25%). Unmeasured but candidate-large.
  - **Status (2026-05-28):** **encoded.** `skills/compose/skill.md` written; design-doc patched
    to emit `FEATURE-SHAPE:` (`enum` | `invariant` | `mixed`) as Hₐ₃'s concrete predicate; RUNBOOK
    routes accordingly. Hₐ₄ moves open → encoded; measurement still pending.

- **F₁₆′ — first measured run of `compose` on oxvg.** Single-variable perturbation: replace
  build-tools with compose on oxvg-structural-selector-preservation (same task that produced the
  Hₐ₄ gap evidence). Predicted artifacts:
  - `surface-matrix.md` enumerating ≥ 6 structural pseudos + 4 combinators + attribute-selector
    operators + functional pseudos (`:is`, `:where`) from `style.rs`.
  - Proxy gate paired control/perturbation tests across the matrix.
  - SOUND + LIVE on isolate.
  - The two ablations that previously missed (`:first-child` removal, `:nth-child` removal) are
    now caught.
  - **Kill conditions:**
    - CONFIRMED Hₐ₄ if both pseudo mutations caught AND SOUND.
    - REFUTED if gold fails (over-specification — surface matrix invented axes the codebase
      doesn't actually require).
    - PARTIAL if one of the two caught (axis enumerated but tests don't discriminate — H₈ gap
      inside compose, not a refutation of the surface-inference step).
  - **Result (2026-05-28, post-run + verified):** **machinery works, evidence corrected.**
    Compose blind run: FEATURE-SHAPE=`invariant`; surface-matrix.md enumerated 6 axes / 28
    elements (4 combinators + 11 structural pseudos + 4 functional pseudos + 7 attr-operators +
    external-anchor + locality) with provenance to `parcel_selectors-0.28.2/parser.rs`. Phase 3
    trimmed to 8 SOUND+LIVE tests because gold-vs-pre-fix were behaviorally equivalent on the
    other 20 axes.
    Targeted ablations against compose proxy: M-first-child MISSED, M-nth-child MISSED.
    **Verification step (the correction):** canonical (10 hidden tests) also passes both
    mutations 10/10. The "mutations" don't observably change behavior; gold's pseudo handling
    isn't load-bearing for canonical. So compose's trim was *correct soundness logic*, not a
    coverage hole. The session's "Hₐ₄ gap measured on oxvg" claim was the experimenter's H₈
    — second time this session.
  - **Status:** machinery 80 (built, sound, integrated); case 30 (oxvg is not the right
    substrate — the mutations that name the breadth-via-pseudos slice aren't canonical-load-
    bearing here). Frontier: find a task where invariant-axis surface inference is genuinely
    necessary for catching canonical-load-bearing mutations. Bandit's `:nth-child`-shaped
    cases (selector operators inside `# nosec` directives) are a candidate; replication
    pending.

- **F₁₄″ — spurious-enumeration filter (Hₐ₂'s next refinement).** Sub-phase patch to build-tools:
  before fanning out an enumeration into N tests, ask *"are all N elements semantically uniform
  per the PRD?"* If 1+ element has tri-state / multi-clause / non-uniform semantics, route it to
  per-case expansion (M tests for that element, M ≥ 2). The opa run caught this manually via
  Phase 4.5 but the load-bearing step should be in Phase 2's interface-enumeration sub-phase
  itself. *Predicted:* without F₁₄″, a future task with a Merge-/Equal-shaped enumeration will
  under-discriminate.

- **F₁₅ — adaptive miss-class discipline (open hypothesis Hₐ₃).** F₁₂ showed task-specific dominant
  class varies widely (compositional / path / breadth all dominate different tasks). A single
  universal stack can't capture this. **Design-doc should read the PRD shape and predict which class
  will dominate**, then route to the matching discipline (much like Feature-type classification). The
  cue is shape-recognizable: enumerations in the PRD → breadth-dominant · multiple-rule-clauses with
  interaction language → compositional-dominant · code-path-state-machine language (chunks, async,
  state) → path/fixture-dominant. *Predicted: an adaptive design-doc that names the *probable miss
  class* per task closes the variance the universal stack cannot.*

- **F₁₆ — meta-lesson worth banking.** F₁₂ was itself the right methodology: codex sniff caught the
  unstated assumption → user observed "we overfit" → corpus sweep measured the actual distribution
  → result decisively refuted the strong claim while preserving the on-axis findings. The audit-post
  pattern (require receipts before publishing) applied at the methodology layer. Codex + sweep is the
  general pattern: any claim built on n=1 should be sniffed and then swept before being trusted.

## Graph state
| node | status | shape | confidence |
|---|---|---|---|
| H₀ closed-negative overbuild | REFINED → H₁ | divergent (single-task) | retired |
| H₁ feature-type decision tree | OSCILLATORY → H₁ₐ/H₁ᵦ split | divergent then split | 82 rule / classification reliability open |
| H₁ₐ discipline > classification | KILLED (pruning log) | divergent against | retired |
| H₁ᵦ tree ordering invites surface match | CONFIRMED on-axis · skill patched | divergent | on-axis: 82 (4 mutants, 1 task); **population: 55** (overfit-discounted) |
| H₂ underspec not contradiction (KNOWN_BAD empty) | CONFIRMED (limited sampling) | divergent | 87 (ded, narrow corpus) |
| H₃ encoded skill → SOUND+LIVE first try | CONFIRMED (n=2, distinct shapes) | divergent | 72 (ind, n=2) |
| H₄ misses ARE residue | CONFIRMED (1 mutant) | divergent | 70 (ind, single measurement) |
| H₅ engineering not science | CONFIRMED · scope discipline | divergent | 80 (abd) |
| H₆ economy of search | CONFIRMED · operational | divergent | 92 (ded+ind, narrow validation) |
| H₇ design-doc iteration translates PRD → spec better | PARTIALLY CONFIRMED (caught M1 not M3) | oscillatory | on-axis: 65; **population: 45** (overfit) |
| H₈ enumeration ≠ discriminating test (mutation thinking) | CONFIRMED · encoded · complementary to H₇ | divergent (caught M3, missed M1) | on-axis: 72; **population: 50** (overfit) |
| H₉ cross-family adversarial > self-iteration | STRONGLY CONFIRMED · 2×2 closed | divergent | on-axis: 77; **population: 60** (overfit but cross-family is somewhat axis-agnostic) |
| H₁₀ codex findings need soundness round-trip (H₈≠H₁₀) | open · typed-acceptance protocol patched | divergent (F₉ unsound on gold) | on-axis: 75; **population: 50** (overfit) |
| H₀′ compositional rules dominant | **REFUTED (F₁₂ corpus, n=224)** | divergent against | 80 (ind, refutation) |
| Hₐ₁ path/fixture discipline | open · F₁₃ queued | predicted divergent | 60 (abd, 14% weighted slice) |
| Hₐ₂ breadth/interface discipline | **CONFIRMED on-axis** (kysely+opa+httpx fresh, 13/13 mutants caught, all SOUND) · skill patched · joint credit ~50% with H₇ on opa, ~14% on httpx (8/57 per-element + 7 spurious-enum extras) | divergent | on-axis: **85** (n=3 tasks); **population: 65** (no PRD-without-any-enumeration task tested yet — oxvg is the candidate but not cached) |
| Hₐ₂′ compositional-as-enumeration | CONFIRMED (2 tasks: kysely SimplifyFrame preserve set; opa nil-receiver behaviors) | divergent | 70 (ind, n=2 occurrences) |
| Hₐ₂″ spurious-enumeration (tri-state in enum unit) | **CONFIRMED · skill patched · directly measured on httpx** | divergent | on-axis: **78** (n=2 tasks where it fired — opa via Phase 4.5, httpx via the explicit sub-phase; httpx run produced `test_B12_plus_json_outside_application_rejected` which caught the `media_type.endswith("+json")` mutation that a flat enum would have missed) |
| Hₐ₃ adaptive miss-class predicate | **REFINED — gate on PRD-enumeration shape, NOT F₁₂ canonical class** | divergent | 55 (opa is decisive single counterexample to the canonical-test-class predicate) |
| Hₐ₄ composer discipline for no-enum PRDs | **ENCODED · monoidal** — `skills/compose/` + `build-tools` self-classify in Phase 0; safe to compose in either order; identity on wrong-shape inputs | open · machinery built; case unfound | machinery: 82 (skill written + monoidal contract added); **case for needing it: 30** — original oxvg "gap" refuted by canonical also passing the mutations 10/10 |
| Hₐ₅ monoidal pipeline (skills compose freely) | **ENCODED · audited · manifest schema fixed** | open · contract asserted with concrete schema, not yet measured at runtime | 65 (manifest now has explicit `build_tools`/`compose` slices + union proxy_gate; identity check added to design-doc and implement-spec; verify-spec already monoidal-conformant; double-dispatch on mixed task still untested) |

## Pruning log
- **dasel-html-document-format nested-`<li>` "PRD contradicts test"** (B3-go subagent abduction).
  Killed 2026-05-27 by direct re-reading: PRD's R1 (`li` closes `li`-siblings) + R2 (block closes `p`)
  trace the test's tree exactly. Subagent confabulated. Mechanism that caught it: the audit-post
  verify gate (claim required receipts before publication). Meta-finding: fan-out subagents over-claim
  contradictions; the verify step is load-bearing.
- **H₁ₐ "discipline is sufficient; classification is decorative"** (proposed after F₁ bandit
  misclassification). Killed 2026-05-27 by F₁′ M1 mutant: even though the agent claimed it encoded
  "metric resolution by blanket vs specific," it missed the nested blanket-dominates-specific case
  (test_017/test_018). Discipline catches what the agent looks at; classification directs *what the
  agent looks for*. The SUBTRACTIVE branch's emphasis on "combinational rules" is the difference.

## Reasoning-mode table
- **deduction** (read precisely, trace consequences): H₂ (PRD re-read), H₆ (gold is correct by
  construction). Ceiling 99%.
- **induction** (measure, experiment): H₁ (13-task fan-out), H₃ (blind inner loop), H₄ (mutant), H₆
  (loop timing). Ceiling 95%.
- **abduction** (propose from observation): H₀ (initial anchor), H₃ population estimate, H₅
  (engineering-vs-science framing). Ceiling 85%.

---

**Update rule.** Every new measurement (mutant, fan-out, inner-loop run, retro) updates the graph
before anything else (per /investigate "graph-first on new evidence"). New evidence either: changes a
node's status (+ note in provenance), opens a frontier edge, kills a node (move to pruning log), or
splits an oscillatory node into sub-hypotheses. The graph is the checkpoint; if not written, the
investigation isn't real.
