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

## 2026-05-27 22:43 · isolate · kysely-window-grouping-helpers

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 22:44 · isolate · kysely-window-grouping-helpers

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 22:45 · isolate · kysely-window-grouping-helpers

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 22:46 · isolate · kysely-window-grouping-helpers

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 22:46 · compare/figure · kysely-window-grouping-helpers

canonical=0 ours=0
- no missed families

## 2026-05-27 22:49 · vary · kysely-window-grouping-helpers

patch=`solution`: proxy=pass canonical=pass — agree

## 2026-05-27 23:10 · F₁₄ · Hₐ₂ CONFIRMED on-axis · kysely-window-grouping-helpers

**First cross-axis perturbation. The breadth-discipline patch lands on its predicted slice.**

Single-variable perturbation: added an "Interface-enumeration discipline" sub-phase to build-tools Phase 2 *before* the discriminating-test discipline. When a criterion lists ≥ 2 surface elements, write N tests, one per element, PRD-quoted. Nothing else changed.

Substrate: `kysely-window-grouping-helpers` — corpus-classified 71% breadth (F₁₂), subtractive transform feature, 77 canonical tests.

Blind subagent ran design-doc → build-tools. Output:
- design-doc: 54 v0 → 57 v1 criteria
- build-tools: **57 proxy tests, 43 from interface enumeration** (75%)
- `dsr isolate`: **SOUND + LIVE**

Outer-loop targeted ablations — 6/6 caught:
| M | class | mechanism |
|---|---|---|
| M1 rename `excludeTies()` | breadth | per-element test fired |
| M2 rename `cumeDist` impl | breadth | TS interface check (build fail) |
| M3 rename `groupByGroupingSets` impl | breadth | TS interface check |
| M4 `cume_dist`→`cume_distt` (behavior) | breadth | per-element test asserted SQL substring |
| M6 invert `hasOrderBy` (default detect) | compositional | preserve-set per-element tests |
| M7 over-strip ROWS/GROUPS frames | compositional | preserve-set per-element tests |

**Two findings worth banking:**

1. **Hₐ₂ on-axis works exactly as predicted.** Catch-rate 6/6 (target was ≥ 50%); no gold-fails (no F₉-shape over-spec); structural element coverage on every PRD-enumerated surface (3 frame modes, 5 single bounds, 4 starters, 5 completers, 4 exclusions, 6 ranking, 5 value accessors, 3 group helpers). On-axis confidence 78%. Population unearned; replication on a non-breadth-dominant task (e.g., opa or oxvg, both path/compositional-dominant per F₁₂) is the next perturbation.

2. **Hₐ₂′ — compositional preservation as enumeration.** The SimplifyFramePlugin's "preserve" clause reads as a compositional rule but the agent encoded it as a 5-element enumeration (preserve ROWS / GROUPS / exclusion / non-default-bounds / expression-offset). M6 and M7 were compositional mutants, both caught by those per-element preserve tests. So *some* compositional rules whose preservation conditions are list-shaped in the PRD are reachable from the breadth discipline. This suggests F₁₂'s class boundaries aren't crisp — the breadth/compositional split is a function of *how the PRD phrases it*, not the rule's logical shape. Worth re-examining the F₁₂ classifications under this lens.

**Methodology note:** `dsr compare` is Python-only (parses `def test_*`), useless for JS/TS targets. Used direct mocha + grep instead. Worth widening dsr's parser later; not a blocker.

**No-peek invariant held.** Blind subagent did not read tests/, solution/, or any lab log. Outer loop measurements (`dsr vary` + targeted ablations) are the legitimate retrospective step.

**What would refute or weaken:** running the same patched stack on opa (path-dominant 50%) and watching the per-element discipline either (a) help nothing because path/fixture is structurally different — expected — or (b) hurt by inflating the gate with irrelevant breadth tests, in which case the discipline needs an Hₐ₃-shaped predicate ("PRD enumerates a surface → apply; PRD describes a state machine → don't").

## 2026-05-27 23:18 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:20 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:20 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:21 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:22 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:23 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:24 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:25 · isolate · opa-rego-rule-profiling

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:26 · vary · opa-rego-rule-profiling

patch=`solution`: proxy=pass canonical=pass — agree

## 2026-05-27 23:55 · F₁₄′ · Hₐ₂ off-axis test on opa-rego-rule-profiling — fires on PRD shape, not F₁₂ class

**The clean refutation of the F₁₂-class-as-Hₐ₃-predicate hypothesis.**

Substrate: `opa-rego-rule-profiling` — F₁₂-classified path-dominant 50%, breadth 0%. Predicted Hₐ₂ would sit silent. **Result: Hₐ₂ fired heavily.** Agent produced 38/53 per-element tests (72%) because the PRD enumerates 17 EvalProfile methods + parallel nil-receiver behaviors. SOUND+LIVE confirmed. 6/6 targeted ablations caught.

