# build-tools lessons

Inner-loop abduction log (newest appended). The outer loop (supervisor) reads this and patches the skills; the inner loop only executes + abducts.

## 2026-05-27 19:17 · compare/figure · httpx-streaming-json-iteration

canonical=36 ours=0
- MISSED **media** (4): iter_json_accepts_json_media_types, iter_json_rejects_non_json_media_types, iter_json_accepts_ndjson_media_types, iter_json_accepts_json_seq_media_types
- MISSED **document** (12): iter_json_document_bom_inside_array_is_error, iter_json_document_yields_single_value_for_object, iter_json_document_yields_single_value_for_scalars, iter_json_document_yields_array_items_not_array, iter_json_document_empty_is_error
- MISSED **ndjson** (8): iter_json_ndjson_ignores_blank_lines, iter_json_ndjson_line_endings, iter_json_ndjson_bom_only_allowed_on_first_non_blank_line, iter_json_ndjson_bom_disallowed_after_first_non_blank_even_if_first_had_bom, iter_json_ndjson_invalid_line_raises_and_closes_streaming_response
- MISSED **json_seq** (8): iter_json_json_seq_ignores_empty_records, iter_json_json_seq_trailing_empty_record_is_error, iter_json_json_seq_requires_rs_start_after_optional_whitespace, iter_json_json_seq_empty_payload_yields_nothing, iter_json_json_seq_non_utf8_encodings
- MISSED **encoding/charset** (1): iter_json_invalid_charset_is_error
- MISSED **stream-semantics** (3): aiter_json_invalid_closes_response, iter_json_repeatable_for_in_memory_content, iter_json_streaming_sets_stream_closed_on_completion

## 2026-05-27 19:20 · vary · httpx-streaming-json-iteration

patch=`gold`: proxy=n/a canonical=pass — agree

## 2026-05-27 19:23 · outer-loop/canonical-analysis · httpx-streaming-json-iteration

**Negative coverage is closed/enumerated, not exhaustive.** Canonical suite: 19 `raises`
(14 DecodingError, 5 StreamConsumed) + 1 rejection test listing exactly 5 rejected content-types
(text/plain, application/xml, application/jsonp, application/x-www-form-urlencoded, image/svg+json).
No test penalizes over-handling of inputs outside these enumerations.

**Abduced bias (applied to implement-spec): slightly overbuild.** Underbuild fails reliably (every
required positive is tested); overbuild is penalized only against ~5 enumerated negatives. So bias to
overbuild where the spec is silent, but honor PRD-stated hard negatives (+json only under application/,
reject image/svg+json). Patched implement-spec 'completeness over minimalism' -> 'bias to slightly
overbuild' with the asymmetry rationale.

## 2026-05-27 19:33 · CONVERGED · corpus fan-out (13 tasks, codex-filtered) · ALL

**The build bias is conditional on FEATURE TYPE, not a flat "overbuild" (H0 refined).** Fan-out over
13 stratified tasks: H0 (closed negatives → overbuild free) HELD for 9 additive features (httpx, opa,
dasel, kcp, happy-dom, effect-sse, dateutil, mnamer, fd, csstree) and was REFUTED for 4
subtractive/transform/filter/selector features (kysely SimplifyFrame, bandit nosec, oxvg selectors,
testem). Codex filtered the flat "bias to overbuild" as dangerous; the sound invariant is MONOTONICITY
against the grader's observable contract.

**Encoded (implement-spec decision tree):**
1. changes existing behavior for existing inputs → preserve residual first, minimal change;
2. selects/suppresses/removes/simplifies/optimizes/validates/type-checks/ranks/orders/canonicalizes →
   narrow; the PRESERVED/residual set is the real spec; over-acting is graded failure;
3. isolated new method/flag/input, no default-path effect → full stated surface + mechanically-implied
   adjacent cases (completeness pays);
4. crosses a PRD hard negative / compile-negative (@ts-expect-error) / security boundary / exact-output
   format → no extra across it; keep types as narrow as the spec allows.
Also encoded: design-doc now emits a Feature-type line that selects the branch.

