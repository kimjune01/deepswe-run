# Legible skills + the harness-richness experiment — recon → craft → audit (Gemini 3.5 Flash + Composer 2.5)

Two goals, neither involving Datacurve as a recipient: **(1)** make the recon→craft→audit scaffold
**legible** — publish every task's trajectory, diff, verifier output, and cost, re-derivable from a
frozen tag; **(2)** **dispel "less prompting is better"** — test whether a richer scaffold resolves
more than minimal single-agent prompting, same models, same tasks, same grader, paired stats.

**Primary model pair (amended 2026-05-28):** Gemini 3.5 Flash recon/adversary + Composer 2.5 craft
(both standard tier; `composer-2.5-fast` 6× markup is forbidden in the scored run). Was Sonnet 4.5
+ GPT-5.5; swap was ~10× cost-driven, capability-equivalent for this task class. CLI setup, smoke
tests, and key hygiene in [`docs/PROCEDURES.md`](docs/PROCEDURES.md). Per-token rates verified
against published vendor pricing 2026-05-29 — see [`docs/composer-2.5-review.md`](docs/composer-2.5-review.md) §F5.

[DeepSWE](https://github.com/datacurve-ai/deep-swe)'s 113 tasks are used only as a contamination-free
2026 substrate, graded by the unmodified [Pier](https://github.com/datacurve-ai/pier) verifier. Their
leaderboard/recognition/PR are out of scope. See [`PREREGISTRATION.md`](./PREREGISTRATION.md).

## What's here

| path | what |
|---|---|
| `PREREGISTRATION.md` | frozen-on-run methodology, at parity with our SWE-bench Pro prereg |
| `WORKLOG.md` | dated development + run trail |
| `skills/` | `design-doc`, `build-tools`, `implement-spec`, `verify-spec`, `compose` — the skill files dispatched by `dsr` and the agents |
| `harness/` | `bootstrap.sh` (per-token key validation), `provision_oracle_ec2.sh` (the May 27 oracle audit), `smoke_box.sh` (the EC2 box-side smoke), `audit_oracle.sh` + `box_audit.sh` (oracle support) |
| `harness/feature/` | `dsr.py` (the feature-task driver CLI), `build-tools-lessons.md`, `HYPOTHESIS_GRAPH.md`, per-task `run/<task-id>/` receipts |
| `external/` | mirrored leaderboard JSON, codex-audit results, deep-swe pin |
| `results/` | per-task verdict ledgers + run logs; `results/smoke/box/` for the EC2 smoke receipts |
| `docs/` | [PROCEDURES.md](docs/PROCEDURES.md), [composer-2.5-review.md](docs/composer-2.5-review.md), [COMPOSE-EVOLUTION.md](docs/COMPOSE-EVOLUTION.md), [PR_DRAFT.md](docs/PR_DRAFT.md) (staged for post-run) |

## The gold-patch audit (complete, tag `audit-v1`)

The most basic check before any model arm: does each task's own reference solution pass its own
verifier? Run on all 113 tasks (oracle agent, $0 model, one spot box, under a dollar), `deep-swe`
pinned at `2f0f4125`. Result: **109 pass, 4 fail** — `langchain-request-coalescing`,
`narwhals-rolling-window-suite`, `prometheus-transactional-reload-status`, `skrub-duration-encoding`,
each confirmed failing in isolation, cause unresolved. Full per-task verdicts in
`results/oracle_audit_ec2.jsonl`. The 4 defectives are excluded from the eligible denominator.

```bash
git clone https://github.com/datacurve-ai/deep-swe && cd deep-swe && git checkout 2f0f4125
uv tool install --python 3.12 datacurve-pier==0.2.0     # needs docker + Compose v2 plugin
for t in tasks/*/; do pier run -p "$t" --agent oracle --env docker; done
```

## The harness-richness experiment (skills built, smoke green, scored run pending)

The recon → craft → audit pipeline is wired and tested at the local-substrate level. Three arms,
one grader:

- **Scaffold arm** — `design-doc` (Flash) → `build-tools` (Composer-author with discipline) →
  Phase 3.5 dual-adversary review (Flash for soundness + Composer for combinatorial breadth) →
  `implement-spec` (Composer-craft) → Phase 4 single-adversary review (Flash) → `verify-spec`
- **Baseline arms** — single-agent `cursor-agent` (composer-2.5) and single-agent `gemini-cli`
  (gemini-3.5-flash), each driven minimally on the same task image
- **Grader** — each task's own verifier via Pier, identical across arms

### Validated this session (2026-05-29)

| measurement | result | receipts |
|---|---|---|
| H₉ cross-family overlap on new pair | bandit 37.9%, kysely 11.5% (both << 70% collapse threshold) | `harness/feature/run/{bandit-structured-nosec-directives,kysely-window-grouping-helpers}/transfer-risk-v1/` |
| H₈ Flash-as-author discipline ablation | discipline load-bearing (+100 PRD-quote density, +12 discriminating-input shape) | `…/bandit-…/transfer-risk-v1/H8-ABLATION.md` |
| H₈ Composer-as-author qualitative | Composer internalizes typed-acceptance protocol unprompted (RESIDUE block, helper functions, sound axis-crossing tests) | `…/bandit-…/transfer-risk-v1/composer-author-disciplined-test_proxy.py` |
| H₁ᵦ purpose-over-surface on Flash | correctly chose branch 2 on oxvg subtractive feature | `…/oxvg-structural-selector-preservation/transfer-risk-v1/flash-classify-raw.txt` |
| Phase 2-bis architectural decision | Phase 3.5 added to build-tools skill with `RESIDUE.md` carry-forward; dual-adversary wired | `skills/build-tools/skill.md` §Phase 3.5 |
| EC2 box-side infra smoke | REWARD 1 on kysely gold patch via fresh spot m7i.xlarge | `results/smoke/box/RESULT.md` |

Composer 2.5 living review with confidence-ranked findings + receipts:
[`docs/composer-2.5-review.md`](docs/composer-2.5-review.md).

### Remaining before freeze

- Model-arm orchestration on local docker (workspace-edit + diff capture for cursor-agent and
  gemini-cli; free-tier cost)
- Multi-box dispatch smoke (`coordinator.py` borrowed from sibling swebench-pro, 2-box EC2)
- `run_order.txt` commit, eligible denominator file finalize, freeze + run

## Running the EC2 box smoke

```bash
# defaults: DEEP_SWE_DIR=../deep-swe DEEPSWE_RUN_DIR=. TASK_ID=kysely-window-grouping-helpers
bash harness/smoke_box.sh                                  # smoke kysely on spot m7i.xlarge
bash harness/smoke_box.sh bandit-structured-nosec-directives  # different task
DEEP_SWE_DIR=/other/deep-swe bash harness/smoke_box.sh     # override source dir
# ~$0.01 EC2, ~3 min wall, self-terminates on EXIT trap, cancels spot request on teardown
```

Receipts land in `results/smoke/box/`. Expects REWARD 1 from gold patch as the box-infra freeze
gate. See `results/smoke/box/RESULT.md` for the 2026-05-29 run.