**Discipline credit (who wrote the test that caught each mutant):**
- M1 Stat nil-receiver guard removed → Hₐ₂ per-element
- M2 SuccessRate zero-evals guard removed → Phase 4.5 (H₇) [spurious-enum tri-state]
- M3 Merge both-nil guard removed → mixed (Equal/Diff per-element)
- M4 HotRules `[]` not `nil` → Hₐ₂ per-element
- M5 Skip Evals++ on EnterOp (path) → Phase 4.5 (H₇) C2/C3
- M6 Packages skip sort+dedup → Hₐ₂ per-element

Hₐ₂ ≈ 50%, H₇ ≈ 33%, mixed 17%. Complementary, not redundant. **The path/state mutation (M5) was caught by H₇, not Hₐ₂.** The disciplines split the work cleanly.

**Three earned findings:**

1. **F₁₂ class ≠ Hₐ₃ predicate.** F₁₂ classifies CANONICAL TESTS; Hₐ₂ triggers on PRD SHAPE. opa is enumeration-rich in PRD but path-rich in canonical (an under-tested canonical may be the cause). Whatever Hₐ₃'s adaptive gate becomes, the trigger must be PRD-shape-recognizable — which is fine, the agent reads PRD anyway, no peek required.

2. **Spurious enumeration (Hₐ₂″).** Three opa methods (Merge, Equal, RuleStat.SuccessRate) look like uniform enumeration units but have tri-state PRD semantics. Agent caught this in Phase 4.5; if Hₐ₂ fired without H₇ followup the gate would have under-discriminated. **Patch applied:** build-tools interface-enumeration sub-phase now has a mandatory spurious-enumeration check ("are all N elements semantically uniform?") before fan-out. List of known spurious patterns encoded.

3. **The experimenter's H₈.** First M4 (`if len(result) == 0 { return nil }` removed) was semantically equivalent — Go's nil slice + `var result []string` + no appends already returns nil. The proxy "missed" it, but the mutation didn't mutate. Real M4 (`result := []string{}`) caught instantly. Mutation thinking applies to measurement, not just gates. Bank as methodology.

**Status updates:**
- Hₐ₂ on-axis confidence ↑ 78 → **82** (n=2 tasks now, 12/12 effective mutants).
- Population still discounted **60** — both kysely and opa have enumeration-rich PRDs. A PRD-without-enumeration task (state-machine or transform feature) hasn't been run with the patched stack yet. The honest negative test is still pending.
- Hₐ₂′ (compositional-preservation-as-enumeration) confirmed twice: kysely's SimplifyFrame preserve set + opa's nil-receiver method enumeration. Both look compositional in logical shape but were PRD-listed as flat enumerations, and Hₐ₂'s discipline reached them.
- Hₐ₃ predicate **refined**: gate on PRD-enumeration shape, NOT F₁₂ canonical class. opa is the decisive counterexample to the original predicate.

**What's left to learn cheaply:**
- A PRD-WITHOUT-enumeration task is the next obvious perturbation. Bandit's PRD has a small enumeration (3 directives + 7 selector operators) but is mostly compositional — would Hₐ₂ over-fire or stay quiet? (Already has a baseline from F₉ saturation; the patched stack can re-run.)
- The full pipeline run (with implement-spec) to measure proxy-green vs grade-green delta on kysely or opa. Currently zero implementations run; the H₆ economy-of-search optimization has not been spent down yet.

**Meta-lesson worth banking.** Two perturbations on the same patch (kysely on-axis, opa off-axis) produced complementary findings: kysely confirmed the patch lands as predicted; opa surfaced Hₐ₂″ (spurious) and refined Hₐ₃'s predicate. Cross-task replication isn't just about boosting confidence — it surfaces *different* refinements per task. The codex sniff + sweep pattern from earlier in the session generalizes: every patch deserves one off-axis test before population claims.

## 2026-05-27 23:35 · isolate · httpx-streaming-json-iteration

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:42 · isolate · httpx-streaming-json-iteration

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:30 · F₁₄″ · spurious-enum sub-phase fires + caught a real shape on httpx

**Third blind run, fresh from clean container/manifest deleted, with the F₁₄″ patch in place.**

Substrate: `httpx-streaming-json-iteration` — F₁₂'d balanced (33% comp / 25% plain / 22% breadth / 19% path). The most balanced corpus task.

Blind subagent output: 51 criteria; **57 proxy tests; SOUND + LIVE**. Composition:
- 8 per-element coverage (5 content-type families + 3 NDJSON line endings)
- **7 spurious-enum splits** (json-seq trailing-record taxonomy, json-seq middle-empty, json-seq empty-payload, charset-detection BOM-vs-codepoint, content-type negative split into 4 distinct rejection mechanisms)
- 8 compositional / path-state
- 34 straight 1:1 criterion-test

**The agent explicitly named the spurious-enum applications.** Two are paradigmatic:

1. **json-seq trailing-record taxonomy** — PRD: "RS alone, RS+LF, RS+whitespace+LF" — one criterion, three structurally different byte patterns. A naive flat-enum would have written one "malformed trailing record raises" test, satisfied by an impl that checks `record.strip() == ""` after a single `rstrip('\n')`. Splitting into 3 tests forces the impl to dispatch correctly per pattern.