**Spec-vs-test gap is pervasive but is UNDERSPECIFICATION, not contradiction** — exact default
spellings (csstree `border-top: solid`→`'medium'`/`'currentcolor'`), exact metrics (bandit test_074
`nosec=1,skipped=0`; kcp exact byte totals), exact formatting (opa residual-query verbatim). These are
the residue: un-encodable from spec, winnable via completeness + judgment, NOT via the proxy gate.

**KNOWN_BAD rule (new no-go class):** if the spec genuinely CONTRADICTS the test (says X, test requires
¬X), binary+no-peek makes it unwinnable → REJECT like the gold-defectives. Outer-loop classification
(needs the test). Gate: rule out a narrower interpretation first. **Set currently EMPTY** — the dasel
nested-li candidate was REFUTED on direct inspection (PRD "same-type siblings" + "block closes p", read
precisely, yield the test's tree; the B3-go subagent confabulated the contradiction). Meta-lesson: the
fan-out's verify step caught a subagent over-claim before it reached the published audit post.

## 2026-05-27 19:40 · isolate · httpx-streaming-json-iteration

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 19:41 · isolate · httpx-streaming-json-iteration

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 19:41 · compare/figure · httpx-streaming-json-iteration

canonical=36 ours=62
- no missed families

## 2026-05-27 19:42 · INNER LOOP RESULT (oracle measurement) · httpx-streaming-json-iteration

**First blind run with the encoded skill: SOUND + LIVE on first try.** Blind subagent (no test peek)
produced 50-criterion design doc + 62-test proxy gate + 2 dev probes, correctly classified the feature
as ADDITIVE. Oracle isolate: gold passes proxy (sound, no false rejects); base fails proxy (live).

**Semantic coverage vs canonical: ~30/36 behaviors (~83%) by name-mapping, higher when parametrized
cases count.** Compare's keyword family-classifier was misleading (33 tests in 'other' was a bucketing
artifact, not a coverage gap). The agent encoded the JSON-seq three-trailing-sub-case enumeration
EXACTLY (c41/c42/c43 ↔ canonical trailing_rs_only / trailing_rs_lf / trailing_rs_ws_lf) — proving the
PRD's explicit enumerations transfer cleanly.

**Genuine misses (the residue, as the skill predicted):**
- `document_bom_inside_array_is_error` — most spec-derivable of the misses; PRD's "optional UTF-8 BOM"
  at start implies BOM disallowed inside the body, but the negative is not stated
- `ndjson_bom_disallowed_after_first_non_blank_even_if_first_had_bom` — subtle composite
- `document_invalid_is_error` — malformed-JSON body, distinct from empty/trailing-non-ws
- `document_streaming_chunk_boundaries`
- `ndjson_non_utf8_encodings`, `json_seq_non_utf8_encodings` — cross-format combinations

**Teaching candidate (small):** design-doc could add a precise-reading nudge — *"optional X at position Y
implies X is not allowed at any other position; derivable as a certain criterion."* Captures the
document_bom_inside_array miss. Possibly too narrow to generalize; flag as a candidate, do not commit
without seeing it recur in a second iteration.

**No skill patch this round.** SOUND+LIVE on first try with ~83% semantic coverage is the encoded
skill working. The remaining gap is exactly the underspecification residue we have not (and per the
necessary-not-sufficient rule, should not) attempt to encode into the proxy gate.

## 2026-05-27 19:45 · compare/figure · httpx-streaming-json-iteration

canonical=36 ours=62
- no missed families

## 2026-05-27 19:45 · ABDUCTION · targeted mutant on gold · httpx-streaming-json-iteration

**High-quality abduction at maximum resolution: one repo, one targeted mutant, sharp signal.**
Mutant = gold with `_allow_bom` guard removed in `_skip_ws_and_bom` (lines 174 & 309 of gold) → BOMs
silently consumed mid-document. Measurement:
- proxy gate: 82 passed (FULL PASS — missed entirely)
- canonical: 1 failed / 107 passed — `DID NOT RAISE httpx.DecodingError` at test_json_stream.py:113,
  precisely `test_iter_json_document_bom_inside_array_is_error`

