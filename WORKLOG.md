# deepswe-run worklog — `deepswe-sub-v2` (supersedes `deepswe-sub-v1`)

Newest first. This is the **scored-run trail** for validating the methodeutic harness on DeepSWE
(feature-implementation tasks). `deepswe-sub-v1` was frozen and dispatched but aborted ~30 min in on
a discovered defect (below); `deepswe-sub-v2` is the clean restart. Pre-freeze development history is
in [`WORKLOG_PREFREEZE.md`](WORKLOG_PREFREEZE.md). Per PREREGISTRATION §10/§11, each scored tag gets
its own trail.

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