2. **Content-Type negative split** — PRD enumerates several non-JSON content-types as failure cases. A flat-enum "non-allowlist raises DecodingError" test is satisfied by an impl that does `endswith("+json")` without checking the `application/` tree — it correctly rejects `text/plain` but incorrectly accepts `image/svg+json`. Splitting into B8 (non-allowlist), B8b (`text/json` — `/json` but wrong tree), B9 (missing header), B12 (`+json` outside `application/`) forces tree-gated suffix matching.

**Targeted mutation to convert induction → measurement:**
- Mutate gold: `media_type.startswith("application/") and media_type.endswith("+json")` → `media_type.endswith("+json")`.
- Predicted: B12 catches; flat-enum baseline would miss.
- Result: **`test_B12_plus_json_outside_application_rejected` FAILED** as predicted. 1 failed, 56 passed. The split test is the one that caught.

**Confidence updates:**
- Hₐ₂ on-axis: **82 → 85** (n=3 tasks, 13/13 effective mutants caught net of methodology errors).
- Hₐ₂″ spurious-enumeration: open → **CONFIRMED, 78** (direct deductive measurement on httpx).
- Population (Hₐ₂): **60 → 65**. Still discounted: no PRD-without-any-enumeration task tested. oxvg is the cleanest candidate (PRD is pure-prose compositional rule) but its container isn't cached.

**Bookkeeping correction noted (F₁₄′).** I had labeled the opa run as an "off-axis test against F₁₂"; in fact F₁₂'s opa entry referred to `opa-template-string-reconstruction`, a different task. I ran `opa-rego-rule-profiling`, which is not in F₁₂ at all. The substantive findings (Hₐ₂ caught 6/6, spurious-enum exists, PRD-shape ≠ canonical-class) still hold, but the cross-axis-against-F₁₂ claim is unearned. Httpx is the first true F₁₂-classified non-breadth task run with the patched stack.

**Pre-existing-artifact contamination caught.** First httpx attempt re-used the May 27 19:38 (pre-patch) `design-doc.md` and `test_proxy.py` because the blind subagent silently consumed existing files. Mitigation: deleted the artifacts before re-dispatching, and the prompt told the agent the artifacts were cleared. The clean run produced a 57-test gate vs. the contaminated read's 82 — but 82 was pytest-parametrize expansion of fewer functions, so they're not directly comparable. Methodology: when re-running a task, scrub the artifact dir AND tell the subagent it's a from-scratch run.

