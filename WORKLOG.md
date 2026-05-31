# deepswe-run worklog — `deepswe-sub-v1`

Newest first. This is the **scored-run trail** for the frozen artifact `deepswe-sub-v1`:
validating the methodeutic harness on DeepSWE (feature-implementation tasks). Pre-freeze
development history is in [`WORKLOG_PREFREEZE.md`](WORKLOG_PREFREEZE.md). Per PREREGISTRATION
§10/§11, each scored tag gets its own worklog; this one carries only `deepswe-sub-v1`'s run.

## 2026-05-31 — FREEZE `deepswe-sub-v1`, begin scored run

**Freeze SHA:** _recorded in the follow-up commit after the tag is cut._

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
