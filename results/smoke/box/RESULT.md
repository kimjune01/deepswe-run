# EC2 box-side smoke — REWARD 1

**Date:** 2026-05-29 12:11 PDT
**Task:** kysely-window-grouping-helpers
**Result:** REWARD 1 (base 22/22 pass, new 254/254 pass)
**Wall:** 2m 54s
**Cost:** ~$0.01 EC2 (~3 min m7i.xlarge spot, no model spend)

## What this validates (the freeze-gate items for box infra)

| item | status |
|---|---|
| AL2023 docker engine + Compose v2 plugin install + assertion | ✅ |
| pier 0.2.0 procurement via uv (lesson: needs Python 3.12) | ✅ |
| Public ECR image pull from us-west-2 | ✅ |
| `dsr ensure_box` + `docker exec` chain on EC2 | ✅ |
| Gold patch `git apply` in container | ✅ |
| `dsr grade` test.sh base + new end-to-end | ✅ identical reward to local |
| Cancel-spot-instance-request on teardown | ✅ no lingering quota |
| Self-terminate via EXIT trap + shutdown backstop | ✅ |
| Isolation from Pro's on-demand coord fleet | ✅ zero disturbance |

## What this does NOT validate

| item | next step |
|---|---|
| Model-arm orchestration (cursor-agent + gemini-cli workspace edits) | local docker first, then EC2 stamp |
| Multi-box dispatch via coordinator.py | local docker-compose, then 2-box EC2 |

## Operational lessons (banked for prereg + provision scripts)

1. **pier 0.2.0 requires Python ≥3.12.** AL2023 ships Python 3.11; pier won't install. Use `uv tool install --python 3.12 datacurve-pier==0.2.0`, never `python3.11 -m pip`. Banked in `harness/smoke_box.sh` and should be propagated to `harness/provision_oracle_ec2.sh` (currently uses `uv tool install` correctly already; only the smoke script was broken).
2. **`deep-swe` is private (`datacurve-ai/deep-swe`).** Cannot `git clone` on EC2 without SSH keys. Solution: scp the single task dir from local. Per-task is small (~40KB for kysely gold). For multi-task runs, scp the tasks dir as a tarball.
3. **`deepswe-run` HTTPS clone on EC2, not SSH.** Local origin uses SSH (`git@github.com:kimjune01/deepswe-run.git`) but EC2 boxes have no SSH key. Box bootstrap uses HTTPS (`https://github.com/kimjune01/deepswe-run.git`).

## Receipts

- `bootstrap.log` — Compose v2 + pier install
- `image-pull.log` — ECR pull (digest `9d62da20595f...`)
- `grade.log` / `grade.out` — full dsr grade output with model.patch summary, test.sh base/new
- `RESULT.md` — this file

## Smoke history

| attempt | result | issue | fix |
|---|---|---|---|
| v1 | FATAL pier install | `python3.11 -m pip` won't install pier 0.2.0 (requires >=3.12) | use uv with --python 3.12 |
| v2 | repos missing | `datacurve/deep-swe` wrong org (it's `datacurve-ai/`); also private | scp task dir from local |
| v3 | REWARD 1 | — | — |

## Cost ledger

- v1: ~$0.003 (~2 min spot)
- v2: ~$0.003 (~2 min spot)
- v3: ~$0.005 (~3 min spot)
- **Total: ~$0.011** across 3 attempts

EC2 spend was negligible. The wall-time gain from "rough is OK" was real — iterating fast through 3 failures was cheaper than designing the perfect single attempt.
