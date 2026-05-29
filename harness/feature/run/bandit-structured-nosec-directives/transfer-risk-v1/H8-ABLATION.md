# H₈ ablation — Flash with vs without mutation-thinking discipline

Date: 2026-05-29. Same substrate (bandit), same author (Gemini 3.5 Flash, `--approval-mode plan`), same PRD. Only difference: the prompt either includes (a) PRD-quote, (b) discriminating inputs, (c) axis-crossing, (d) boundary-clause disciplines explicitly, or strips all four.

## Headline metrics

| Metric | with discipline | lean | delta |
|---|---|---|---|
| Test count | 34 | 31 | +3 |
| PRD-quoted docstrings | **100%** | **0%** | **+100** |
| PRD-negative clauses | **100%** | **0%** | **+100** |
| Axis-crossing keyword tests | 18% | 13% | +5 |
| Discriminating-input shape (pos + neg assertion) | 35% | 23% | +12 |

PRD-quoting and boundary-clause discipline are entirely prompt-driven. Flash does NOT internalize them at all on its own — 0% appearance without explicit instruction. Discriminating-input shape is moderately model-driven (~23% baseline) and meaningfully lifted by the discipline (+12 points).

## Qualitative — which tests does discipline add?

Tests present in disciplined but not lean:

| Disciplined-only test | Significance |
|---|---|
| `test_axis_crossing_begin_and_next_line` | The axis-crossing category Hₐ₈ targets. **Also the load-bearing soundness bug codex F1 caught.** Lean would not have this test at all (good for soundness, bad for coverage). |
| `test_nested_active_regions_lifo` | Composer F6 flagged this as over-asserting line-numbers (soundness concern). Disciplined-only adds it, with the soundness flaw. |
| `test_indented_begin_whitespace_basis` | Composer F7 flagged the `assertEqual(issues, [])` as over-asserting. Disciplined-only adds it, with the flaw. |
| `test_optional_selector_no_prefix` | Discrimination of selector-syntax-as-prefix vs as-token. Useful. |
| `test_tokens_separated_by_space_union` / `_by_comma_union` (split) | Disciplined separates two cases that lean rolls into one. |
| `test_metrics_classification_resolved_set` | Disciplined adds the classify-by-resolved-set test (Composer F3, F4 partially flagged metrics arithmetic). |
| `test_next_statement_does_not_leak_subsequent_statements` | Discrimination of "next statement" boundary. Useful — the lean version's `test_next_line_blanket` doesn't put any subsequent statement in the disagreement region. |

Tests present in lean but not disciplined:

| Lean-only test | Significance |
|---|---|
| `test_basic_inline_nosec_metrics` | Sanity check of legacy `# nosec`. Disciplined skipped because PRD focuses on new directives. Defensible omission. |
| `test_region_explicit_end` | A direct test of the explicit-end clause separate from `test_end_terminates_active_region`. Disciplined fused them. |

## The interesting trade-off

**Discipline buys depth AND introduces wrong-confidence soundness bugs.** Three of the disciplined version's uniquely-added tests are the same ones Composer and codex flagged for over-asserting:
- `test_axis_crossing_begin_and_next_line` → codex F1 (soundness, unsound assertion the PRD does not require)
- `test_nested_active_regions_lifo` → Composer F6 (soundness, over-asserts line numbers)
- `test_indented_begin_whitespace_basis` → Composer F7 (soundness, over-asserts empty issues)

So the discipline introduces sophisticated tests AND, in this run, introduced 3 soundness flaws that the lean variant would have avoided by not writing them at all. Net positive only if you have the Phase 3.5 adversary review wired to catch them — which is exactly why we just added Phase 3.5 to the build-tools skill.

This is mechanistically *why* Phase 3.5 (just-added) pays its way. The discipline phase pushes Flash to write the sophisticated tests it would otherwise omit. Some of those will be over-asserting, since discipline doesn't come with built-in soundness verification. Phase 3.5 catches the over-assertions before the impl runs.

## H₈ verdict on the new pair

**H₈ stands, with the caveat that discipline is necessary AND insufficient.** Flash does not internalize the disciplines; the prompt phase is load-bearing for PRD-quoting (+100), boundary-clauses (+100), discriminating inputs (+12), and axis-crossing tests (+5). The discipline phase is therefore paying its tokens — gate quality drops materially without it.

The trade-off worth knowing about: discipline introduces over-assertion in ~10% of new tests it adds (3 of 7 uniquely-disciplined tests on this artifact were flagged by the adversary as over-asserting). This is exactly the failure mode the typed-acceptance Phase 3.5 review addresses.

## Architectural recommendation

Keep Phase 2's full discipline prose. Keep Phase 3.5 (the residue-carrying adversary on the gate). The two work as a system:

1. Phase 2 discipline forces depth that the model wouldn't write on its own.
2. Phase 3.5 catches the soundness slips that depth introduces.

Neither alone is sufficient. Removing Phase 2 → shallow gate, miss real impl-bug-causing axis crossings. Removing Phase 3.5 → over-asserting gate that fails on gold (the F₉ failure mode that motivated the typed-acceptance protocol).

## Open follow-ups

1. **n=2 on kysely.** Run the same ablation on a breadth-dominant additive task. If discipline delta is similar (~+100 quote density, ~+12 discriminating shape), H₈ generalizes. If much smaller, the bandit-class signal may be inflating the result.
2. **Composer-as-author with vs without discipline.** This ablation tested only Flash. The role split has Composer as craft (impl) not author (gate). But Composer has been used as author in earlier fires (partial-v1) and showed first-pass proxy-green — would discipline change that? Unmeasured.
3. **Cost-benefit of the over-assertion rate.** 3 over-assertions per ~7 unique-disciplined tests is ~40% over-assertion rate among the depth additions. Phase 3.5 must catch most of them or the disciplined gate ships unsound. Measured Phase 3.5 catch rate on this artifact: 3/3 (codex F1, Composer F6, Composer F7 — all three flagged). Sufficient.

## Cost ledger

- Flash with discipline: already had (transfer-risk-v1 fire, $0 model spend — gemini free tier)
- Flash lean: 1 run, ~$0 (gemini free tier), ~6 min wall
- Analysis script: $0
- Total marginal: ~$0, ~6 min wall
