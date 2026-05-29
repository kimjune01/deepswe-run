# Hypothesis graph — feature pipeline on DeepSWE

Tight self-note. Primary consumer: me (the agent running the pipeline). Skip framework prose; live decisions only. Full receipts in `harness/feature/run/` + WORKLOG.

## Operating directives (apply every run)

1. **Classification → discipline routing.** Read `FEATURE-SHAPE` (`enum` / `invariant` / `mixed`) from the PRD before anything else. Routes: `enum` → build-tools (Hₐ₂). `invariant` → compose (Hₐ₄). `mixed` → both, monoidal, either order.
2. **Purpose over surface (H₁ᵦ).** When the decision tree's branch 3 ("isolated new method/flag") conflicts with branch 2 (subtractive/transform/filter/optimizer/selector verbs), branch 2 wins. Surface-view classification on a purpose-SUBTRACTIVE feature loses preservation semantics.
3. **PRD enumeration → one test per element, PRD-quote per test (Hₐ₂).** But first ask "are all elements semantically uniform?" (Hₐ₂″). Tri-state / multi-clause elements route to per-case expansion (≥2 tests each), not flat per-element.
4. **Mutation thinking at test-design (H₈).** For each criterion, name the simplest plausible-wrong impl and ensure inputs put it in the *disagreement* region. Inputs in the agreement region don't discriminate. Identical-blanket inputs for a LIFO/FIFO distinction = bug.
5. **Design-doc iteration phase (H₇).** After draft, re-read PRD asking "what behaviors emerge from rule *combinations* I haven't enumerated?" Phase 4.5 catches what classification misses, and vice versa — they're complementary, keep both.
6. **Cross-family adversarial review (H₉).** Send the proxy gate to a different model family for review. Apply findings selectively; cross-family makes blind spots *different*, not absent. **WARNING for Flash+Composer: pattern is built on Claude↔GPT-5.5 complementarity. Re-measure (see Transfer Risks §).**
7. **Round-trip soundness on the augmented gate (H₁₀).** After applying any new tests (cross-family or otherwise), re-run gold-passes-proxy. Unsound-on-gold routes to **build-tools**, NOT implement-spec. The gate is wrong, not the impl. Verdict: `NOT_RESOLVED — proxy-unsound`.
8. **Verify the mutant changes observable behavior on canonical first.** Before claiming a coverage gap, confirm canonical-catches-mutant. Twice this session I tripped over phantom gaps where the mutation was a no-op at canonical level (oxvg pseudos, opa nil-slice M4). Self-H₈ failure.
9. **Inner-loop economy (H₆).** Use `dsr isolate` (gold → proxy) for measurement; skip implement-spec when isolating build-tools quality.
10. **Scope discipline (H₅).** Engineering claim only: "our pipeline on this substrate." Never claim agent-capability conclusions. Always report on-axis AND population (overfit-discounted) confidence separately.

## Graph state (live)

