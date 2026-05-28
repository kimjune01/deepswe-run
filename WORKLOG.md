# DeepSWE submission worklog — pre-freeze

Newest first. This is the **development trail** before any scored run. A scored tag
(`deepswe-sub-v1`) opens its own worklog on freeze, per PREREGISTRATION §3/§10.

## 2026-05-27 (later still) — EC2 oracle defect-audit: a HARNESS fault, not bad goldens (procedure lesson)

Ran the gold-patch defect audit on one spot m7i.8xlarge (32 vCPU/128GB, separate spot quota, ~$0.50,
10-wide, self-terminating). **First run: all 113 returned `reward=NA, rc=0`** — and that is emphatically
**our fault, not 113 defective goldens.** Diagnosis from the box: `result.json` showed `RuntimeError`,
`trial.log` dumped docker's *usage text* → pier invoked `docker compose` and AL2023's `dnf install
docker` ships the engine **without the Compose v2 plugin** (buildx present, compose absent, no
`~/.docker/cli-plugins`). Pier uses Compose to bring up the sandbox + egress-proxy pair, so every trial
errored before grading. Locally it worked only because Docker Desktop bundles Compose.

**Verdict-integrity call (mirrors the Pro discipline):** an all-uniform failure across every task is a
platform/harness signature, never a bench finding. Calling these "defects" would be the same
loss-laundering error in reverse — blaming the bench for our missing plugin. Result voided, not recorded.

**Fix:** bootstrap now installs the Compose plugin into `~/.docker/cli-plugins` and **asserts**
`docker compose version` + `docker buildx version` (loud FATAL, never silent NA). Re-running.

**Procedure lesson (the load-bearing one): the REAL scaffold run on EC2 grades through pier too**, so
its box bootstrap needs the identical Compose+buildx setup. A $0.50 throwaway audit de-risked the real
run's environment before we built the coordinator around it — exactly why the cheap check goes first.
Pinned in PREREGISTRATION §3a.

(Also hit `MaxSpotInstanceCountExceeded` on the immediate retry: the torn-down box still held the
32-vCPU spot quota while `shutting-down`; must `wait instance-terminated` before relaunching a
same-size spot box. Minor op note.)

## 2026-05-27 (later) — smoke tests + the "bench is the tasks" reframe

- **First smoke (`pier run --agent claude-code` Sonnet 4.5 on `ts-pattern-match-each`):** validated
  the full live path (ECR image up, claude-code installed + running in-sandbox under `allow_internet=
  false` with `api.anthropic.com` allowlisted, paid key). Confirmed plumbing, then **killed** it once
  the reframe (below) made it clear this was a *baseline-arm* run, not the scaffold — it no longer
  bought us anything toward the headline. Containers torn down (0 left running).
- **Reframe — the bench is the tasks, not Pier.** DeepSWE = the 113 Harbor tasks + each task's own
  verifier; Pier is just Datacurve's runner. So the scaffold arm runs under **our own driver** (same
  as Pro), graded by the task verifier executed unmodified via Pier; `pier run --agent` is kept only
  for the single-agent baseline arms. Prereg §1.3/§3a/§6/§8/§9 + README updated.
- **No-cheating invariants pinned (§9):** same 113 tasks, same unmodified per-task verifier (identical
  grading path to the leaderboard), agent never sees `solution/` or grade-time `test.patch`,
  source-only diffs, instance-blind; the agent *runner* is the only declared variable, grader held
  constant across arms.
- **Task-set integrity verified:** 113 manifest == 113 dirs, no mismatch, every task has
  `task.toml`+`instruction.md`+`tests/test.sh`; all 113 have `solution/`+`tests/test.patch`. Mix: 35
  TS / 34 Py / 34 Go / 5 Rust / 5 JS; 106 feature / 4 bugfix / 3 enhancement.
- **Second smoke (RUNNING, `--agent oracle`, $0 model):** applies each task's reference solution and
  grades via the verifier. Fault-reveals the real environment + unmodified verifier path (the
  load-bearing piece for scaffold-arm grading) AND doubles as the §5 defect check (does gold pass its
  own verifier?). **Result: reward 1.0 in 20s** (image warm) — gold passes its own verifier, the
  unmodified verifier path is sound, and `ts-pattern-match-each` is non-defective. The scaffold-arm
  grading mechanism (grade an external diff via the task verifier) is now de-risked on a real task.