**DISAGREE — proxy missed; gap localized to ONE canonical test.** This is the targeted-mutation
discriminating-power measurement: each mutant breaks one behavior; canonical/proxy agreement per mutant
gives a per-behavior coverage map far sharper than name-mapping. The behavior is what we already
flagged as "the most spec-derivable miss" — PRD's "optional UTF-8 BOM" at start implies BOM disallowed
elsewhere; the blind agent didn't encode the implication.

**Reframed test classification (industry-familiar).** Replaced the keyword family-bucketer
(media/document/ndjson/json_seq/encoding/stream) with `unit / integration / e2e`. Shape, not behavior —
generalizes across the corpus and reads naturally to engineers.

## 2026-05-27 19:56 · isolate · bandit-structured-nosec-directives

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 19:57 · isolate · bandit-structured-nosec-directives

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 19:57 · compare/figure · bandit-structured-nosec-directives

canonical=0 ours=30
- no missed families

## 2026-05-27 19:58 · compare/figure · bandit-structured-nosec-directives

canonical=78 ours=30
- no missed families

## 2026-05-27 20:00 · INNER LOOP RESULT · F₁ replication (bandit) · bandit-structured-nosec-directives

**Mixed signal: H₃ replicates, H₁ classification miss observed.**

H₃ (encoded skill → SOUND+LIVE first try): **CONFIRMED for n=2.** 30-test proxy on 30 of 37 criteria;
gold passes proxy (sound, no false rejects); base fails proxy (live). Replicates across feature types.

H₁ (feature-type decision tree): **CLASSIFICATION FAILED, OUTCOME OK.** Agent classified bandit as
ADDITIVE despite the corpus-validated SUBTRACTIVE/FILTER ground truth. Reasoning: "Three new directive
keywords... no existing input shape changes meaning" — took the SURFACE view (new methods = branch 3)
rather than the EFFECT view (suppression = branch 2). Skill's branch 2 explicitly names "bandit nosec"
as the canonical example, but the agent matched branch 3 first.

**Outcome was still SOUND+LIVE** because the agent locked down PRD-stated hard negatives as proxy
assertions (blanket-dominates, exact-metric-classification, ignore-nosec respected). Hard-negative
discipline carried it, not the classification.

**Coverage thinner than httpx:** 30 proxy tests vs 78 canonical (~38%) vs httpx's 30/36 (~83%). The
agent deferred 9 of 37 criteria to residue (operator precedence, dedent-on-blank, malformed-expr
fallback tokenization, glob>prefix, none-metric-side-effect, exact warning text). Those are exactly
the kind of edges canonical's 78 tests would cover.

**One targeted mutant attempted** (gold − blanket-dominance branch in tester.py): both proxy and
canonical passed. Not enough to differentiate — either no canonical test exercises that exact path
with shaped inputs, or the mutation collapses to a behavior canonical doesn't distinguish. Sample
size too small to conclude.

**Open hypothesis split (graph update needed):**
- H₁ₐ: feature-type classification is decorative; hard-negative-locking discipline does the work.
- H₁ᵦ: classification matters but the decision tree's ordering invites surface-view matches.
Distinguishing these needs: more mutants on subtractive features that probe over-suppression specifically.

## 2026-05-27 20:33 · ABDUCTION · F₁′ mutants on bandit (H₁ split resolved) · bandit-structured-nosec-directives

**Two targeted mutants resolved the H₁ split in favor of H₁ᵦ (classification matters).**

- **M1** — `_union` blanket-dominance killed in `bandit/core/nosec.py` (replace `if not a or not b: return set()` with `if False:`). Effect: nested blanket-inside-specific resolves to specific. **Proxy 30/30 PASS, canonical FAIL** (test_017_region_blanket_overrides_specific + test_018_region_lifo_close_reveals_outer_set). **DISAGREE — proxy missed the compositional rule.**
- **M2** — directive-line made retroactive (`start_line = line` instead of `line + 1`). **Proxy FAIL, canonical FAIL** (test_082 + test_begin_directive_line_itself_not_suppressed). **AGREE — both caught it.**

**Pattern:** the agent encoded **simple per-directive PRD negatives** ("directive line not suppressed" is one PRD sentence — caught by M2) but missed **compositional / nested resolution rules** (blanket-dominance under nesting requires reasoning about combined regions — missed by M1). Exactly the boundary the SUBTRACTIVE branch's "exhaust combinational rules" wording targets.

