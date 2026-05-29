# Composer 2.5 — a working review

A living note. Findings accumulate as the project's harness-richness experiment exercises Composer in more roles (implementer, build-tools author, Phase 4 adversary, baseline single-agent). Most "model reviews" are vibes after one chat session; this one is grounded in measured runs against an actual benchmark substrate (DeepSWE-113), with receipts pointed in `harness/feature/run/`.

Each finding lists: claim → confidence → evidence → caveat. New evidence promotes/demotes confidence in place; refuted claims move to the **Pruned** section at the bottom with the date and the receipt that killed them.

---

## What I'm grading against

- **Substrate:** DeepSWE-113 (gateless feature pipeline, 4 trials per cell on the public leaderboard, see `external/deepswe-leaderboard/`)
- **Roles exercised:** implementer (kysely / bandit / happy-dom), build-tools author (bandit proxy gate), Phase 4 cross-family reviewer (transfer-risk-v1 on bandit), baseline single-agent (pending)
- **Comparison set:** GPT-5.5 via `codex exec`, Sonnet 4.5 historical, Gemini 3.5 Flash
- **Total supervised wall time:** ~6–8h, ~10 dispatches, ~$3 model spend
- **Reviewer:** me, with full task tracing — not a chat-window impression

The receipts are linked at the bottom; every finding cites the run directory or worklog entry that produced it.

---

## Findings (ordered by how much I'd bet on them)

### F1 — Codebase-conformance is real and underappreciated (confidence 88, n=1 strong)
Composer follows the *existing* per-file convention of the repo it's editing more strictly than the human gold patch does. On kysely-window-grouping-helpers it split each new operation-node into its own file with the exact `kind/is/create` factory shape kysely already uses (`extends OperationNode`, `freeze({…})`). The gold patch fused two nodes into one file for compactness — Composer didn't, and the divergence tracks an existing pattern the gold ignored. The bench grader can't see it; a human reviewer would prefer Composer's output.

- **Evidence:** Hₐ₇ in `harness/feature/HYPOTHESIS_GRAPH.md`; kysely fire #1 source files vs gold.
- **Caveat:** n=1 on a repo with strong existing convention. Repos with weak/inconsistent conventions may push Composer back toward over-decomposition. Bandit (smaller, less internally consistent) didn't replicate this finding cleanly — n was wrong for the test there.