## 2026-05-27 — configure: clone, install, validate, fork

Stood up the submission environment alongside the live SWE-bench Pro run (which holds the EC2 fleet
+ the paid API window; this work is local-only and shares nothing but the operator's attention).

- **Cloned** `datacurve-ai/deep-swe` (113 Harbor tasks, `source_dataset: swe-bench-ultra`, images on
  `public.ecr.aws`) and `datacurve-ai/pier` (Harbor-compatible harness, ATIF v1.7 trajectories).
- **Installed** `datacurve-pier` 0.2.0 (`uv tool install`). Docker daemon up locally; no Modal, so
  the execution path is **local docker** (their images are public-ECR, pullable). Model cost path:
  claude-code on Max subscription + codex on its own sub = $0 model spend; only local compute.
- **Validated plumbing end-to-end**: `pier run --agent oracle --env docker` on the bundled
  hello-world task passed (reward 1.0, 29s), wrote the full trial tree
  (`agent/`, `verifier/{reward.txt,ctrf.json,test-stdout.txt}`, per-trial + job `result.json` with
  token/cost stats). Confirms the provenance shape we publish (PREREGISTRATION §7).
- **Custom-agent hook confirmed:** `pier run --agent-import-path <module>` accepts a custom agent.
  This is how the recon→craft→audit composition plugs in as a first-class Pier agent (not just
  `--agent claude-code`), so the submission showcases the actual contribution: the composition.
- **Forked** `datacurve-ai/deep-swe` → `kimjune01/deep-swe` for the eventual PR (a public signal even
  if never merged; the PR is part of the litmus test).
- **Wrote** `PREREGISTRATION.md` at parity with the Pro prereg: predicate, fixed fault state machine,
  verdict-independent reclassification, official-Pier-only grading, whole-set stopping rule, full
  trajectory publication, and the **harness ablation DeepSWE skipped** (scaffold vs single-agent
  claude-code vs codex on the same 113, Fisher exact + Wilson).

**Not yet run.** A scored pass is a *measurement* and requires freeze (§10) + the defect audit (§5) +
the `--agent-import-path` adapter. Deferred until the Pro run frees the subscription quota (the paid
key is earmarked for Pro until ~2026-05-29 03:00). Configuration is complete; the run is staged.

**Framing correction (the bench is the tasks, not Pier).** DeepSWE = the 113 Harbor tasks + each
task's own verifier; Pier is merely Datacurve's runner. Treating "run through Pier" as the bench
repeats the harness/model conflation we attack in their work. So:
- **Scaffold arm runs under our own driver** (same as Pro), in the task image, emitting a source-only
  diff — NOT `pier run`. Contorting our composition into Pier's single-agent loop buys nothing.
- **Pier's only load-bearing role is the grader**: execute the task's unmodified verifier
  (`test.patch` + `test.sh`) so grading is demonstrably theirs, not hand-rolled.
- **`pier run --agent claude-code/codex`** stays for the single-agent baseline arms only (faithful
  Datacurve setup), grading held identical across arms. The smoke run (`--agent claude-code` Sonnet)
  is therefore a **baseline-arm** data point, not the scaffold.

**Execution decision:** scored run on the **EC2 fleet** (Pro coordinator reused), not local docker —
113 × 3 passes won't fit the laptop's disk or wall-clock. Driver reuse is near-total; the box
bootstrap adds pier (for grading + baselines) + deep-swe clone. `DOCKER_FAULT` (ECR pull/build)
carries more weight here. See PREREGISTRATION §3a.

**Next:** (1) write the recon→craft→audit Pier agent adapter; (2) port the Pro coordinator/run_fleet
to the `pier run` per-task command + `result.json` verdict parse; (3) run the §5 defect+originality
audit on all 113; (4) freeze `deepswe-sub-v1`; (5) scored pass + baselines on the fleet;
(6) publish trajectories + open the PR.