**Net for the session.** Three on-axis confirmations of Hₐ₂; one direct measurement of Hₐ₂″; three new findings preserved across the run (PRD-shape vs F₁₂ class separation, spurious-enum as a real failure mode, experimenter's own H₈). Population claim STILL UNEARNED — the negative test (PRD with no enumeration) is the obvious next perturbation but doesn't have a cached substrate.


## 2026-05-27 23:59 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-27 23:59 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:00 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:01 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## F₁₆ · oxvg honest negative — Hₐ₂ correctly silent · Hₐ₄ composer gap measured · oxvg-structural-selector-preservation

**The honest negative test. Hₐ₂ stayed silent as predicted; the gap that opens is composer-shaped.**

Substrate: `oxvg-structural-selector-preservation` — PRD is pure-prose transform invariant (5 sentences, no operators/methods/keywords). F₁₂ classified it 40% compositional. Expected behavior of the discipline gate: interface-enumeration sub-phase fires zero times.

Blind subagent output: 9 criteria (7 certain + 2 routed-to-residue for ambiguity); **8 proxy tests; SOUND + LIVE**; **0 per-element tests; 0 spurious-enum splits.** The discriminating-test sub-phase (H₈) carried the gate's design — each test atomized one PRD clause and built paired discriminating inputs against a named plausible-wrong impl.

**Discipline-gate behavior:** correct. The interface-enumeration sub-phase didn't fire because the PRD lacked listings to expand. The skill's predicate worked as designed.

**Measured gap (two missed mutations):**
| M | mutation | proxy | canonical-coverage |
|---|---|---|---|
| M-first-child | remove `:first-child` from `is_structure_sensitive_selector` allowlist | 8/8 PASS — **MISSED** | canonical has `detects_first_child_pseudo` |
| M-nth-child | remove `:nth-child` from allowlist | 8/8 PASS — **MISSED** | canonical has `detects_nth_child_pseudo` (implied) |

Gold supports **6 structural pseudos**: `:first-child`, `:last-child`, `:only-child`, `:nth-child(...)`, `:nth-last-child(...)`, `:empty`. The proxy covers **0** of these because the PRD never names them. The agent inferred 4 combinator axes from PRD's "structure-dependent" cue (C1 descendant, C2 child, C3 adjacent-sibling, C4 general-sibling) but the inference stopped at combinators.

**The gap shape names the missing discipline.** For invariant-shaped PRDs, the surface is NOT enumerated in the PRD; it has to be inferred from the codebase's existing supported axes. oxvg's selector engine supports both combinators AND structural pseudos; the PRD's invariant ("preserve structure-dependent matching") must hold across BOTH. Hₐ₂ enumerates surfaces the PRD already lists. **Hₐ₄ (composer)** enumerates surfaces the PRD *implies* via the invariant — by reading the codebase to find every axis the invariant must hold across.

**Per user direction: composer as a separate skill, not a build-tools sub-phase.** Reasoning:
1. Load-bearing step is structurally different (codebase surface inference vs PRD listing read).
2. Sharing Phase 2 with interface-enumeration risks the prose-overload that codex-sniff caught on Phase 4.
3. Hₐ₃'s adaptive predicate becomes structural rather than imperative: PRD-shape → route to skill.

Proposed contract (sketch only, not yet built):
- **Input:** design doc with invariant criteria; codebase access.
- **Step 1 — Surface inference:** read the codebase for every axis the invariant must hold across (oxvg: combinators + structural pseudos + attribute selectors + functional pseudos like `:is`/`:where`). Build the surface matrix.
- **Step 2 — Paired discriminating tests:** per (invariant-clause, surface-element), construct (control_input, perturbation_input) where a plausible-wrong impl produces a different observable than the correct impl.
- **Step 3 — Spurious-axis check:** are all surface elements semantically uniform under the invariant? If not (e.g. one pseudo has different mechanics), split per-mechanic.
- **Step 4 — Typed-acceptance protocol** (same as build-tools Phase 4): codex volley, ENTAILMENT/DISCRIMINATOR/SPECULATION/WRONG.

**What's left to learn cheaply (session saturation point):**
- Building Hₐ₄ requires designing and testing a new skill — a real next phase, not a perturbation.
- Population claim for Hₐ₂ is now at n=4 with the right shape (3 enum-rich confirmations + 1 no-enum silent-correctness). On-axis 85, population 70 (the no-enum case validated the gate; that strengthens the discipline's bounds).
- F₁₂ class still doesn't perfectly predict Hₐ₂ firing (opa-rego is the standing counterexample) but the *direction* of correspondence holds: enum-rich PRD → Hₐ₂ fires heavily; pure-prose PRD → Hₐ₂ silent.
- Composer skill design + a first build on oxvg would be the cleanest next perturbation.

**Net of session:**
- 4 task validations of Hₐ₂ (kysely, opa-rego, httpx, oxvg).
- 13 effective mutants caught, 2 effective mutants missed — both in the composer-shaped slice.
- 2 skill patches (interface-enumeration sub-phase F₁₄, spurious-enumeration filter F₁₄″).
- 1 new skill proposed (composer / Hₐ₄ / F₁₆).
- 3 methodology lessons banked (experimenter's H₈, artifact contamination, F₁₂ slug confusion).

## 2026-05-28 00:24 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:25 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **UNSOUND**  (sound=False gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:29 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:31 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## 2026-05-28 00:32 · isolate · oxvg-structural-selector-preservation

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)

## F₁₆′ · compose skill encoded + first blind run on oxvg — machinery works, original gap claim refuted

**Built `skills/compose/skill.md`** (~400 lines) as the invariant-shape sibling of build-tools. Load-bearing step: read the codebase to infer the surface where the invariant must hold, writing `surface-matrix.md` with per-axis-element provenance. Same manifest schema as build-tools.

**Routing predicate (Hₐ₃) made concrete** in design-doc Phase 5: `FEATURE-SHAPE: enum | invariant | mixed`. RUNBOOK routes accordingly.

**First blind compose run on oxvg-structural-selector-preservation:**
- FEATURE-SHAPE = `invariant` (chosen correctly)
- Surface matrix: 6 axes, 28 elements with provenance to `parcel_selectors-0.28.2/parser.rs` (combinators, NthType variants including all 11 structural pseudos, functional pseudos, attribute operators, external anchor, locality)
- Initial draft: 28 paired tests → Phase 3 trim → **8 SOUND+LIVE tests**. Agent dropped 20 axes because gold-vs-pre-fix produced behaviorally equivalent outputs on those axes.

**Then: the correction.** I ran M-first-child and M-nth-child against compose's new proxy expecting catches. Both missed. Initial reading: "compose trimmed too aggressively." Verification step: ran the canonical (10 hidden tests) against both mutations. **Canonical also passes both 10/10.** The mutations are inert at the canonical level — gold's pseudo handling isn't load-bearing for canonical tests.

**Implication: this is the experimenter's H₈, second occurrence this session.** First was opa M4 fast-path-removal (semantically equivalent under Go nil-slice rules). Now: oxvg pseudo-list removal (gold's `is_structure_sensitive_selector` isn't reached by canonical's selector shapes). Both times the "gap" wasn't real because the mutation wasn't observable.

**What this corrects:**
- Compose's Phase 3 (spurious-axis check + gold-vs-pre-fix differential) is now corpus-validated as *useful soundness logic*, not as an over-aggressive trim.
- Hₐ₄ machinery confidence stays high (~80): the skill produces a structurally correct surface-matrix.md + manifest + paired tests + SOUND+LIVE gate on first try, on a representative invariant-shape PRD.
- Hₐ₄ *case* confidence drops to ~30: the oxvg gap I claimed previously was inert mutations. The composer is built but its load-bearing necessity hasn't been earned. Need a substrate where invariant-axis mutations are canonical-load-bearing.

**Durable methodology lesson — bank twice now:** before claiming a coverage gap, run the candidate mutation against the canonical suite *first*. If canonical passes too, the mutation is inert and the gap is illusory. This is the same shape as F₉'s codex finding #13 (reversed metric direction) at the agent-side and now twice at the experimenter-side. The H₁₀ "round-trip soundness ask" applies to ablations too.

**Net for the session.** Built compose as a separate skill (per user direction); validated its machinery on oxvg; corrected the originating gap claim by checking canonical; left Hₐ₄'s case as an honest open frontier rather than overclaiming on bad evidence. The artifact pipeline now distinguishes by PRD shape; whether the second branch (compose) earns its complexity is the next perturbation.

## Hₐ₅ · monoidal contract added to build-tools + compose (encoded, untested)

User direction: skills should compose like a monoid — order shouldn't change the manifest, double-application should be idempotent, and wrong-shape input should be a clean identity, not a forced run.

**What changed:**
- `skills/compose/skill.md` and `skills/build-tools/skill.md` each gained a **Phase 0 — Self-classify**. The skill reads the PRD itself (does not trust design-doc's `FEATURE-SHAPE:` hint alone) and decides `applies | partially-applies | does-not-apply`. The sniff rule is symmetric: `enum-count` ≥ 1 with `invariant-count` = 0 → build-tools applies, compose no-ops; mirror for the other direction; both > 0 → both apply on their respective slice; both = 0 → both no-op (PRD is degenerate).
- Phase-N (Phase 6 in compose, Phase 5 in build-tools) emit changed from "write manifest" to "merge manifest" — detect the other skill's slice via `*.applied: true` and merge into a shared `proxy_gate.criteria` list. `proxy_gate.run` concatenates both test files.
- Idempotency: a second invocation of the same skill on the same manifest detects `*.applied: true` and exits clean.
- `RUNBOOK` updated: routing is now *advisory*. The skills self-classify; misrouting is recoverable.

**Contract asserted (not measured):**
- `build-tools` ∘ `compose` = `compose` ∘ `build-tools` (on `mixed`-shape tasks)
- `compose` ∘ `compose` = `compose` (idempotent)
- `build-tools` ∘ `build-tools` = `build-tools` (idempotent)
- On wrong-shape input: identity (clean no-op).

**Why this matters:** the original session had operator-level routing (RUNBOOK + design-doc hint). Skills couldn't be composed safely; running compose on an enum PRD would produce noise, running build-tools on an invariant PRD would silently under-discriminate (the oxvg pattern). The monoidal contract makes the pipeline composable: a user can dispatch both, in either order, and get the same manifest. The first skill applies its slice and writes its slice key; the second skill applies its slice and merges; redundant runs no-op.

**Open frontier (Hₐ₅):** the contract is written but **not measured**. The first task in the corpus that's plausibly `mixed`-shape is httpx (the PRD enumerates content-type families AND has invariant clauses around stream lifecycle / chunk-boundary preservation). A clean test: dispatch build-tools then compose on a fresh httpx run, then re-dispatch compose then build-tools on a parallel fresh run, and verify the two manifests are equivalent up to ordering. Until that runs, monoidality is asserted but not earned.

**The risk pattern this session:** the same one we banked twice (experimenter's H₈). Writing "monoidal" in skill prose doesn't make the implementation behave that way. A skill that says "merge" but actually overwrites would silently violate the contract; only an end-to-end double-dispatch test catches it. Next session.

## Hₐ₅ audit · per-skill monoidal-contract check + obvious fixes

User direction: "audit each skill for its monoidal contract" + "make obvious improvements as you go." Audit table:

| Skill | Identity | Idempotency | Commutativity | Merge | Patches applied |
|---|---|---|---|---|---|
| design-doc | violates (always emits) | partial (graph append duplicates) | n/a (first stage) | violates (append, not dedupe) | + Phase 0 identity check via PRD sha256; emit includes `prd-sha:` + `session:` tags; graph append now session-tagged and dedupe-rule stated |
| build-tools | prose-only | prose-only | prose-only | violates (single write) | + manifest schema rewritten to carry `build_tools` and `compose` slices + union `proxy_gate`; Phase 0 + Phase 5 made concrete (read-merge-write) |
| compose | prose-only | prose-only | prose-only | prose-only | + manifest schema explicit reference to build-tools'; Phase 0 + Phase 6 made concrete (read-merge-write) |
| implement-spec | violates (runs unconditionally) | implicit (Phase 5 re-detects green) | n/a (single stage) | n/a (source not manifest) | + Phase 0 identity check: if proxy green + suite clean on entry, exit clean without editing |
| verify-spec | honors (empty-patch case) | honors (read-only, verdict overwrite is correct semantics) | n/a (terminal) | terminal verdict — overwrite is correct | no change needed |

**Load-bearing fix:** the manifest schema. Before: single `proxy_gate` object; the merge was prose, not structurally possible. After: each skill writes its slice (`build_tools` or `compose`) with `applied`/`path`/`criteria`/`run`; `proxy_gate` is the union, refreshed on every emit. `dsr gate` / `dsr isolate` read only `proxy_gate.run` — they're agnostic to which slice ran. Two runs of the same skill on the same manifest is a no-op (Phase 0 detects `*.applied: true` and exits). Two different skills run in either order produce identical final manifests (up to criteria-list ordering).

**Risks still standing (not yet patched):**
- Sniff-rule reliability. The PRD-shape classifier (`enum-count` vs `invariant-count` from sentence-shape) is named in three skills' Phase 0 but isn't a real parser. Two skills disagreeing on shape would split, with each writing its slice anyway — that's still sound (the union proxy_gate runs both) but it's wasteful and the operator can't tell from the manifest.
- Implementation of "read-merge-write" is prose. A skill that writes naively (overwriting the manifest) would silently violate the contract. Needs an end-to-end double-dispatch test on a mixed-shape task before claiming the implementation matches the spec.

**Confidence:** Hₐ₅ 55 → 65 (the manifest schema is now structurally possible). Still untested at runtime, so the contract is encoded but not earned.

The double-dispatch test on httpx (the likeliest `mixed`-shape candidate) is the obvious next perturbation.

## Hₐ₅ · convergence framing + per-skill cheap perturbations

User direction: "the monoidal contract for nondeterministic LLM skills can just be a convergence guarantee and a tiny dampener. see /humanize for example" + later "i imagine compilers have the same property of exiting out when nothing is left to change at each stage" + "we are building a kind of a prose compiler."

**The frame shift.** LLM output is not bit-stable; strict idempotency is the wrong target. The right contract:
- **Convergence under iteration**: each pass narrows the diff against the fixed point.
- **Dampener**: each pass acts only on what's still inconsistent, leaving stable parts alone.
- **Termination signal**: a pass with zero edits is the fixed point.

This is exactly how compiler optimizer passes work (SCCP / GVN / dead-code-elim / constant-folding all iterate to fixed point on the same IR; `gcc -O3`'s driver iterates the pass pipeline until no pass fires). It's also how `/humanize` is structured: scan, act on what's still wrong, report each cut, exit when re-read finds nothing.

**Re-skilled Phase 0** (all four LLM skills):
- design-doc: prd-sha header → fixed-point fast-path; mismatch or coverage-hole → dampener acts on the diff.
- build-tools: convergence read keeps PRD-quote-matching tests, adds only uncovered criteria, removes only kill-flagged tests; emits `// CONVERGENCE: kept N, added M, removed K` header where `M + K == 0` signals fixed point.
- compose: mirror — convergence read against surface-matrix.md + paired tests; same header shape.
- implement-spec: green proxy on entry → fixed point; partial green → dampener restricts edits to failing-criterion paths.
- verify-spec: read-only, terminal — already monoidal-conformant; verdict overwrite is correct terminal semantics.

**The pipeline as a prose compiler.** RUNBOOK reframed: skills are passes, IR = (design doc + manifest + $PROXY_GATE_DIR), driver iterates until no pass fires. design-doc = parser; build-tools/compose = codegen; implement-spec = optimizer; verify-spec = verifier.

**Cheap perturbations (all 5 passed):**
- A — implement-spec convergence: apply gold to kysely, run proxy gate → 57/57. Phase 0 would correctly identify fixed point. Deterministic; zero LLM calls.
- B — verify-spec idempotency: same input state → same verdict. Trivially passes (read-only + verdict-overwrite-is-correct-terminal).
- C — build-tools convergence: subagent reading skill against `build_tools.applied: true` stub → correctly identifies no-op exit. Cheap LLM dispatch.
- D — compose convergence: subagent reading skill against `compose.applied: true` stub → correctly identifies no-op exit. Same dispatch.
- E — design-doc convergence: subagent reading skill against `prd-sha`-matching stub → correctly identifies `CONVERGED` exit.

**Confidence on Hₐ₅: 65 → 75.** Single-skill Phase 0 dynamics are now verified at one cheap point each. The honest residue:
- **Commutativity** (build-tools ∘ compose = compose ∘ build-tools on mixed-shape) is still untested. Cheapest test: httpx with its existing build-tools artifact + dispatching compose on top, then compare to a fresh "compose first" run.
- **Convergence under LLM noise across multiple full passes** (do two real build-tools runs produce manifests that *actually* converge in 1–2 iterations?) is also untested.

**Bank: prose compiler.** The framing earns its complexity by importing 60 years of compiler-pass design. Fixpoint iteration, dampener, IR, codegen passes, optimizer passes — every term has a well-understood semantic. Future skill design should ask "what compiler-pass shape is this?" before writing prose from scratch.

## Cross-reference · this pipeline is a third prose compiler

User pointer: [Internal Reasoning of Prose Compiler](https://june.kim/internal-reasoning-of-prose-compiler) (June Kim, 2026-05-15) — local source at `~/Documents/june.kim/src/content/blog/2026-05-15-internal-reasoning-of-prose-compiler.md`.

The post names two pipelines that share an IR:
- **sweep** (contributor side): `Issue → PR with embedded receipts`.
- **immune** (maintainer side): `PR → verdict the maintainer reads in 30 seconds`.

Both run the same six-stage Natural Framework substrate (perceive · cache · filter · attend · transmit · consolidate) and pass a **hypothesis graph** between stages: *"prose-shaped so a human can audit it, graph-shaped so a machine can traverse it. Nodes are perturbations, edges are evidence trajectories, leaves carry e-value classifications with provenance back to the artifact each claim came from."*

**This deepswe-run feature pipeline is the third compiler in that family.** It compiles `PRD → grade-green patch`. Same IR shape (the HG), same convergence-under-iteration property, same dampener/fixed-point/legibility properties. Different transport: a benchmark task list rather than GitHub.

What the cross-reference clarifies:
1. The **HG node grammar is canonical**, not a per-project ad-hoc thing. Nodes = perturbations · edges = evidence trajectories · leaves = e-value classifications with provenance. My graph has been informally using this; the header now references the canonical source.
2. The **per-task IR** (design doc + manifest + `$PROXY_GATE_DIR`) and the **cross-task IR** (the HG itself + lessons log) are both *instances of HG*. One scoped to a single PRD; the other to the meta-loop that develops the skills.
3. The **convergence property** isn't a methodology I invented — it's the prose-compiler family's identifying signature, alongside legibility and the typed IR.
4. **Skill development workflow is `(Issue) → PR → merged`** on the skill files in `skills/*/skill.md`. The meta-loop's IR is this graph; the merge gate is whether the patch's measurement confirms the hypothesis.

What stays specific to this pipeline:
- The transport is a benchmark task list (not a GitHub Issue/PR). The artifacts are local files (manifest.json, design-doc.md, surface-matrix.md), not webhook events.
- The verifier is `dsr gate` + `dsr grade`, not a CI label.
- The "human gate" is the operator running `dsr grade` and reading the retrospective oracle — analogous to immune's maintainer-merge gate but at a different point in the loop.

Bank: future skill design for this pipeline should default to **HG-shaped IR** (perturbations/edges/e-value/provenance) and the six-stage substrate. The `compose` skill already fits cleanly (its surface-matrix.md is the perturbation set; the paired tests are the evidence trajectories; SOUND/LIVE is the e-value classification). The other skills should be auditable in the same grammar.

## Hₐ₅ · convergence framing + cheap perturbations (consolidated)

User direction: "the monoidal contract for nondeterministic LLM skills can just be a convergence guarantee and a tiny dampener. see /humanize for example" + "i imagine compilers have the same property of exiting out when nothing is left to change at each stage" + "we are building a kind of a prose compiler" + (HG-is-IR pointer above).

**Re-skilled Phase 0 across the four LLM skills:** prd-sha / applied-flag identity fast-paths; convergence read on existing state (keep stable parts, act only on diff); fixed-point header (`// CONVERGENCE: kept N, added 0, removed 0`) when re-run is a no-op.

**Cheap perturbations — all 5 passed:**
| # | Skill | Test shape | Cost | Result |
|---|---|---|---|---|
| A | implement-spec | apply gold to kysely, run proxy gate | 1 container build, 0 LLM | 57/57 → would print `converged` |
| B | verify-spec | identical state → identical verdict | deterministic substrate (A) | trivially passes |
| C | build-tools | stub manifest with `build_tools.applied: true` | 1 small subagent | correctly identifies no-op exit |
| D | compose | stub manifest with `compose.applied: true` | (same subagent) | correctly identifies no-op exit |
| E | design-doc | hypothetical prd-sha match | (same subagent) | correctly identifies `CONVERGED` exit |

Hₐ₅ confidence 65 → 75 (single-skill Phase 0 dynamics verified at one cheap point each).

Honest residue:
- Commutativity (build-tools ∘ compose = compose ∘ build-tools on `mixed`-shape) still untested at runtime.
- Convergence-under-LLM-noise across multiple full passes (do two real build-tools runs on the same task converge in 1–2 iterations?) also untested. The next obvious perturbation: dispatch build-tools on httpx (already has a build-tools artifact from F₁₄″), expect Phase 0 to fire and produce zero edits.

## Pipeline framing correction · `Spec → Issue or PR`, upstream of sweep

User: "we have (Spec) → Issue or PR · something similar"

Original framing was `PRD → grade-green patch`. The correction: the output is **bimodal** depending on whether the spec admits a clean implementation:

- **RESOLVED** verdict → emit a **PR** (the implementation patch, proxy-green + regression-clean)
- **NOT_RESOLVED — coverage hole** → emit an **Issue** against the spec (which is structurally what sweep consumes)
- **NOT_RESOLVED — criterion unmet / regressions** → emit an **Issue** against the implementation pass
- **REJECTED — PRD unparseable / KNOWN_BAD** → emit an **Issue** to the human bin

This positions the pipeline **upstream of sweep**: sweep's input is an Issue; this pipeline produces one when a Spec doesn't yet admit a clean PR. The verify-spec verdict's "route" field is exactly the Issue/PR discriminator: route=`none` ⟹ PR-ready; route=`design-doc`/`implement-spec` ⟹ Issue against the spec or against the prior implementation pass.

Family map (with positions):
```
Spec ─→ [this pipeline] ─→ Issue ──→ [sweep] ──→ PR ──→ [immune] ──→ verdict / merge
                       └─→ PR ─────────────────────────→ [immune] ──→ verdict / merge
```

The PR-direct path skips sweep when the Spec was clean enough; the Issue path feeds sweep when more work is needed. Either way the artifact crossing the boundary is a typed IR (HG), so the next compiler can audit upstream reasoning without re-encoding.

Updated HYPOTHESIS_GRAPH.md header and RUNBOOK to reflect.

## Framing correction · benchmark-shaped output; commutativity dropped

User: "we are still aiming for benchmark shaped output, commutativity unnecessary"

Walking back the prose-compiler-family positioning overreach. What stays load-bearing:

1. **HG as IR** — still the right abstraction for the internal reasoning that lets us iterate skills.
2. **Convergence + dampener** for LLM-skill Phase 0 — still useful: prevents wasted iterations, makes re-entry safe, and the 5/5 cheap perturbations confirmed it.
3. **The skill-passes pipeline structure** (design-doc → routing → build-tools/compose → implement-spec → verify-spec) — operationally correct.

What gets walked back:

1. **"Spec → Issue or PR · upstream of sweep"** — the deepswe-run pipeline does NOT feed sweep. The output is benchmark-shaped: a patch that `dsr grade` scores against the hidden grader on the DeepSWE corpus. The success metric is **grade-green rate across the 113 tasks**, not "Issue or PR for some downstream compiler."

2. **Commutativity** (`build-tools ∘ compose = compose ∘ build-tools`) — DROPPED. The Hₐ₅ residue item is removed. For benchmark output the order of skill dispatch is fixed by the RUNBOOK; commutativity is an "interesting general property of prose compilers" but not in the "needed for grade-green" bucket. The merge-not-overwrite manifest behavior still matters (so re-entry from verify-spec doesn't lose prior work), but that's a separate property (idempotency for re-entry) not commutativity.

Updated HYPOTHESIS_GRAPH.md header + RUNBOOK to reflect. Hₐ₅ row renamed from "monoidal pipeline" to "convergence + dampener for LLM skills" — drops the inflated property, keeps the earned one.

**Frame check:** the convergence work this session was justified because it makes re-entry safe (verify-spec coverage-hole → design-doc back-edge → design-doc converges to refined criteria → re-dispatch downstream skills doesn't recompute the stable parts). Re-entry is on the benchmark hot path. So the convergence patches earn their keep at the benchmark axis, not at the "general compiler properties" axis.

**What's actually next for benchmark numbers:**
- Population claim for Hₐ₂ at 70 — still needs replication on a task in the middle of the F₁₂ distribution.
- Full pipeline run (with implement-spec) on at least one task to spend H₆ down and measure proxy-green vs grade-green delta. We have zero grade-green measurements this session.
- Audit pattern (codex sniff) on the corpus-fanout claims before trusting them.

## Frame check ×2 · upstream is WIP; no family-membership claim

User: "vision → roadmap → spec are still in the works, we're not quite there yet"

Even the "borrows the prose-compiler shape" framing was a degree too forward. The wider stack (`vision → roadmap → spec → ...`) that would let arbitrary intent become a benchmark-shaped spec isn't built yet. Until it is, this pipeline only consumes pre-existing benchmark PRDs.

Updated HYPOTHESIS_GRAPH.md header + RUNBOOK to:
- Lead with **scope**: input PRD, output patch, metric grade-green rate across 113 tasks.
- **Borrow patterns, don't claim membership.** HG as IR + convergence + dampener are useful internally for re-entry safety. They're not a claim that this is a sibling of sweep/immune in any operational sense.
- Defer family positioning until the upstream chain exists.

Pattern that earns its keep this session, narrow-scoped: **convergence-under-iteration with a dampener makes re-entry safe.** verify-spec coverage hole → design-doc → re-dispatch downstream skills converges without redoing stable work. That's a benchmark-relevant property; positioning claims aren't.

## 2026-05-28 01:23 · isolate · kysely-window-grouping-helpers

build-tools proxy gate: **SOUND + LIVE**  (sound=True gold-passes-proxy, live=True base-fails-proxy)