### F2 — First-pass proxy-green is very strong; first-pass grade-green is class-dependent (confidence 70, n=2 split)
Two-for-two on first-pass *proxy* green on dense PRDs (kysely 57/57, bandit 30/30 — every test Composer's own design doc specified passed on the first impl shot). On the hidden *grader*: kysely 254/254 → REWARD 1, bandit 75/78 → REWARD 0. The bandit gap was *all* compositional axis-crossing — set-algebra inside expressions, bracket-tracking across continuation lines — exactly the failure mode the proxy gate's own author didn't enumerate.

**Pattern:** Composer writes confidently within the abstractions it's set up, less so across the joints between them.

- **Evidence:** Hₐ₆ in HYPOTHESIS_GRAPH; kysely + bandit fires 2026-05-28.
- **Caveat:** the bandit deficit was fully recoverable via a 13-line hand patch from the diagnosis. n=2 is low; the split direction matched the pre-registered F₁₂-class prediction, which is the part that makes it more than vibes.

### F3 — As Phase 4 adversary it's productive but verbose (confidence 80, measured)
61 findings on a 34-test gate vs codex's 44 on the identical prompt. Many of Composer's discrimination-section findings are defensive ("detected, no extra input needed") — coverage of the prompt's structure rather than substantive concerns. Its missing-coverage section was where it earned its tokens: 13 unique gaps codex didn't surface, mostly *interaction* scenarios (multi-region per multi-line statement, stacked next-line directives, nested begin same line, region continuation across block exits).

Composer is reaching for combinatorial completeness in a way codex isn't. Codex is reaching for soundness in a way Composer isn't. Both lenses earn their tokens, and the union is much more useful than either alone.

- **Evidence:** `harness/feature/run/bandit-structured-nosec-directives/transfer-risk-v1/PAIRING.md`.
- **Caveat:** the prompt asked for findings in a numbered list; both reviewers padded. A leaner prompt ("only flag substantive concerns") might compress Composer harder than codex. Untested.

### F4 — The one soundness miss is the interesting one (confidence 85, single high-signal datapoint)
Composer reviewed a gate that asserts unsound PRD behavior (a `nosec-next-line` directive whose suppression leaked into the following statement) and *certified the test as discriminating well* (F42 in the Composer review). Codex caught it immediately as F1 soundness. This is the exact failure mode the cross-family protocol is built to handle.

**Don't deploy Composer as both author and sole reviewer.** Same-family review is structurally biased toward "my own confident output looks fine to me." H₉ is load-bearing precisely here.

- **Evidence:** `transfer-risk-v1/codex-review-raw.txt` F1 vs `composer-review-raw.txt` F42; spot-check confirmed codex correct against PRD literal read.
- **Caveat:** one artifact. n=2 on a different feature class would harden the finding. But the failure mode is structurally predictable, not stochastic, so I'd put weight on it now.

### F5 — Pricing is the headline nobody's writing about (confidence 95, verified against published rates)
At Cursor's published rates (Standard tier: $0.50/M input, $2.50/M output), **Composer 2.5 is the cheapest sub-frontier coding model with frontier-comparable benchmarks.** Per-token:

| | input $/M | output $/M | per typical review (~5.7k in, ~2k out) |
|---|---|---|---|
| Composer 2.5 Standard | $0.50 | $2.50 | **~$0.01** |
| Gemini 3.5 Flash (paid) | $1.50 | $9.00 | ~$0.025 |
| Gemini 3.5 Flash (gemini-cli free tier) | — | — | **$0** |
| GPT-5.5 standard | $5.00 | $30.00 | ~$0.085 |
| Opus 4.7 | $15.00 | $75.00 | ~$0.24 |

Composer is **~10× cheaper than GPT-5.5**, **~3× cheaper than paid Flash**, and **~25× cheaper than Opus 4.7** per call. Coding-capability-per-dollar, Composer 2.5 is the cheapest competent model right now, full stop.

Scaffold-arm budget at these rates: ~$80–90 for the full 113 × 3 ablation, of which most is Composer impl-spec; Flash via gemini-cli is free tier. The earlier Sonnet 4.5 + GPT-5.5 pair would have been ~$1500–2000. At this price point, *"first pass 95% + one targeted retry"* is the actual cost model — the bandit grade-red was recoverable via a 13-line patch we verified by hand → REWARD 1 on identical impl, total Composer spend ~$0.30 for the fire.

**Reproducibility caveat:** Composer 2.5 has no public API. Calls must go through Cursor IDE or `cursor-agent` CLI. Anyone replicating this scaffold needs a Cursor subscription or Cursor API key — not just an OpenRouter or Anthropic key. Meaningful for prereg attestation: the model is gated behind one vendor's CLI.

- **Evidence:** [cursor.com/blog/composer-2-5](https://cursor.com/blog/composer-2-5), [openai.com/api/pricing](https://openai.com/api/pricing/), [ai.google.dev/gemini-api/docs/pricing](https://ai.google.dev/gemini-api/docs/pricing), all verified 2026-05-29; PREREGISTRATION.md §0.2 budget rewrite.
- **Caveat:** arithmetic on published Standard-tier rates against measured token volume. Cursor's Fast tier is 6× more expensive ($3/M in, $15/M out); `cursor-agent -p -f --model composer-2.5` defaults to Standard on the accounts I've tested, but operators should verify on their account.

### F6 — Operationally it's the most annoying frontier coder to dispatch (confidence 90, lived)
Cursor-agent (the CLI) was responsible for 3 of 9 banked operational gotchas this session: silent cwd switching to last-trusted dir if `--workspace` is omitted, `CURSOR_API_KEY` not surviving subshell spawning even with `source ~/.zshrc`, and the harness "background command completed" signal firing when the dispatcher shell returns rather than when the spawned `&` job finishes. The model is good. The CLI is not.

If you're not running Composer inside Cursor (the IDE), budget real time on plumbing. Three back-to-back failed dispatches preceded the first successful bandit fire.

- **Evidence:** HYPOTHESIS_GRAPH.md "Operational lessons from live fires" §§1, 2, 8, 9.
- **Caveat:** rapidly changing — Cursor ships CLI updates often. The specific lessons may not survive the month. The general "the CLI is rougher than the model" should.

### F7 — Training-corpus signal leaks through in diff style (confidence 65, qualitative)
Composer is Cursor-fine-tuned on Kimi K2's base. The Kimi base shows through: terse comments, single-line function bodies where the original code uses block form, occasional Mainland-Chinese-coding-style namespace conventions. None of that affects correctness. It does affect *recognizability* — reviewers who've never seen Kimi-shaped output will pattern-match "unusual" before "fine." A small but real adoption tax in conservative codebases.

- **Evidence:** kysely fire #1 + bandit fire #1 diff style vs gold. Qualitative.
- **Caveat:** subjective; a controlled style-only assessment would tighten this. Not load-bearing.

### F8 — Where I would NOT ship it (confidence 80, derivative of F4)
Safety-critical work where the cost of a missed soundness bug is high (medical, finance, legal patches). The bandit pattern — confident certification of unsound behavior — is exactly the failure mode that can't be allowed in those domains. For ordinary application code where a CI suite catches the misses, the cost/capability tradeoff dominates and Composer is the right choice.

- **Evidence:** F4 directly.
- **Caveat:** GPT-5.5 and Opus 4.7 have their own soundness misses; this is relative ranking on a small n. The principle (don't ship a self-confident model as its own reviewer) is general.

### F9 — Market positioning bet (confidence 75, structural read)
Cursor is betting that *frontier-quality coding* at *cheap-tier prices* is more valuable than *frontier-quality reasoning* at frontier prices. For 95%+ of dev work the bet is right. The long-tail-hardest 5% they're conceding to GPT-5.5 / Opus 4.7 / Sonnet 4.6. That's a defensible market segment, and the fact that the SWE-bench Pro pre-registration (sibling experiment) also switched to a Flash + Composer primary pair suggests the bet is already winning at the practitioner level.

- **Evidence:** PREREGISTRATION §0.2 + the equivalent move in swebench-pro/.
- **Caveat:** structural inference, not measurement. The "5% conceded" claim is a guess; the actual ceiling could be higher or lower.

---

### F10 — As Phase 3.5 adversary (gate review at author-time) it's *more* productive than as Phase 4 reviewer (confidence 75, n=1 cross-phase)
Same artifact (Flash-authored bandit gate), same review prompt: Composer surfaced 14 unique missing-coverage findings, codex surfaced 4. Phase 3.5's catch rate on the substrate's known impl-bug axis-crossings was 1/3 clean + 2/3 partial. Composer specifically caught the multi-region-per-multi-line-statement gap (F50) that traced to one of the three eventual impl bugs. The implication: Composer's combinatorial-completeness habit (F3) is *more* useful before the impl exists than after — it can suggest test categories the author didn't author proactively.

This is a real architectural reframe: Composer earns more tokens as adversary on the *gate alone* than as adversary on the *gate + impl*, on this substrate. The Phase 3.5 protocol just added to `skills/build-tools/skill.md` (2026-05-29) operationalizes this; carrying SPECULATION-typed findings forward to Phase 4 via `RESIDUE.md` lets a finding's type change across phases (Hₐ₁₀ operationalized).

- **Evidence:** `transfer-risk-v1/PHASE-2-BIS.md`; Composer review F50 vs bandit test_058 impl bug.
- **Caveat:** n=1 cross-phase comparison; one more substrate would harden. The "more productive" framing is partial — codex's single soundness catch on the gate was load-bearing and Composer missed it (F4). Both phases need both lenses.

### F13 — Adversary role is substrate-dependent: Flash > Composer on compositional, Composer > Flash on breadth-additive (confidence 87, n=2 cross-substrate)
**MAJOR FINDING from kysely fire 2026-05-29.** The bandit measurement (where Flash beat Composer 2/2 vs 1/2 on soundness) was reversed on kysely: Composer caught 5 soundness flaws Flash declared "highly sound" (0/5), including a harness-wiring slip (`db` undefined) Flash missed entirely.

The lens difference is real, but **which lens catches which failure mode is substrate-dependent**:
- Compositional / dense Python PRD (bandit): Flash's literal PRD-scope tracking catches over-asserting (axis-crossing leaks, line-number over-assertion).
- Breadth-additive / multi-feature TS PRD (kysely): Composer's combinatorial reasoning catches over-scoping (dialect-specific quoting, empty grouping sets, type-generic constraints, harness slips).

A single adversary is structurally insufficient. The dual-adversary protocol at Phase 3.5 is more important than the bandit n=1 measurement made it look. H₉ overlap on kysely (~11.5%) is *lower* than on bandit (37.9%) — the two lenses are MORE complementary on breadth-additive substrates than on compositional ones.

- **Evidence:** `kysely-window-grouping-helpers/transfer-risk-v1/RESULT.md`; flash-adversary (13 findings, 0 soundness) vs composer-adversary (45 findings, 5 soundness).
- **Caveat:** n=2 across two feature classes is still small. The substrate-dependence framing is qualitatively strong but quantitatively bracketed.
- **Implication for role-split design:** F11 (Flash dominates per-soundness-catch-per-dollar) was substrate-conditional. The corrected framing: neither adversary is uniformly better; dual-adversary at Phase 3.5 is the right protocol.

### F11 — As soundness-catching adversary on compositional substrates, Composer is outperformed by Flash (confidence 80, n=1 bandit-specific)
On the same Flash-authored bandit gate, fired in parallel: Flash caught 2/2 known soundness bugs (axis-crossing + nested-LIFO line-numbers), codex caught 1/2 (axis-crossing only), Composer caught 1/2 (LIFO only). Flash returned 14 findings; codex returned 44; Composer returned 61. **Composer's advantage at this protocol is breadth, not soundness** — it surfaced 19 unique missing-coverage gaps neither Flash nor codex flagged.

**Per-review pricing (verified 2026-05-29 against published rates):** Flash gemini-cli free tier $0 (or ~$0.025 paid), Composer 2.5 Standard ~$0.01, codex GPT-5.5 ~$0.085. **Composer is ~8.5× cheaper than codex per review and cheaper than paid Flash too.** The earlier "Composer ~$0.05/call" figure I used was wrong — I was estimating from output length without per-token rates.

This is the cleanest empirical justification for **dual-adversary at Phase 3.5**: Flash for soundness, Composer for breadth. Their substantive overlap is 37.9% so 62% of findings come from one and not the other — neither alone is the right adversary. Combined cost: **~$0.01 per task, ~$3 across the full ablation** (Flash free tier + Composer Standard). Cheap insurance.

- **Evidence:** `transfer-risk-v1/flash-adversary-raw.txt` vs `composer-review-raw.txt` vs `codex-review-raw.txt`; PAIRING.md.
- **Caveat:** n=1 artifact, single substrate. Composer's verbosity may compress with a leaner prompt (untested). Flash's soundness-catch advantage may be substrate-dependent — the bandit PRD is dense enough that mechanical scope-tracking pays. Sparse PRDs may favor combinatorial reasoning.
- **Implication for role-split design:** Composer-as-adversary is *not* a default replacement for Flash-as-adversary at any phase. Use Composer alongside Flash when breadth matters; use Flash alone when budget pressures discourage dual-fire — though at $0.01/task the budget excuse barely exists.

- **Evidence:** `transfer-risk-v1/flash-adversary-raw.txt` vs `composer-review-raw.txt` vs `codex-review-raw.txt`; PAIRING.md.
- **Caveat:** n=1 artifact, single substrate. Composer's verbosity may compress with a leaner prompt (untested). Flash's soundness-catch advantage may be substrate-dependent — the bandit PRD is dense enough that mechanical scope-tracking pays. Sparse PRDs may favor combinatorial reasoning.
- **Implication for role-split design:** Composer-as-adversary is *not* a default replacement for Flash-as-adversary at any phase. Use Composer alongside Flash when breadth matters; use Flash alone when budget pressures discourage dual-fire.

### F12 — Composer-as-author internalizes typed-acceptance discipline; Flash mechanically templates it (confidence 82, n=1 ablation)
Same prompt, same PRD, same `--approval-mode plan`. Flash-disciplined produced 34 tests with 100% PRD-quote density but introduced 3 over-asserting soundness bugs (axis_crossing, nested_LIFO, indented_whitespace). Composer-disciplined produced 37 tests with 100% PRD-quote density, **3 axis-crossing tests all written soundly** (no over-asserting), an unprompted `# RESIDUE:` block at file head listing 3 typed-acceptance speculation entries, and helper functions (`ids()`, `count()`) for richer assertion shapes.

Composer is *applying* the typed-acceptance protocol on its own initiative. Flash *templates* it — fills in PRD-quote slots without preserving the underlying soundness invariant. The coding-instruction-tuning difference shows up exactly here.

- **Evidence:** `transfer-risk-v1/H8-ABLATION.md` extended with Composer rows; `composer-author-disciplined-test_proxy.py` axis_* method bodies.
- **Caveat:** keyword analyzer is Flash-shape-biased (low on Composer's `assertEqual(count(...), 1)` style); qualitative read overrides metric. n=1 substrate.
- **Implication for role-split design:** the prereg's "Composer as author" choice is empirically supported — Composer's author output is qualitatively much stronger than Flash's. The role split as deployed is right.

### F14 — Composer-as-recon dominates Flash on schema adherence; the gap is family-deep (confidence 87, n=3 head-to-head)
Composer-as-recon (design-doc skill) was empirically tested against Flash-as-recon on the same prompt, across kysely (breadth-additive) + bandit (compositional) + oxvg (subtractive) substrates 2026-05-29.

**Flash output across all 3:** drifted into conversational prose, filled schema fields with free-form text instead of enum values (e.g. `BRANCH: feature/grouped-aggregation-window-helpers` treating the project's decision-tree branch slot as a git-branch name), and ended the kysely doc with *"Please let me know if you would like me to proceed."* — treating a one-shot dispatch as a conversation turn.

**Composer output across all 3:** followed the schema (correct enum values), surfaced explicit `PRD hard negatives` + `Typed-interface surface` sections unprompted (exactly the structure build-tools needs for axis-crossing test design), included a `*Residue (AMBIGUOUS):*` section flagging PRD clauses with multiple readings — **applying the typed-acceptance protocol at recon stage on its own initiative**.

The pattern is consistent with the [[gemini-family-discriminator-not-generator]] memory: Gemini's strength is recognition / classification on tasks where it has been pretrained on the surface, weak on multi-step adherence to *prompt-defined* schemas where the prompt redefines common words (`BRANCH`).

- **Evidence:** `results/recon-comparison/composer-recon-{kysely,bandit,oxvg}-*.txt` vs `results/runs/<task>/scaffold/audit/design-doc.md`. PREREGISTRATION §3a amended 2026-05-29 to move recon from Flash to Composer; cost delta ~$1.13 across full ablation.
- **Caveat:** the original Flash-recon prompt was thin (didn't define `BRANCH` as decision-tree slot). A separate test where Flash *was* given the tight schema (oxvg flash-classify on 2026-05-29) saw Flash classify correctly — suggesting prompt-tightness can recover some of the gap. But Composer needs less prompt-tightness to stay on schema, which is itself a meaningful capability difference.
- **Implication for role-split design:** the role split is now Composer-as-recon + Composer-as-author + Composer-as-craft (all Composer body) with Flash + Composer as Phase 3.5 dual-adversary and Flash as Phase 4 adversary. Cross-family property is preserved at the adversary step (where H₉ measured it matters) without forcing a generative role on Flash where it underperforms.

## Open questions (will be folded back into findings as measurements land)

- **OQ1.** Does Composer-as-adversary fire usefully at *proxy-author* time (Phase 2-bis), not just at *impl-review* time (Phase 4)? The bandit grade-red was traceable to proxy-author misses, so the loop may need to fire earlier. Item #3 on the project's improvement list — a separate measurement.
- **OQ2.** Does Composer's first-pass proxy-green property transfer across substrates other than dense additive/compositional Python? Need a TS-only or Rust task to test.
- **OQ3.** How does Composer compare against itself with vs without `--model composer-2.5-fast`? `-fast` is forbidden in our scored runs but a single ablation pair would tell us the speed/quality elasticity.
- **OQ4.** Does the prompt-leanness hypothesis under F3 hold? Same artifact, 1-line prompt asking only for substantive concerns — does Composer compress to codex-volume or stay at 60+?
- **OQ5.** Composer-as-baseline (single-agent driving the full task end-to-end, no scaffold). Required for the prereg's harness-richness ablation. Will surface what Composer does without our recon→craft→audit structure.

---

## Receipts

- **HG status table + per-hypothesis rows:** `harness/feature/HYPOTHESIS_GRAPH.md`
- **Per-task run dirs:** `harness/feature/run/{kysely-window-grouping-helpers,bandit-structured-nosec-directives,happy-dom-abort-pending-body-reads}/`
- **H₉ transfer-risk measurement (this session):** `harness/feature/run/bandit-structured-nosec-directives/transfer-risk-v1/{PAIRING,RESULT}.md`
- **Pre-registration (where Composer's role + pricing rewrite is documented):** `PREREGISTRATION.md` §0.2, §3a
- **Worklog (chronological):** `WORKLOG.md`, `harness/feature/WORKLOG.md`

---

## Pruned (claims refuted by evidence)

*(none yet — first entry will date when a finding gets demoted)*
