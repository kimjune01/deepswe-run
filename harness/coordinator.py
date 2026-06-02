#!/usr/bin/env python3
"""coordinator.py — DeepSWE dynamic-dispatch coordinator for the scored run.

Adapted from sibling SWE-bench Pro's coordinator pattern but trimmed for the
DeepSWE setup:
  - work unit is (task_id, arm) instead of single instance_id
  - per-token auth (CURSOR_API_KEY + GEMINI_API_KEY pushed to box .dsr.env)
  - dispatches `bash harness/run_arm.sh <task-id> <arm>` on the box
  - ledger of (task_id, arm) -> verdict tuple for resume

Run: python3 harness/coordinator.py --boxes 4 \\
       --eligible frozen/eligible.txt --arms scaffold \\
       --max-tasks 3

v4 phasing (2026-05-30):
  Phase A (this run): `scaffold` only — Composer 2.5 + Flash adversary, the
    v3 freeze shape. 4-box concurrency target (per-token API auth, no
    subscription throttle).
  Phase B (checkpoint, later): add `scaffold-codex` + `baseline-codex` — both
    GPT-5.5 via codex CLI subscription. Codex subscription tier accepts
    ~8 concurrent sessions safely; rate-limit backoff is in run_arm.sh's
    codex_call wrapper.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import queue
import subprocess
import sys
import threading
import time

REPO = pathlib.Path(__file__).resolve().parent.parent
LEDGER_DEFAULT = REPO / "results" / "coordinator" / "ledger.jsonl"
SSH = ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=15"]

_ledger_lock = threading.Lock()


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def load_done(ledger: pathlib.Path) -> set[tuple[str, str]]:
    """Terminal verdicts already in the ledger (resume)."""
    done: set[tuple[str, str]] = set()
    if not ledger.exists():
        return done
    for line in ledger.read_text().splitlines():
        try:
            r = json.loads(line)
            if r.get("state") in ("DONE", "INCOMPLETE"):
                done.add((r["task_id"], r["arm"]))
        except Exception:
            pass
    return done


def record(ledger: pathlib.Path, rec: dict) -> None:
    rec["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with _ledger_lock:
        ledger.parent.mkdir(parents=True, exist_ok=True)
        with open(ledger, "a") as f:
            f.write(json.dumps(rec) + "\n")


def provision_box(name: str, deep_swe_dir: str, deepswe_run_dir: str, cursor_key: str, gemini_key: str) -> dict | None:
    """Provision a single fresh spot box via smoke_arm_ec2.sh's setup phase,
    but stop after bootstrap (don't run an arm). Returns env dict (PUBIP, KEY)
    or None on failure."""
    # For the smoke, we reuse smoke_arm_ec2.sh with a sentinel arm assignment
    # that exits immediately after bootstrap+keypush. Cleaner long-term move:
    # split bootstrap out of smoke_arm_ec2.sh into a separate setup_box.sh.
    # For now, dispatch by directly running provisioning inline.
    raise NotImplementedError("provision_box: see TODO in coordinator.py — split bootstrap out of smoke_arm_ec2.sh")


# codex arms (gpt-5.5 via codex CLI) run ~3-4x slower than Composer; a 2400s
# ceiling fires routinely on hard cells (observed: pwntools needed 43min). The
# sibling SWE-bench Pro uses 36000s precisely so the local timeout is a
# never-fires backstop. We make the budget arm-aware and the REMOTE process
# self-limit (D4 + D1 of the 2026-06-02 A3 investigation).
_CODEX_ARMS = {"scaffold-codex", "baseline-codex"}


def remote_ceiling(arm: str, base_ceiling: int) -> int:
    """Per-arm remote budget. codex arms get a floor of 6000s; others keep base."""
    if arm in _CODEX_ARMS:
        return max(base_ceiling, 6000)
    return base_ceiling


def _ssh_run(pem: str, pubip: str, cmd: str, timeout: int) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(
            SSH + ["-i", pem, f"ec2-user@{pubip}", cmd],
            capture_output=True, text=True, timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return None


def cleanup_box(box_env: dict, task_id: str) -> None:
    """Pre-attempt: kill any LIVE run_arm/codex tree for this task before a new
    dispatch (D2 — prevents double-dispatch onto an orphan). Scoped to the task
    where possible; the stray codex/cursor-agent sweep is safe because the fleet
    runs one (task,arm) per box serially. run_arm.sh resets its own workspace, so
    no git reset here — we only guarantee no live writer remains."""
    pem = f"/tmp/{box_env['KEY']}.pem"
    pubip = box_env["PUBIP"]
    kill = (
        f"pkill -9 -f 'run_arm.sh {task_id}' 2>/dev/null; "
        "pkill -9 -f 'codex' 2>/dev/null; "
        "pkill -9 -f 'cursor-agent' 2>/dev/null; "
        "sleep 2; echo CLEANED"
    )
    _ssh_run(pem, pubip, kill, timeout=40)


def harvest_grade(box_env: dict, task_id: str, arm: str) -> dict | None:
    """Read a COMPLETE grade.json off the box (D3 — recover a pipeline that
    finished just after the local timeout). Completion is gated on the
    revision-decision.txt marker run_arm.sh writes near the end; without it the
    grade may be stale/partial, so we decline rather than accept a half-write."""
    pem = f"/tmp/{box_env['KEY']}.pem"
    pubip = box_env["PUBIP"]
    d = f"results/runs/{task_id}/{arm}"
    probe = (
        f"cd ~/deepswe-run && "
        f"if [ -s {d}/audit/revision-decision.txt ] && [ -s {d}/grade.json ]; then "
        f"jq . {d}/grade.json 2>/dev/null; "
        f"echo CLASS=$(cat {d}/failure_class.txt 2>/dev/null); "
        f"echo WALL=$(cat {d}/wall.txt 2>/dev/null); "
        f"else echo NO_COMPLETE_GRADE; fi"
    )
    r = _ssh_run(pem, pubip, probe, timeout=60)
    if r is None or "NO_COMPLETE_GRADE" in (r.stdout or ""):
        return None
    return _parse_verdict(r.stdout)


def _parse_verdict(stdout: str) -> dict | None:
    reward = None; cls = None; wall = None
    for line in stdout.splitlines():
        if line.startswith('  "reward"'):
            try:
                reward = int(line.strip().split(":")[1].strip().rstrip(","))
            except Exception:
                pass
        elif line.startswith("CLASS="):
            cls = line.split("=", 1)[1].strip()
        elif line.startswith("WALL="):
            try:
                wall = int(line.split("=", 1)[1].strip())
            except Exception:
                pass
    if reward is None:
        return None
    return {"reward": reward, "class": cls, "wall": wall}


def run_arm_on_box(box_env: dict, task_id: str, arm: str, ceiling: int) -> dict | None:
    """SSH to box, dispatch run_arm.sh under a REMOTE self-limit so the box kills
    its own process tree on overrun (D1 — no orphan reparented to init). The local
    SSH timeout is a generous backstop (remote_ceil + slack). On any fault we
    harvest a late-completed grade before declaring the work lost (D3).
    Returns verdict dict (reward + class + wall) or None on genuine fault."""
    pem = f"/tmp/{box_env['KEY']}.pem"
    pubip = box_env["PUBIP"]
    rceil = remote_ceiling(arm, ceiling)
    rlog = f"/tmp/runarm-{task_id}-{arm}.log"
    # timeout -k 60: SIGTERM at rceil, SIGKILL 60s later if it ignores TERM.
    remote = (
        "source ~/.dsr.env && "
        f"cd ~/deepswe-run && "
        f"timeout -k 60 -s TERM {rceil}s bash harness/run_arm.sh {task_id} {arm} > {rlog} 2>&1; "
        f"RC=$?; tail -80 {rlog}; echo RUNARM_RC=$RC; "
        f"jq . results/runs/{task_id}/{arm}/grade.json 2>/dev/null; "
        f"echo CLASS=$(cat results/runs/{task_id}/{arm}/failure_class.txt 2>/dev/null); "
        f"echo WALL=$(cat results/runs/{task_id}/{arm}/wall.txt 2>/dev/null)"
    )
    r = _ssh_run(pem, pubip, remote, timeout=rceil + 300)
    if r is None:
        # Local backstop fired (rare now the remote self-limits). The remote may
        # still be wrapping up or hung past its own timeout -- harvest if complete.
        log(f"  {task_id}/{arm}: local SSH backstop ({rceil + 300}s) hit — harvesting")
        return harvest_grade(box_env, task_id, arm)
    if r.returncode != 0:
        # SSH transport failure (the remote `;`-chain ends in `echo WALL` so a
        # connected box returns 0 even when run_arm.sh timed out -- a non-zero rc
        # here means ssh itself failed). Harvest a complete grade if one exists.
        log(f"  {task_id}/{arm}: SSH transport rc={r.returncode} — harvesting")
        return harvest_grade(box_env, task_id, arm)

    # The authoritative signal is RUNARM_RC (run_arm.sh's own exit), NOT r.returncode.
    # Trust the inline-emitted verdict ONLY on a clean exit (RUNARM_RC=0); on a
    # `timeout` kill (124) or any error the inline `jq grade.json` may have read a
    # stale/pre-revision/partial grade -- fall back to the marker-gated harvest,
    # which refuses anything without the revision-decision.txt completion marker.
    # (gemini volley 2026-06-02: inline verdict on the kill path bypasses the gate.)
    runarm_rc = None
    for line in r.stdout.splitlines():
        if line.startswith("RUNARM_RC="):
            try:
                runarm_rc = int(line.split("=", 1)[1].strip())
            except Exception:
                pass
    if runarm_rc == 0:
        verdict = _parse_verdict(r.stdout)
        if verdict is not None:
            return verdict
        # Clean exit but inline parse failed (jq drift, truncation, read race).
        # The grade is complete (RC=0), so the marker-gated harvest recovers it
        # rather than discarding a finished verdict. (gemini volley r2.)
        log(f"  {task_id}/{arm}: RUNARM_RC=0 but inline parse failed — marker-gated harvest")
        return harvest_grade(box_env, task_id, arm)
    log(f"  {task_id}/{arm}: RUNARM_RC={runarm_rc} (killed/errored) — marker-gated harvest")
    return harvest_grade(box_env, task_id, arm)


def pull_receipts(box_env: dict, task_id: str, arm: str, dest: pathlib.Path) -> None:
    """scp the arm's results dir from box to dest/<task_id>/<arm>/.
    Pre-create dest/<task_id> so scp -r nests <arm> beneath it consistently
    (scp's behavior differs when target dir pre-exists vs doesn't)."""
    pem = f"/tmp/{box_env['KEY']}.pem"
    pubip = box_env["PUBIP"]
    task_dest = dest / task_id
    task_dest.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["scp", "-q", "-i", pem, "-o", "StrictHostKeyChecking=no", "-r",
         f"ec2-user@{pubip}:/home/ec2-user/deepswe-run/results/runs/{task_id}/{arm}",
         str(task_dest)],
        capture_output=True, text=True,
    )


def worker(name: str, box_env: dict, work_q: queue.Queue, ledger: pathlib.Path,
           dest: pathlib.Path, ceiling: int, max_attempts: int) -> None:
    """Pull work units (task_id, arm) from queue; run on assigned box."""
    while True:
        try:
            task_id, arm = work_q.get_nowait()
        except queue.Empty:
            log(f"{name}: queue empty — retiring")
            return
        attempt = 0
        result = None
        while attempt < max_attempts and result is None:
            attempt += 1
            log(f"{name} -> {task_id}/{arm} (attempt {attempt}/{max_attempts})")
            # D2: never dispatch onto a live tree from a prior attempt's orphan.
            cleanup_box(box_env, task_id)
            t0 = time.time()
            result = run_arm_on_box(box_env, task_id, arm, ceiling)
            wall = int(time.time() - t0)
            if result is not None:
                log(f"  {name}: {task_id}/{arm} -> reward={result['reward']} "
                    f"class={result['class']} wall={result['wall']}s (ssh-wall={wall}s)")
                pull_receipts(box_env, task_id, arm, dest)
                record(ledger, {
                    "task_id": task_id, "arm": arm, "box": name, "state": "DONE",
                    "reward": result["reward"], "class": result["class"],
                    "wall": result["wall"], "ssh_wall": wall, "attempt": attempt,
                })
            else:
                log(f"  {name}: {task_id}/{arm} attempt {attempt} fault")
        if result is None:
            record(ledger, {
                "task_id": task_id, "arm": arm, "box": name, "state": "INCOMPLETE",
                "reason": f"{max_attempts}_attempts_failed",
            })
        work_q.task_done()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--eligible", required=True, help="path to eligible.txt (one task_id per line)")
    p.add_argument("--arms", default="scaffold")
    p.add_argument("--boxes-env", required=True,
                   help="JSON file: [{\"name\":\"box1\",\"PUBIP\":\"…\",\"KEY\":\"…\"}, …]")
    p.add_argument("--ledger", default=str(LEDGER_DEFAULT))
    p.add_argument("--dest", default=str(REPO / "results" / "coordinator" / "runs"))
    p.add_argument("--ceiling", type=int, default=2400, help="per-arm timeout seconds")
    p.add_argument("--max-attempts", type=int, default=2)
    p.add_argument("--max-tasks", type=int, default=0, help="cap on # tasks (0 = all)")
    args = p.parse_args()

    eligible = [t.strip() for t in pathlib.Path(args.eligible).read_text().splitlines() if t.strip()]
    if args.max_tasks > 0:
        eligible = eligible[:args.max_tasks]
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    log(f"eligible={len(eligible)} arms={arms} -> {len(eligible)*len(arms)} work units")

    boxes = json.loads(pathlib.Path(args.boxes_env).read_text())
    log(f"boxes: {[b['name'] for b in boxes]}")

    ledger = pathlib.Path(args.ledger)
    done = load_done(ledger)
    log(f"resume: {len(done)} terminal verdicts already in ledger")

    work_q: queue.Queue = queue.Queue()
    for t in eligible:
        for a in arms:
            if (t, a) not in done:
                work_q.put((t, a))
    log(f"queued: {work_q.qsize()} work units")

    dest = pathlib.Path(args.dest); dest.mkdir(parents=True, exist_ok=True)
    threads = []
    for b in boxes:
        thr = threading.Thread(
            target=worker, name=b["name"],
            args=(b["name"], b, work_q, ledger, dest, args.ceiling, args.max_attempts),
            daemon=True,
        )
        thr.start()
        threads.append(thr)
    for thr in threads:
        thr.join()

    log("coordinator done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