**H₁ₐ killed; H₁ᵦ confirmed; skill patched.** implement-spec decision tree now has a precedence rule ('purpose over surface' — branch 2 wins over branch 3 on conflict). design-doc Feature-type emit block mirrors. **The encoding loop ran end-to-end this iteration**: blind run → mutant abduction → graph update → skill patch.

## 2026-05-27 20:41 · ABDUCTION · F₁′ extended (M3/M4/M6) — H₁ᵦ → 95% · bandit-structured-nosec-directives

Three more mutants on bandit gold. Tally now:

| M | class | prediction | proxy | canonical | result |
|---|---|---|---|---|---|
| M1 nested blanket-dominance | compositional | DISAGREE | PASS | FAIL (test_017+018) | ✓ |
| M2 `nosec-begin` retroactive | per-directive | AGREE | FAIL | FAIL (test_082+) | ✓ |
| M3 LIFO end-pop → FIFO | compositional | DISAGREE | PASS | FAIL (test_018) | ✓ |
| M4 auto-end-on-dedent disabled | compositional | DISAGREE | PASS | PASS | inconclusive null |
| M6 `re.IGNORECASE` removed | per-directive | AGREE | FAIL | FAIL (test_098+) | ✓ |

**4/4 informative mutants match prediction.** Pattern replicated → H₁ᵦ to 95%.

M4 (null) is informative as the residue boundary AT THE TAIL: agent flagged auto-end-on-dedent for blank/comment lines as residue (criterion 20), and canonical agrees by omission — no canonical test exercises that path either. The residue boundary holds from BOTH sides on that edge.

## 2026-05-27 20:49 · isolate · bandit-structured-nosec-directives

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 20:51 · ABDUCTION · F₆ iteration test — H₇ partially confirmed · bandit-structured-nosec-directives

**Iteration alone caught some compositional rules but not all.** Single-variable experiment: same task (bandit), same hard read-forbids, same surface-view ADDITIVE misclassification (held by experimental override of the H₁ᵦ patch). Only difference: mandatory design-doc iteration phase (draft → re-read PRD for combinational behaviors → revise).

