# deepswe-run worklog — `deepswe-sub-v2` (supersedes `deepswe-sub-v1`)

Newest first. This is the **scored-run trail** for validating the methodeutic harness on DeepSWE
(feature-implementation tasks). `deepswe-sub-v1` was frozen and dispatched but aborted ~30 min in on
a discovered defect (below); `deepswe-sub-v2` is the clean restart. Pre-freeze development history is
in [`WORKLOG_PREFREEZE.md`](WORKLOG_PREFREEZE.md). Per PREREGISTRATION §10/§11, each scored tag gets
its own trail.

## 2026-05-31 (evening) — codex run HALTED: `reasoning_effort=none` defect (leaderboard reconciliation)

**Trigger.** Operator skepticism: DeepSWE leaderboard puts gpt-5.5 at **70%**; our baseline-codex was
running **~30%**. Too big to dismiss.

**Defect (confirmed).** `codex_call` + the 2 direct `codex exec` blocks in `run_arm.sh` passed only
`-c model=gpt-5.5` with **no reasoning flag** → codex CLI default is **`reasoning_effort: none`**
(verified live: bare `codex exec -c model=gpt-5.5` banner reads "reasoning effort: none"; the
leaderboard's 70% was gpt-5.5 at **xhigh**). So both codex arms measured a *crippled* gpt-5.5. The
70→30 gap is **our config**, not the leaderboard (its separate reproducibility issues from the audit
still stand). Confounded the Hₐ₁₂ comparison too: Composer at full cursor-agent reasoning vs codex at
*none*.

**Action.** Halted the none-run at ~21% (codexrun2-20260531), torn down clean, 0 orphans. The
partial none-numbers (scaffold-codex 7/22, baseline-codex 7/24) are kept only as *gpt-5.5-at-none*
exploratory, NOT a capability read. Fixed all 3 codex exec sites to
`-c model_reasoning_effort="${DSR_CODEX_REASONING:-xhigh}"` (matches leaderboard; configurable).
Frozen deepswe-sub-v2 Composer/Flash results untouched (don't use codex).

**Canary.** baseline-codex at xhigh on the first 8 tasks (2 boxes) to confirm the jump toward ~70%
before committing the full (slow, quota-heavy) xhigh run.

## 2026-05-31 (evening) — §3b codex secondary launched (the Hₐ₁₃ decider)

After deepswe-sub-v2 completed + torn down (freeing spot quota), launched the §3b within-model
two-harness secondary on **8 spot boxes**: `scaffold-codex` vs `baseline-codex`, GPT-5.5 via codex
CLI subscription, 218 cells, under the **deepswe-sub-v2 freeze** (`0336f49`) — same frozen harness,
codex arms. Run-tag `codexrun2-20260531`. Dispatched 18:17, subscription-paced (hours).

**Purpose:** the decisive test of Hₐ₁₂/Hₐ₁₃ (operator bet) — does the harness HELP a general-purpose
model where it did NOT help coding-specialized Composer? Δ = scaffold-codex − baseline-codex; the
**sign** decides (Δ>0 confirms test-writing/specialization, immune to the capability confound because
it's a within-model delta).

**Provisioning saga (4 attempts — fleet.sh fragility, retro item).** (1) parallel-on-demand →
`MaxSpotInstanceCountExceeded` (spot quota L-34B43A08 = **32 vCPU = 8 boxes**; on-demand L-1216C47A =
128 vCPU is a separate pool). (2) on-demand 10-box → 4/10 empty-IID (rapid `run-instances` throttle).
(3) spot reused-tag → `InvalidKeyPair.NotFound` (tag collided with cleaned-up keys). (4) **fresh-tag
spot → clean.** Cleaned up after each (~$0.20 waste, zero orphans). Added `MARKET=on-demand` to
fleet.sh (`1e06d8a`); provision loop still needs retry-on-empty-IID + no-reused-tags hardening.

## 2026-05-31 (afternoon) — deepswe-sub-v2 COMPLETE: harness-richness thesis UNSUPPORTED

**Run.** 327 cells (109 × {scaffold, baseline-comp, baseline-flash}), 8 spot boxes, dispatched 10:33,
complete + torn down 18:12 (~7.5h wall), 0 orphans, ~$3 EC2. Flash adversary live throughout
(adv-flash.txt 6/6 non-empty at scale; v2 fix held). scaffold 100% real verdicts, 0 infra-fails.

**Final results.**
- scaffold **30/106 = 28.3%** Wilson[20.6, 37.5] — 3 INCOMPLETE (gql/sqlfmt/valibot heavy-tail
  ceiling-faults, classified INCOMPLETE not LOSS per fault taxonomy).
- baseline-comp **36/109 = 33.0%** Wilson[24.9, 42.3].
- baseline-flash **0/109 = 0.0%** Wilson[0, 3.4].
- **McNemar scaffold vs baseline-comp (106 paired):** scaffold-only 16, comp-only 21, discordant 37,
  **exact two-sided p = 0.51 → NOT significant.**

**Finding (honest, corrected).** The harness-richness thesis — scaffold beats single-agent Composer —
is **UNSUPPORTED** on DeepSWE feature tasks. The live-run read of "scaffold underperforms" is
**walked back**: the arms are statistically tied (CIs overlap, p=0.51). The harness does not earn its
complexity at a fixed coding-specialized model. They win DIFFERENT tasks (16 vs 21 discordant) — helps
some, hurts others, nets ≈0.

**Hypotheses opened (see `harness/feature/HYPOTHESIS_GRAPH.md`):** Hₐ₁₁ (harness no-lift), Hₐ₁₂
(general-purpose > coding-specialized on prose-shaped tasks — the whole optimistic graph H₁–Hₐ₁₀ was
built on Sonnet/codex, swapped to Composer/Flash; transfer-risk warning fired), Hₐ₁₃ (test-writing ≠
test-passing; harness leverage is the test-writing stage). Hₐ₁₃ localization MIXED (2 proxy-green/
official-red = test-writing failure, ~5 proxy-red = test-passing failure) → partial only.
baseline-flash 0% is the Hₐ₁₂ axis at its extreme (most coding-tuned model, prose tasks, total fail).

**Decider deferred to the §3b codex run** (above): does the harness help a general-purpose model?

## 2026-05-31 — `deepswe-sub-v1` ABORTED → restart as `deepswe-sub-v2` (failure class: silent Flash-adversary disablement)

**Failure class.** `INFRA_ENV / silent-adversary-disablement`. The Phase 3.5 cross-family **Flash
soundness adversary was silently dead on every box**, and the `baseline-flash` arm was 100%
non-functional — both producing empty/FATAL output. Caught ~30 min into the v1 scored run by the
health-check monitor (1 RESOLVED in the first ~11 verdicts, a cluster of fast `UNRESOLVED_NO_DIFF`).

**Root cause (codex-corroborated).** The driver bootstrap symlinked the uv-venv's python outside the
venv (`ln -sf .dsr-venv/bin/python /usr/local/bin/python3-dsr`). A venv python symlinked outside its
venv loses `pyvenv.cfg` discovery and falls back to the base interpreter, where `google.generativeai`
is absent → `gemini_api.py` FATALs. The bootstrap's genai assert used the *direct* venv path, so it
passed (`CREDS_INSTALL_OK`) and masked the bug. Decisive evidence: the v1 smoke's `adv-flash.txt` was
0 bytes even though that run RESOLVED — scaffold tolerates a dead Flash lens (backgrounded,
`2>/dev/null`), so the defect never surfaced in earlier scaffold-only smokes. The `baseline-flash`
arm, which depends entirely on Flash, exposed it.

**Fix.** `fleet.sh` bootstrap: replace the symlink with a wrapper script
(`#!/bin/sh; exec .dsr-venv/bin/python "$@"`) that preserves the venv exec path, plus a
`python3-dsr -c 'import google.generativeai'` assertion so the failure is loud at bootstrap, not
silent at runtime. The frozen harness code (`run_arm.sh`, `gemini_api.py`, skills, `HASHES.txt`
artifacts) is **unchanged**; only the driver's provisioning changed. Re-smoke confirmed at the
artifact level: scaffold `adv-flash.txt` = 4655 bytes (real soundness review), baseline-flash emits a
real Flash diff.

**Why a new tag.** The frozen hash set is identical, but the *effective treatment* changed — the
scaffold's documented dual cross-family adversary (Flash soundness + Composer breadth) was running as
Composer-only and is now genuinely dual. Honest provenance requires marking the boundary, so
`deepswe-sub-v2`'s freeze SHA pins the fixed driver. v1 produced no valid headline (aborted as
invalid); its ~$0.40 of EC2 is the cost of the canary discipline working as intended.

## 2026-05-31 — FREEZE `deepswe-sub-v1`, begin scored run

## 2026-05-31 — FREEZE `deepswe-sub-v1`, begin scored run

**Freeze SHA:** `d675d4690f328464d62a2c30cee27279faa27962` (tag `deepswe-sub-v1`).

**What is frozen.** The methodeutic harness for PRD-shaped feature tasks (design-doc → build-tools →
Phase 3.5 dual cross-family adversary → implement-spec → Phase 5 + RESIDUE re-type → bounded
regression-guarded revision), Composer 2.5 craft/recon + Gemini 3.5 Flash adversary. `frozen/HASHES.txt`
regenerated at the freeze SHA and verifying (13 artifacts). `frozen/eligible.txt` = 109 tasks
(113 − 4 documented gold-fails-verifier defects per `audit-v1`). `frozen/COMPARISONS.txt` declares
the pre-data comparison: primary = three-arm harness-richness ablation (scaffold vs `baseline-comp`
vs `baseline-flash`), two paired McNemar tests at Bonferroni α=0.025; secondary (exploratory, §3b) =
codex two-harness at GPT-5.5.

**Why this freeze, why now.** Goal: validate the methodeutic harness on DeepSWE — a new
feature-implementation instantiation of the IR, not the recon/craft/audit bug-fix harness validated
on Verified/Pro. The scaffold resolve rate is the validation; the scaffold-vs-`baseline-comp`
ablation (model held fixed, harness toggled) is the clean typed-mode on/off isolation the
methodeutic-harness paper names as missing future work.

**Pre-freeze validation discharged (in `WORKLOG_PREFREEZE.md`).** Phase A n=10 Composer/Flash scaffold
(40% RESOLVED); three end-to-end canary smokes through the frozen `fleet.sh` driver — `scaffold-codex`,
api-mode `scaffold` (Composer/Flash), and the multi-box paired dispatch — each RESOLVED reward=1 on
`abs-module-cache-flags`. Post-v2 harness improvements folded in and re-hashed: the grade-NA fix
(`git config safe.directory '*'` in `dsr.py`), `revert_test_files_in_workdir` source-only-discipline
inserts in `run_arm.sh`, and the codex arms (inert for this run; used only in §3b).

**Run config.** 8× m7i.xlarge spot, us-west-2, ~$0.09/hr. 109 eligible × 3 arms = 327 cells,
1 trial/cell. Coordinator ceiling 2400s, max-attempts 2, ledger-resumable. Budget: ~$6 EC2
(authorized ≤ $20), Composer/Flash marginal-zero on subscription + free gemini-cli.

**Fault runbook (banked from `swebench-pro` worklog).** Watch the ledger for: a fast-fail wave
(sub-2-min cells with 0-byte patches + 401 strings → `PROVIDER_CRED_REJECT`, halt + re-push creds +
resume); cells past p95 / over-ceiling (grader-side flake → SSH in before assuming capability loss);
box death (account guardrail at 00:00 PT → re-provision + re-dispatch, coordinator skips terminal
verdicts). Run launched ~09:30 PT, ~7h wall, finishes before the midnight guardrail.