| node | claim (one line) | status | on-axis | population | transfer to Flash/Composer |
|---|---|---|---|---|---|
| H₁ᵦ | purpose-over-surface beats branch-3 surface match | confirmed · patched | 82 | 55 | **med** — re-test classification accuracy |
| H₂ | spec-test gaps are underspec, not contradiction; KNOWN_BAD empty | confirmed (narrow) | 87 | — | low — deductive |
| H₃ | encoded skill → SOUND+LIVE on first blind run | confirmed (n=3, cross-family) | 78 | — | low — kysely fire #1 confirmed on Composer |
| H₄ | proxy misses ARE the residue | confirmed (n=1 mutant) | 70 | — | low |
| H₅ | bench is engineering, not science | confirmed · discipline | 80 | — | n/a — meta |
| H₆ | gold-isolate substitutes for implement-spec measurement | confirmed · **measured end-to-end** (kysely gold + Composer impl both → REWARD 1, 2026-05-28) | 95 | — | none — pure ops |
| H₇ | design-doc iteration surfaces compositional rules | partial (caught M1, missed M3) | 65 | 45 | **high** — Composer may emit fuller first-pass reads |
| H₈ | enumerated ≠ discriminating; mutation thinking at test-design | confirmed · encoded | 72 | 50 | **high** — Flash/Composer blind spots ≠ Claude's |
| H₉ | cross-family review catches structural blind spots | strong (2×2 closed) · **non-firing on first-pass-green tasks** (kysely fire #1) | 77 | 60 | **CRITICAL** — Claude↔GPT-5.5 pair gone; new pair = Anthropic-absent. See §Transfer. Note: adversary unmeasured when craft model first-passes; need a *missing* fire to measure overlap. |
| H₁₀ | augmented-gate soundness round-trip needed; UNSOUND routes to build-tools | open · patched | 75 | 50 | low — protocol |
| H₀′ | compositional rules are the dominant class | **REFUTED** (F₁₂, n=224: breadth 41% > comp 32% > path 14%) | — | 80 | low — corpus fact |
| Hₐ₁ | path/fixture discipline (test fixture actually triggers code path) | open · F₁₃ queued | — | 60 | unknown |
| Hₐ₂ | PRD-enumeration → per-element tests with quote | confirmed on-axis (n=3: kysely, opa, httpx; 13/13 mutants) | 85 | 65 | **low-med** — PRD listing is language-agnostic; spurious-enum filter may need re-tuning |
| Hₐ₂′ | compositional rules sometimes encodable as enumeration (kysely SimplifyFrame, opa nil-receivers) | confirmed (n=2) | 70 | — | low |
| Hₐ₂″ | spurious-enum filter (tri-state in flat enum) | confirmed · patched · measured on httpx | 78 | — | low |
| Hₐ₃ | adaptive routing on **PRD shape**, not canonical-test class | refined (opa decisive) | 55 | — | med — re-test on PRD-without-enum task |
| Hₐ₄ | compose: enumerate surface the PRD *implies*, not just what it lists | encoded · monoidal | machinery 82 / case 30 | — | unknown — case still unfound (oxvg refuted) |
| Hₐ₅ | convergence + dampener for LLM skills (Phase 0 self-classify, identity on wrong-shape) | encoded · 5/5 cheap probes pass | 75 | — | low — protocol, commutativity dropped |

## Live partial-run datapoints (deepswe-partial-v1, fires log)

| # | task | F₁₂ class | model | proxy | grade | wall | notes |
|---|---|---|---|---|---|---|---|
| 1a | kysely-window-grouping-helpers | 71% breadth | **gold** | n/a | **REWARD 1** (base 22/22, new 254/254) | <1 min | H₆ closed end-to-end. Bench plumbing verified top-to-bottom. |
| 1b | kysely-window-grouping-helpers | 71% breadth | **Composer 2.5** | 57/57 (1st pass) | **REWARD 1** (base 22/22, new 254/254) | ~30 min | First Flash+Composer grade-green. 21 files (vs gold 15). No adversary volley needed → H₉ non-firing here. |

## Hₐ₇ — Composer follows codebase idioms more strictly than gold (REFINED, kysely fire #1)

- **claim (refined):** Composer's grade-green impl decomposes per the codebase's *own* existing convention more strictly than gold (kysely: each operation-node in its own file with the `kind/is/create` factory pattern; new `parser/` layer mirroring kysely's existing parser-side). Gold broke kysely's per-file convention for compactness (fused `window-frame-node.ts` holds both frame + bound). On the oracle, both pass equally — the bench can't see the divergence.
- **null (original, refuted):** Composer would simply *over-decompose* (split things arbitrarily). It didn't; the split tracks an existing pattern.
- **trajectory:** n=1 supporting (kysely fire #1). Composer's `frame-node.ts` / `frame-bound-node.ts` / `group-by-cube-node.ts` all use the same `import freeze`, `extends OperationNode`, `kind:'FooNode'`, `FactoryType.is/create/freeze({...})` shape as kysely's existing `over-node.ts`, `aggregate-function-node.ts`, etc.
- **status:** open · single datapoint
- **mode/conf:** deduction (head-by-head file comparison, deterministic) → **88%** on the idiom-conformance finding (kysely-specific); population unknown
- **implication for the publishable claim:** *strengthens* "Flash+Composer match SOTA": Composer's output is not just behaviorally correct but also idiomatically consistent with the repo, arguably more so than the human gold. The earlier worry that Composer would produce structurally-divergent code that a maintainer would reject is contradicted by n=1.
- **risk to retest:** repos with weak/inconsistent existing conventions may not give Composer a stable pattern to grep, in which case Hₐ₇ flips back to over-decomposition. Bandit (Python, smaller codebase) may show this.
- **provenance:** Composer's new node-file heads (`frame-node.ts`, `frame-bound-node.ts`, `group-by-cube-node.ts`) compared head-to-head with kysely's existing `over-node.ts`, `aggregate-function-node.ts`; 2026-05-28 kysely fire #1.

## Hₐ₆ — Composer first-passes breadth-dominant features without an adversary loop (NEW)

- **claim:** on breadth-dominant tasks (F₁₂ ≥ 60% breadth), Composer 2.5's first pass with PRD + proxy gate is proxy-green *and* grade-green — the adversary slot is non-firing, so the cost projection should treat the Phase-4 volley as conditional, not unconditional.
- **null:** Composer needs an adversary review on breadth tasks just like Claude needed codex.
- **trajectory:** n=1 supporting (kysely). The adversary slot wasn't tested for *value*; it was tested for *necessity* and didn't trigger.
- **status:** open · single datapoint
- **mode/conf:** induction · on-axis 60 (1 task); population unearned
- **perturbation needed:** a *compositional-dominant* task (bandit, F₁₂ 42% comp) where Claude needed H₇/H₈/H₉ stacks to clear M1/M3 mutants. If Composer also first-passes there, H₉'s necessity claim collapses on this pair. If Composer fails there, the adversary slot fires and H₉ overlap becomes measurable.
- **provenance:** kysely fire #1 (2026-05-28), `harness/feature/run/kysely-window-grouping-helpers/partial-v1/composer-impl-pass1.log`.

## Transfer risks for Gemini 3.5 Flash + Composer 2.5 (NEW, top-priority for upcoming run)

The graph above was built on Sonnet 4.5 generator + GPT-5.5 (codex) challenger. Primary pair swapped 2026-05-28 (PREREGISTRATION §0.2). Risk-ranked:

| risk | what's at stake | measurement to run first |
|---|---|---|
| **H₉ blind-spot complementarity** | Cross-family pattern assumed Claude↔GPT-5.5. New pair is Gemini + Composer. Composer is Cursor-fine-tuned on Kimi K2.5 base → genuinely different family from Gemini, so H₉ may still work. But measure, don't assume. | Run codex (GPT-5.5) review on a Flash-generated proxy + Composer review on same; compare gap sets. If overlap > 70%, H₉ collapses to mostly self-review. |
| **H₈ mutation thinking** | Discipline patches a Claude-specific tendency (test from rule *name* not observable consequence). Flash/Composer may already do this, in which case forcing the phase is wasted tokens; OR they may have a different failure mode the phase doesn't catch. | F₇-style ablation (H₈ on / off) on one breadth-dominant + one compositional task per model. |
| **H₇ design-doc iteration** | Composer is instruction-tuned for coding → may emit fuller first-pass PRD reads → iteration impact lower. | Same ablation as H₈: iterated vs single-pass design doc on one task per model. |
| **H₁ᵦ purpose-over-surface** | Decision tree was patched against Claude's branch-3 over-eagerness. Flash may default to branch 2 (or to some other branch entirely). | Single bandit run per model; check whether agent reaches SUBTRACTIVE without override. |
| **F₁₂ class distribution** | Corpus class % were measured from Claude-family canonical-test reads. Flash/Composer may surface different miss classes on the same tasks. | F₁₂-style classification by Flash+Composer on 3-4 tasks before committing further skill stack changes. |

**Safe-to-transfer (low risk, no re-measurement before run):** H₂, H₃ (operationally), H₅, H₆, Hₐ₂ core pattern, Hₐ₂″ filter, Hₐ₅ Phase 0 self-classify, H₁₀ routing protocol.

**Action before scored run:** run the five measurements in the table above on `kysely-window-grouping-helpers` (breadth-dominant) + `bandit` (compositional anchor) at minimum. If any returns surprising — discipline doesn't fire, or backfires — patch the skill before freeze (§3 PREREGISTRATION restart).

## Open frontiers (TODO)

- **F₁₃ — path/fixture discipline (Hₐ₁).** Per-test: "does my fixture produce the observable change this rule triggers?" Add as build-tools Phase 2-bis. Substrate: `happy-dom` or `opa-template-string-reconstruction` (path-dominant per F₁₂).
- **F₁₅ — adaptive miss-class prediction (Hₐ₃).** Design-doc reads PRD shape → predicts probable miss class → routes discipline. Already partial via FEATURE-SHAPE; extend to predict breadth/compositional/path proportion.
- **Hₐ₄ case substrate.** Need a task where invariant-axis surface inference is canonical-load-bearing. oxvg refuted (mutations didn't change canonical behavior). Candidates: bandit `:nth-child`-shaped selector ops inside `# nosec`.
- **Hₐ₂ true off-axis.** A PRD-without-flat-enumeration task with the patched stack, to confirm Hₐ₂ self-suppresses safely (predicted: `enum` shape silent, compose handles it). bandit is the obvious test.
- **H₇+H₈ stack-test under joint encode.** Measure whether they're truly complementary post-patch or whether one subsumes the other on new substrates.
- **H₁₀ verdict route.** Wire `NOT_RESOLVED — proxy-unsound` into `dsr` + verify-spec; route failing test names back to build-tools for kill.

## Pruning log

- **H₀ closed-negative-overbuild.** Single-task anchor (httpx). Refined into H₁; flat form refuted by 13-task fan-out (4/13 subtractive REFUTE).
- **H₁ₐ "discipline is sufficient; classification decorative."** Killed by F₁′ M1: agent missed nested blanket-dominance despite claiming the discipline. Classification directs *what* the agent looks for; discipline only catches what it looks at.
- **H₀′ strong form ("compositional dominates").** Refuted by F₁₂ corpus (n=224): breadth 41% > comp 32%. Session anchored on bandit (42% comp — *outlier*). H₁ᵦ/H₇/H₈/H₉/H₁₀ all target the second-largest class.
- **dasel "PRD contradicts test"** (B3-go subagent). Killed by direct re-read; subagent confabulated. Lesson: audit-post verify gate is load-bearing; fan-out subagents over-claim contradictions.
- **Hₐ₄ "oxvg gap measured" (first claim).** Refuted by canonical-passes-mutation verification (10/10 on both `:first-child` and `:nth-child` removal). Pseudo handling isn't canonical-load-bearing on oxvg. Compose machinery sound; case wrong. Self-H₈ failure.
- **opa M4 "nil-slice gap."** Refuted: mutation was a no-op in Go (nil-slice + `var result []string` + no appends = nil regardless of guard). Real M4 caught instantly. Self-H₈ failure #2.
- **Hₐ₅ commutativity.** Dropped — not needed for benchmark-shaped output. Monoidality (Phase 0 self-classify + identity on wrong-shape) is enough.

## Operational lessons from live fires (banked, fix before next dispatch)

1. **`cursor-agent` defaults to its last-trusted cwd.** Always pass `--trust --workspace <path>`. Without these flags it silently `cd`s to its remembered trust dir and edits the wrong tree. Banked 2026-05-28 kysely fire #1.
2. **`CURSOR_API_KEY` does not survive Bash-tool shell spawning** even with `source ~/.zshrc`. Every cursor-agent dispatch needs the env var passed explicitly (e.g. `CURSOR_API_KEY="$KEY" cursor-agent …`) or `--api-key "$KEY"`. Bootstrap's "validate once" assumption is wrong.
3. **`dsr isolate` wipes the working diff** (applies gold, resets to base). Use it for measuring the proxy gate, never after running impl. To measure an impl pass: `docker cp src` then `proxy_gate.run` directly.
4. **`cursor-agent`'s self-reported gate result was accurate on n=1** (Composer claimed 57/57, container verified 57/57 on kysely). Tentative: may be usable as an early-exit signal, but don't trust until n≥3.
5. **Long impl runs are silent** — Composer made 21 file edits with no streaming output until the IMPL_DONE line. Monitor by log file size growth, not by content tail.

## Standing meta-lessons (worth re-reading at the start of every session)

- **n=1 → sniff + sweep.** Any claim from one task gets a codex/gemini sniff for unstated assumptions, then a corpus sweep before population-level use. F₁₂ was the methodology vindication.
- **Report two confidences.** On-axis (training distribution) AND off-axis/population (discounted). Never collapse.
- **Verify the mutant first.** Canonical-catches-mutation is the precondition for any "proxy misses mutant" claim. Twice burned this session.
- **Cross-family doesn't make codex right.** Codex over-suggests; the agent must filter. H₁₀ exists because of this.
- **PRD shape ≠ canonical-test class.** Hₐ₃ predicate is observable from PRD alone (good — no peek). F₁₂ classes are for corpus analysis, not routing.

## Provenance pointers

- Per-task receipts: `harness/feature/run/<task>/{baseline.json,manifest.json,verdict.json}`
- Cross-task: `harness/feature/run/wider-sweep.md` (F₁₂ classification)
- Skill lessons (durable patches): `skills/build-tools/build-tools-lessons.md`
- Run history: `WORKLOG.md`
- Run procedure + CLI: `docs/PROCEDURES.md`

---

**Update rule.** New measurement → graph first (per /investigate). Update status, log provenance, open or close frontier, or split into sub-hypotheses. If not written, the investigation didn't happen.
