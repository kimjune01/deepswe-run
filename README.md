# A prose-compiler stage: PRD → typed-acceptance gate → impl → cross-family-audited revision

This repo publishes one stage of a prose compiler — the stage that takes a PRD-shaped feature
spec and produces a gradeable software artifact, with well-defined I/O contracts so other
stages chain in front (PRD discovery) or after (deployment, observability).

**The pipeline this stage implements:**
```
PRD → design-doc       (schema-tight classification + acceptance criteria + residue)
    → build-tools | compose   (proxy gate authored from PRD; routed by FEATURE-SHAPE)
    → Phase 3.5 cross-family adversary on the gate (typed-acceptance: ENTAILMENT,
       DISCRIMINATOR, SPECULATION, WRONG → SPECULATION carried in RESIDUE.md)
    → implement-spec   (impl in workspace)
    → Phase 5 adversary on impl + RESIDUE re-type (SPECULATION → ENTAILMENT when impl
       gives the speculation concrete shape)
    → bounded one-shot revision pass on ENTAILMENT (regression-guarded: revert if base
       regressed or REWARD dropped)
    → grade (per-task verifier, unmodified)
```

**Three deliverables** (in durability order):

1. **The compiler stage** — `skills/`, `harness/`, `frozen/`, `STANDARD_PROMPTS.md`, the typed-
   acceptance protocol, the RESIDUE.md carry-forward, the `dsr` CLI. Reusable on any PRD-shaped
   feature spec with any coding-capable LLM that follows schema-tight prompts. **The artifact
   that travels.**
2. **A bench measurement that validates the stage:** Composer 2.5 in this scaffold on 109 of
   DeepSWE-113 (4 audit-v1 defectives excluded), pass@1 reported as Wilson 95% interval. The
   first published Composer 2.5 datapoint on the DeepSWE substrate — DeepSWE's leaderboard does
   NOT include Composer 2.5, likely because of the API gating named in deliverable #3.
3. **A methodology essay** on what we discovered while trying to construct a defensible
   baseline. Cursor's structural prevention of independent Composer evaluation is the same
   model-vs-system collapse the [DeepSWE audit](https://june.kim/blog/auditing-deepswe)
   identified, now in a different vendor stack. Pattern recognition over n=2 is suggestive, not
   proof — but earns the writeup as a methodology observation.

**Models used.** Composer 2.5 for craft + author + recon (via `cursor-agent -p -f -w $WORK`);
Gemini 3.5 Flash for Phase 3.5 adversary soundness lens (via direct API per `gemini_api.py`);
Composer also serves as Phase 3.5 breadth lens (dual-adversary). Both standard-tier; `composer-
2.5-fast` 6× markup is forbidden in the scored run. Per-token rates verified against published
vendor pricing 2026-05-29 — see [`docs/composer-2.5-review.md`](docs/composer-2.5-review.md) §F5.

[DeepSWE](https://github.com/datacurve-ai/deep-swe)'s 113 tasks are used as a contamination-free
2026 substrate, graded by the unmodified [Pier](https://github.com/datacurve-ai/pier) verifier.
Their leaderboard/recognition/PR are out of scope. See [`PREREGISTRATION.md`](./PREREGISTRATION.md).

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

## The scored run (1 arm, 1 number)

Single arm: Composer 2.5 in our scaffold on 109 eligible tasks. **No comparison baseline** —
see §3a of [`PREREGISTRATION.md`](PREREGISTRATION.md) for why (TL;DR: Cursor structurally
prevents independent Composer measurement; constructing a defensible baseline outside the
Cursor stack would have either violated their ToS or measured a Composer behavior they didn't
optimize for). Reported as Wilson 95% interval.

The reason no baseline is *itself a finding*, written up as the methodology essay
([deliverable #3](#deliverables) above).

### Architecture validated this session (2026-05-29)

| component | how | receipt |
|---|---|---|
| Compose stage end-to-end on EC2 | scaffold REWARD 1 on kysely-window-grouping-helpers via fresh spot m7i.xlarge | `results/coordinator/test-drive-v2/runs/kysely-window-grouping-helpers/scaffold/` |
| Dual-adversary at Phase 3.5 | n=2 substrate measurement (bandit 37.9% overlap, kysely 11.5%) | `harness/feature/run/<task>/transfer-risk-v1/` |
| Composer-as-recon dominates Flash-as-recon (n=3 head-to-head) | schema-tight prompt validation | `results/recon-comparison/` |
| Multi-box coordinator dispatch | 2 concurrent spot boxes, ledger-based resume, scp pull, teardown clean | `results/smoke/multibox/`, `results/coordinator/test-drive-v[12]/` |
| Six bugs caught + fixed by test-drive validation | cursor-agent --workspace, python3-dsr symlink, git pathspec :!, scp -r nesting, multibox keypair collision, classifier '0\n0' grep | commits 52c070b, 6f226fd, 1ea7148, 2aa0b96 |

Frozen tag: `frozen-skills-v2` at commit `1ea7148`. The skill collection is what's frozen; the
scored run (when launched) reads from this tag's hash manifest and refuses to start on drift.

Composer 2.5 living review with confidence-ranked findings + receipts:
[`docs/composer-2.5-review.md`](docs/composer-2.5-review.md).

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