Results:
- criteria: v0=30, v1=48 (+14; agent self-rated 10 load-bearing / 4 polish)
- M1 (blanket-dominance under nesting): original MISSED → iterated CAUGHT (test_41_blanket_dominance_for_metric_classification)
- M3 (LIFO end-pop nesting): original MISSED → iterated still MISSED (criterion #35 enumerated but its test didn't exercise M3's path)
- SOUND+LIVE preserved

**H₇ partially confirmed (70% induction):** iteration IS a real lever — it caught a load-bearing compositional rule that classification alone wouldn't have. Not a complete substitute for H₁ᵦ.

**H₁ᵦ + H₇ are COMPLEMENTARY, not redundant.** They catch overlapping but non-identical subsets of the compositional gap. Both encoded into the skills: implement-spec keeps the purpose-over-surface precedence rule (H₁ᵦ); design-doc gets a new Phase 4.5 "Combinational re-read" (H₇).

**Second finding (the agent's framing):** enumerating a combinational criterion doesn't guarantee a test that *exercises* the right code path. The agent surfaced criterion 35 (nested LIFO) but its proxy test didn't distinguish M3. So design-doc iteration is a NECESSARY-not-sufficient lever; the test-construction skill still matters.

## 2026-05-27 21:35 · isolate · bandit-structured-nosec-directives

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 21:37 · ABDUCTION · F₇ result — H₈ confirmed as COMPLEMENTARY lever · bandit-structured-nosec-directives

**Mutation-thinking catches what iteration alone misses, and vice versa.** Decisive cross-table:

| | M1 (blanket-dominance metric) | M3 (LIFO end-pop, different selectors) |
|---|---|---|
| F₆ iterated proxy | CAUGHT (test_41) | MISSED |
| F₇ iter + mutation-thinking proxy | MISSED | CAUGHT (test_regions_nest_lifo_with_different_selectors) |

Mutation thinking IS a real lever (H₈ at 80%). The H₈ agent wrote a discriminating-shape test with outer B404 / inner B602 that F₆'s iteration didn't produce. But its blanket-dominance test (criterion 27) was likely input-setup-insufficient on M1 — no findings actually generated by the test fixture, so the resolved-set difference is unobservable.

**Second-order finding:** even with mutation thinking, the test's input must actually EXERCISE the rule's code path (generate the relevant findings). H₈ closes the agreement-region gap; a *path-coverage* gap (does the test setup actually trip the rule?) remains. A third skill exists.

**Encoded:** build-tools Phase 2 now mandates per-test mutation-thinking (name a plausible-wrong impl; ensure inputs distinguish it; comment in source).

**Frontier reshuffled:** H₉ (cross-family adversarial review) is now the obvious next perturbation — it's the natural candidate for catching what either single-model discipline misses, given their complementary gaps are now empirically established.

## 2026-05-27 21:48 · ABDUCTION · F₈ — H₉ strongly confirmed (90%) · bandit-structured-nosec-directives

**Cross-family adversarial review closes the 2×2 with a single applied finding.**

F₇'s proxy (Claude iteration + mutation thinking) → codex (gpt-5.5) adversarial review → 18 concrete findings. Applied just ONE — finding #16: blanket region + inline `# nosec` → metric resolved-set classification → counts `nosec` not `skipped_tests` — as a supplementary test.

Result table:
| proxy | M1 (blanket-dominance) | M3 (LIFO nesting) |
|---|---|---|
| F₆ iteration | CAUGHT | MISSED |
| F₇ iter + mutation-thinking | MISSED | CAUGHT |
| F₇ + codex finding #16 | CAUGHT | CAUGHT |

Gold still passes (26/26 SOUND). The 17 other codex findings target gaps neither M1 nor M3 surface — operator coverage (`|`, `&`, `!`, parentheses), selector-grammar fallback, multi-line statement edges, comment/semicolon/ellipsis skip rules. **Cross-family review expands the surface, not just closes the named gap.**

**Lever summary across H₇/H₈/H₉ (corpus-validated, bandit single task):**
- H₇ iteration (~70%) — surfaces enumerated *rules* via second-pass PRD reread
- H₈ mutation thinking (~80%) — surfaces discriminating *inputs* for enumerated rules
- H₉ cross-family review (~90%) — catches what same-model disciplines structurally miss + finds gaps neither local mutant surfaces

**Encoded:** build-tools Phase 4 now mandates a codex cross-family review with three asks (soundness + discrimination + missing coverage). Same-model self-iteration alone is insufficient on subtractive features.

## 2026-05-27 22:06 · isolate · bandit-structured-nosec-directives

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 22:06 · compare/figure · bandit-structured-nosec-directives

canonical=78 ours=36
- no missed families

## 2026-05-27 22:08 · ABDUCTION · F₉ saturation — stack catches both mutants, drifts unsound · bandit-structured-nosec-directives

**Full skill stack (H₁ᵦ + H₇ + H₈ + H₉) on bandit, no overrides — moment of truth result.**

- Feature-type classified as **SUBTRACTIVE/SELECTOR** without override (H₁ᵦ fires correctly)
- 36 tests, 31 fail on clean base (LIVE)
- M1 (blanket-dominance metric): **CAUGHT** by `test_combination_blanket_dominates_specific`
- M3 (LIFO nesting): **CAUGHT** by `test_nested_regions_lifo_end_pops_inner`
- Gold: **2 of 36 tests FAIL → UNSOUND.** `test_next_line_skips_blank_comment_and_grouping_only_lines` + `test_multiline_statement_with_end_inside_statement` over-specify what gold actually does. Both came from codex findings #3 and #7.

**Two new findings worth banking:**

1. **H₁₀ (new):** mutation thinking has two complementary forms — H₈ inside the agent ('does my test reject a plausible-wrong impl?' → discrimination) vs H₁₀ at the boundary ('does my test reject a known-good impl?' → soundness). Cross-family review (H₉) can over-suggest; the Phase-4 soundness ask run BEFORE applying findings doesn't catch the over-spec the agent INTRODUCES from codex. Fix: round-trip the soundness ask on the AUGMENTED gate. **Encoded** in build-tools Phase 4.

2. **Cross-family doesn't make codex right.** Codex finding #13 had the metric direction reversed (`!none` would yield blanket); the agent caught it because it filtered. Cross-family adds DIFFERENT blind spots, not NO blind spots. The agent must filter codex too.

**Architectural finding:** `dsr isolate` (gold-passes-proxy) is the OUTER loop's role — a blind agent cannot run it without contamination. So UNSOUND-on-gold must route back to build-tools as a kill report identifying the failing tests for the agent to pull or weaken. New verdict route candidate: `NOT_RESOLVED — proxy-unsound` → build-tools.

**Net:** the stack works on the discriminating signal but needs one more discipline (H₁₀) to not over-shoot. The 2 over-spec tests are isolated and identifiable; the fix is a single mandatory phase, not an architectural rebuild.

## 2026-05-27 22:11 · OUTER LOOP · codex sniff on the session's architecture · ALL

**Codex (gpt-5.5) sniffed the full hypothesis graph + four refactored skills. Five findings, all land.**

1. **Confounded perturbations.** H₇/H₈/H₉ confounded with criterion count, applied-finding selection, agent stochasticity (single run per condition). H₃ also confounded — SOUND+LIVE may be task friendliness, not encoded skill. Acknowledged in graph; honest caveat.

2. **Confidence inflation.** Mass downgrade applied: H₁ᵦ 95→82; H₃ 92→72; H₄ 95→70; H₉ 90→77; H₂ 95→87; H₆ 95→92; H₇ 70→65; H₈ 80→72; H₁₀ 80→70. Codex was systematically right that small-n inductions had ceiling problems.

3. **Skill prose drift.** build-tools Phase 4 was overloaded (three asks + caveats + round-trip + filtering). Rewritten as a **typed-acceptance protocol** with an explicit table (ENTAILMENT / DISCRIMINATOR / SPECULATION / WRONG) — agent must type every finding before acting.

4. **Missing meta-hypothesis (codex's sharpest catch).** H₀′ added: *compositional/residual-rule coverage is the dominant failure mode once obvious PRD criteria are encoded.* This is the background assumption all of H₁ᵦ/H₇/H₈/H₉/H₁₀ depend on. If false, patches are over-fit to one miss class. F₁₁ queued — classify bandit's 78 canonical tests by miss class to test this.

5. **H₁₀ critique — strongest finding.** The round-trip doesn't fully fix F₉: the agent that judges PRD entailment is the same family anchored by codex's suggestions. The deeper problem: applying-codex-findings lacks a **typed acceptance protocol**. Each finding needs classification (entailment/discriminator/speculation/residue/wrong), not another soundness prompt. This is the patch above.

**Meta-finding: the codex sniff itself worked.** Cross-family critique caught what I (Claude, same family that produced the session) was systematically anchored on — confidence numbers were the clearest case. The pattern is consistent with H₉'s thesis at the meta layer.

## 2026-05-27 22:15 · OUTER LOOP · F₁₁ corpus classification (H₀′ partially refuted) · bandit-structured-nosec-directives

**Codex's catch was right. The dominant-failure-mode claim doesn't hold.**

Classified all 77 bandit canonical tests by miss class:
- compositional: 32 (42%) — nested regions, region+inline, dominance, metric resolved-set, multi-rule
- path/fixture: 19 (25%) — Windows newlines, midline, comment-trailer, multi-line, blank/comment/ellipsis/grouping skips, indent boundaries
- breadth/interface: 13 (17%) — selector operators (|, &, -, !, parens, glob, fallback), separators, whitespace, case
- plain/atomic: 11 (14%) — per-directive isolated
- baseline/regression: 2 (3%) — ignore_nosec, legacy preservation

**Compositional IS the largest single class (42%) but path/fixture (25%) + breadth (17%) = 42% combined.** Co-equal in aggregate. The session's patches (H₁ᵦ, H₇, H₈, H₉, H₁₀) all target compositional. They are necessary but not sufficient for a complete proxy.

**Two new discipline axes opened:**

- **Hₐ₁ path/fixture discipline** — for each proxy test, the agent must verify the input setup actually generates findings the rule's code path touches. Not just naming the rule. Per-test: "what observable change does this trigger? does my fixture produce it?" (Codex finding #1 in F₈ was exactly this — invalid syntax prevented the expected finding.)

- **Hₐ₂ breadth/interface discipline** — when the PRD enumerates an interface surface (operator set, keyword variants, separator characters), the proxy needs a test per element. Mechanically simple, easy to forget without an explicit checklist.

**Meta-finding worth banking:** codex's sniff didn't just correct confidence numbers — it surfaced an unstated background assumption that, once tested, partially refuted itself. The codex-volley pattern works at the architecture layer too.

## 2026-05-27 22:16 · META · OVERFIT named (user observation) · ALL

**The session was train+test on the same axis. Names it: compositional rules.**

Lineage:
1. H₀ anchored on httpx (closed-negatives + compositional edges).
2. Bandit chosen *because* corpus-confirmed SUBTRACTIVE/filter — same axis.
3. Probe mutants M1 (nested blanket-dominance), M3 (LIFO end-pop) — both compositional.
4. Every patch (H₁ᵦ, H₇, H₈, H₉, H₁₀) targets compositional gaps.
5. F₉ saturation validated against the same compositional signal.
6. F₁₁ corpus classification revealed 42% non-compositional surface (path/fixture + breadth) untouched.

**Graph updated with on-axis vs population confidence.** On-axis (the compositional patches DO catch compositional misses on the training task) is real. Population (will these patches generalize?) is unearned. Discounted ~20-25 points across H₁ᵦ/H₇/H₈/H₁₀.

**Hₐ₁ (path/fixture discipline) and Hₐ₂ (breadth/interface discipline)** were named via F₁₁ specifically to be off-axis additions. They're predicted-helpful but UNTESTED.

**Methodology hygiene: F₁₂ (cross-task corpus replication) must run BEFORE further skill patching.** Without a different feature shape + class distribution as evidence, more patches just deepen the overfit.

The overfit pattern is itself a corpus-level finding worth bank ing: agents iterate on one task, find a class of misses, patch against it, validate against same task — high-confidence-feeling product that doesn't generalize. The audit's thesis applied at the methodology layer.

## 2026-05-27 22:26 · F₁₂ WIDER SWEEP · corpus refutes H₀′; breadth dominates · CORPUS (n=224, 6 tasks)

**The wider sweep was the right move. Result decisively refutes the session's strong claim.**

Aggregate (weighted, n=224 across 6 tasks):
- Breadth/interface: 41% ← LARGEST corpus class
- Compositional: 32%
- Path/fixture: 14%
- Plain/atomic: 12%
- Baseline: 2%

Per-task dominant class:
- bandit (subtractive/filter): compositional 42% [SESSION ANCHOR — outlier]
- opa (additive): path/fixture 50%
- httpx (additive): compositional 33% (mild, balanced)
- happy-dom (additive): breadth 63%
- kysely (subtractive transform): breadth 71%
- oxvg (subtractive selector): compositional 40%

**Three findings:**

1. **Breadth/interface, not compositional, is the dominant class** across the corpus by both weighted and unweighted aggregation. The session's patches (H₁ᵦ/H₇/H₈/H₉/H₁₀) all target the second-largest class.

2. **Feature type does not predict dominant class.** kysely (subtractive transform) is 71% breadth — not the predicted compositional. happy-dom (additive) is 63% breadth — not the predicted plain/atomic. The mapping is task-specific, not feature-type-determined.

3. **Per-task variance is wide** (breadth ranges 0%-71% across tasks). A universal discipline cannot cover the corpus. The design-doc skill needs an ADAPTIVE step that predicts the dominant miss class from PRD shape, then applies the matching discipline.

**Highest-priority unbuilt component (Hₐ₂):** breadth/interface discipline. 41% of weighted corpus surface, currently zero patches targeting it.

**Meta-lesson:** the audit-post pattern (require receipts) applied at the methodology layer worked. Codex sniff → user-observed overfit → wider sweep → empirical refutation. The session's compositional patches are real on the compositional axis; their generalization claim is now empirically discounted, with concrete corpus distribution as the receipt.
