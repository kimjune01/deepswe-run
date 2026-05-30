#!/usr/bin/env python3
"""dsr — DeepSWE-run feature-task driver.

The CLI shell for the design-doc -> implement-spec -> verify-spec pipeline.
Each subcommand hoists one deterministic stratum out of the model prompt and
prints a readable, single-screen answer (the "CLI tool / live state" layer from
the Encoding Expertise trilogy). The model never re-derives what a tool can state.

Strata -> subcommands:
  identity (precondition)   dsr task   <id>      gradeable? defect-flagged? PRD.
  live state (ground truth) dsr box    <id> -- … run a cmd in the task container.
  regression baseline       dsr base   <id>      existing suite on clean base.
  the oracle (measurement)  dsr grade  <id>      hidden grader: proxy-vs-grade gap.
  legal moves (postcond)    dsr verdict <id>      validate the $VERDICT_FILE enum.

Stdlib only. No build step. Run: python3 harness/feature/dsr.py <cmd> <id>
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib  # py3.11+
except ModuleNotFoundError:  # minimal fallback for the flat keys we read
    tomllib = None

def _load_toml(path: Path) -> dict:
    if tomllib:
        with open(path, "rb") as f:
            return tomllib.load(f)
    # tiny parser: [section] headers + key = "value" / key = number lines
    out: dict = {}
    sec = out
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            sec = out.setdefault(line[1:-1].strip(), {})
            continue
        if "=" in line:
            k, v = (s.strip() for s in line.split("=", 1))
            v = v.strip("'\"")
            sec[k] = v
    return out

REPO = Path(__file__).resolve().parents[2]
TASKS_ROOT = Path(os.environ.get("DSR_TASKS", REPO.parent / "deep-swe" / "tasks"))

# The gold-defect audit (audit-v1) confirmed these 4 fail their own verifier in
# isolation. They are un-gradeable through no fault of the runner -> REJECTED at
# the identity precondition, never sent into the loop. (See results/, WORKLOG.)
KNOWN_DEFECTIVE = {
    "langchain-request-coalescing",
    "narwhals-rolling-window-suite",
    "prometheus-transactional-reload-status",
    "skrub-duration-encoding",
}

# KNOWN_BAD: the spec genuinely CONTRADICTS the grading test (spec says X, test
# requires not-X). Under binary grading + no-peek a spec-faithful agent cannot
# win -> a no-go zone, REJECTED like the defectives. This is an OUTER-LOOP
# classification (detecting it needs the test, which the blind inner loop cannot
# see). Gate before adding: only after a NARROWER interpretation that satisfies
# both spec and test has been ruled out — most apparent contradictions are merely
# underspecification (winnable via completeness/residue), not true contradiction.
# Empty so far: the dasel-html nested-li candidate was REFUTED on inspection (the
# PRD's "same-type siblings" + "block closes p" rules, read precisely, produce the
# test's tree — no contradiction). See build-tools-lessons.md.
KNOWN_BAD: set[str] = set()

# ── readable output helpers ───────────────────────────────────────────────────
BOLD, DIM, RED, GRN, YEL, RST = "\033[1m", "\033[2m", "\033[31m", "\033[32m", "\033[33m", "\033[0m"
if not sys.stdout.isatty():
    BOLD = DIM = RED = GRN = YEL = RST = ""


def rule(label: str = "") -> str:
    bar = "─" * max(4, 72 - len(label))
    return f"{DIM}{label} {bar}{RST}" if label else f"{DIM}{'─' * 72}{RST}"


LESSONS = REPO / "harness" / "feature" / "build-tools-lessons.md"


def append_lesson(kind: str, task_id: str, body: str):
    """Inner-loop log: append a durable, timestamped entry for the OUTER loop
    (the human/model supervisor) to inspect and turn into skill patches.
    The inner loop executes + abducts; it never edits skills."""
    import datetime
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    LESSONS.parent.mkdir(parents=True, exist_ok=True)
    if not LESSONS.exists():
        LESSONS.write_text(
            "# build-tools lessons\n\nInner-loop abduction log (newest appended). The outer loop "
            "(supervisor) reads this and patches the skills; the inner loop only executes + abducts.\n")
    with open(LESSONS, "a") as f:
        f.write(f"\n## {ts} · {kind} · {task_id}\n\n{body.rstrip()}\n")


def die(msg: str, code: int = 1):
    print(f"{RED}error:{RST} {msg}", file=sys.stderr)
    sys.exit(code)


def task_dir(task_id: str) -> Path:
    d = TASKS_ROOT / task_id
    if not d.is_dir():
        die(f"task not found: {task_id}  (looked in {TASKS_ROOT})")
    return d


def load_meta(d: Path) -> dict:
    return _load_toml(d / "task.toml")


# ── identity precondition: dsr task ───────────────────────────────────────────
def cmd_task(args):
    d = task_dir(args.id)
    meta = load_meta(d)
    m, env = meta.get("metadata", {}), meta.get("environment", {})
    sol = list((d / "solution").glob("*")) if (d / "solution").is_dir() else []
    sol_files = sum(1 for _ in (d / "solution").rglob("*")) if (d / "solution").is_dir() else 0
    defective = args.id in KNOWN_DEFECTIVE
    known_bad = args.id in KNOWN_BAD

    print(f"{BOLD}TASK{RST}  {args.id}")
    print(f"lang  {m.get('language','?')}   category  {m.get('category','?')}   "
          f"solution-files  {sol_files}")
    print(f"repo  {m.get('repository_url','?')} @ {m.get('base_commit_hash','?')[:7]}")
    print(f"image {env.get('docker_image','?')}")
    print(rule())
    if defective:
        print(f"DEFECT-AUDIT  {RED}FLAGGED{RST} — confirmed gold-fails-verifier (audit-v1)")
        print(f"PRECONDITION  {RED}REJECTED{RST} — un-gradeable; route to human bin, not the loop")
    elif known_bad:
        print(f"DEFECT-AUDIT  {GRN}clean{RST}   SPEC-VS-TEST  {RED}KNOWN_BAD{RST} — spec contradicts the test")
        print(f"PRECONDITION  {RED}REJECTED{RST} — unwinnable under binary+no-peek; route to human bin")
    else:
        print(f"DEFECT-AUDIT  {GRN}clean{RST} — gold passed its own verifier in audit-v1")
        print(f"PRECONDITION  {GRN}gradeable{RST}")
    print(rule("PRD (instruction.md)"))
    print((d / "instruction.md").read_text().strip())


# ── live state: dsr box <id> -- <cmd> ─────────────────────────────────────────
def container_name(task_id: str) -> str:
    return f"dsr-{task_id}"


def ensure_box(task_id: str) -> str:
    """Start (or reuse) the task container; return its name. Repo is at /app."""
    meta = load_meta(task_dir(task_id))
    image = meta.get("environment", {}).get("docker_image")
    if not image:
        die(f"{task_id}: no docker_image in task.toml")
    name = container_name(task_id)
    running = subprocess.run(["docker", "ps", "-q", "-f", f"name=^{name}$"],
                             capture_output=True, text=True).stdout.strip()
    if running:
        return name
    # remove a stopped one of the same name, then start detached, sleeping.
    subprocess.run(["docker", "rm", "-f", name], capture_output=True)
    r = subprocess.run(["docker", "run", "-d", "--name", name, "-w", "/app",
                        image, "sleep", "infinity"], capture_output=True, text=True)
    if r.returncode != 0:
        die(f"failed to start container: {r.stderr.strip()}")
    # Banked 2026-05-30 (codex smoke v1): `docker cp $WORK/. -> /app/.` from the
    # host changes /app ownership uid (host uid != container root), which makes
    # `git` inside the container refuse with "dubious ownership in repository
    # at '/app'". Every subsequent rev-parse/checkout silently fails — the grade
    # fallback masks it as "(empty — no model changes)" and the test.patch reset
    # step `git checkout base -- file || rm -rf file` then deletes the file we
    # were trying to preserve. One-time safe.directory='*' makes git trust the
    # repo regardless of who owns it. Survives all subsequent cp roundtrips.
    subprocess.run(["docker", "exec", name, "git", "config", "--global",
                    "--add", "safe.directory", "*"], capture_output=True)
    return name


def box_exec(task_id: str, cmd: str, quiet: bool = False) -> subprocess.CompletedProcess:
    name = ensure_box(task_id)
    return subprocess.run(["docker", "exec", "-w", "/app", name, "bash", "-lc", cmd],
                          capture_output=quiet, text=True)


def cmd_box(args):
    if not args.cmd:
        die("usage: dsr box <id> -- <command>")
    cmd = " ".join(args.cmd)
    r = box_exec(args.id, cmd)
    sys.exit(r.returncode)


# ── the oracle: dsr grade <id> ────────────────────────────────────────────────
def cmd_grade(args):
    """Run the HIDDEN grader exactly as Pier would, locally, as our private
    measurement instrument. Captures the model.patch (current /app diff vs base),
    applies test.patch, runs test.sh base + new. This is how we measure the
    proxy-vs-grade gap — NOT a signal the pipeline is allowed to consume."""
    d = task_dir(args.id)
    meta = load_meta(d)
    base = meta.get("metadata", {}).get("base_commit_hash")
    test_patch = (d / "tests" / "test.patch").read_text()

    # stage the hidden grader files into the container under /tests
    name = ensure_box(args.id)
    subprocess.run(["docker", "exec", name, "mkdir", "-p", "/tests"], check=True)
    subprocess.run(["docker", "cp", str(d / "tests" / "test.patch"), f"{name}:/tests/test.patch"], check=True)

    print(f"{BOLD}GRADE{RST} {args.id}  {DIM}(private oracle — base={base[:7]}){RST}")
    print(rule("captured model.patch (current /app vs base)"))
    diff = box_exec(args.id, f"git add -A && git diff --cached --stat {base} 2>/dev/null || git diff --stat",
                    quiet=True)
    print(diff.stdout.strip() or f"{DIM}(empty — no model changes){RST}")

    # reset test-patch-touched files to base, apply hidden test patch
    files = sorted(set(re.findall(r'^diff --git "?a/.+ "?b/(.+?)"?$', test_patch, re.M)))
    reset = " && ".join(f"(git checkout {base} -- '{f}' 2>/dev/null || rm -rf '{f}')" for f in files)
    box_exec(args.id, reset, quiet=True)
    ap = box_exec(args.id, "git apply --whitespace=nowarn /tests/test.patch", quiet=True)
    if ap.returncode != 0:
        die(f"test.patch failed to apply: {ap.stderr.strip()}")
    box_exec(args.id, "chmod +x test.sh", quiet=True)

    print(rule("test.sh base (regression suite)"))
    b = box_exec(args.id, "./test.sh base", quiet=True)
    print(tail(b.stdout + b.stderr))
    print(f"base  -> {pf(b.returncode)}")

    print(rule("test.sh new (hidden feature gate)"))
    n = box_exec(args.id, "./test.sh new", quiet=True)
    print(tail(n.stdout + n.stderr))
    print(f"new   -> {pf(n.returncode)}")

    reward = 1 if (b.returncode == 0 and n.returncode == 0) else 0
    print(rule())
    col = GRN if reward else RED
    print(f"{BOLD}REWARD {col}{reward}{RST}{BOLD}{RST}   "
          f"(base {'pass' if b.returncode==0 else 'FAIL'}, new {'pass' if n.returncode==0 else 'FAIL'})")
    append_lesson("grade/oracle", args.id,
                  f"REWARD={reward} (base={'pass' if b.returncode==0 else 'FAIL'}, "
                  f"new={'pass' if n.returncode==0 else 'FAIL'}) — grade-green truth for the proxy-vs-grade gap")


def pf(rc: int) -> str:
    return f"{GRN}pass{RST}" if rc == 0 else f"{RED}FAIL{RST}"


def tail(s: str, n: int = 12) -> str:
    lines = s.strip().splitlines()
    out = lines[-n:]
    pre = f"{DIM}… {len(lines)-n} lines above …{RST}\n" if len(lines) > n else ""
    return pre + "\n".join(out)


# ── canonical run (shared by grade + vary) ────────────────────────────────────
def run_canonical_new(task_id: str) -> subprocess.CompletedProcess:
    """Apply the hidden test.patch over whatever source is in /app and run the
    feature gate (`test.sh new`). test.patch only touches test files, so any
    source patch already applied survives. Returns the pytest result."""
    d = task_dir(task_id)
    base = load_meta(d).get("metadata", {}).get("base_commit_hash")
    name = ensure_box(task_id)
    subprocess.run(["docker", "exec", name, "mkdir", "-p", "/tests"], check=True)
    subprocess.run(["docker", "cp", str(d / "tests" / "test.patch"), f"{name}:/tests/test.patch"], check=True)
    tp = (d / "tests" / "test.patch").read_text()
    files = sorted(set(re.findall(r'^diff --git "?a/.+ "?b/(.+?)"?$', tp, re.M)))
    reset = " && ".join(f"(git checkout {base} -- '{f}' 2>/dev/null || rm -rf '{f}')" for f in files)
    box_exec(task_id, reset, quiet=True)
    box_exec(task_id, "git apply --whitespace=nowarn /tests/test.patch && chmod +x test.sh", quiet=True)
    return box_exec(task_id, "./test.sh new", quiet=True)


# ── varying patches on one repo: dsr vary <id> <manifest> [--patch P] ─────────
def cmd_vary(args):
    """Hold the repo constant, vary the patch (economy of search). Apply a patch,
    run our proxy gate AND the canonical feature gate, report agreement. Iterate
    with different --patch (gold, mutants, base) to measure the proxy gate's
    discriminating power vs canonical. Disagreement is the figure:
      canonical FAIL + proxy PASS -> proxy missed this behavior (coverage gap)
      canonical PASS + proxy FAIL -> proxy over-specified (unsound)."""
    man = json.loads(Path(args.manifest).read_text())
    run = man.get("proxy_gate", {}).get("run")
    d = task_dir(args.id)
    patch = Path(args.patch) if args.patch else (d / "solution" / "solution.patch")
    label = args.name or patch.stem

    base_reset(args.id)
    if patch.exists():
        name = ensure_box(args.id)
        subprocess.run(["docker", "cp", str(patch), f"{name}:/tmp/vary.patch"], check=True)
        ap = box_exec(args.id, "git apply --whitespace=nowarn /tmp/vary.patch", quiet=True)
        if ap.returncode != 0:
            die(f"patch {patch} failed to apply: {ap.stderr.strip()}")
    print(f"{BOLD}VARY{RST} {args.id}  patch={label}  {DIM}(one repo, varying patch){RST}")

    proxy_rc = box_exec(args.id, run, quiet=True).returncode if run else None
    can_rc = run_canonical_new(args.id).returncode
    base_reset(args.id)

    def v(rc):
        return "n/a" if rc is None else ("pass" if rc == 0 else "FAIL")
    proxy_v, can_v = v(proxy_rc), v(can_rc)
    agree = (proxy_rc is not None) and ((proxy_rc == 0) == (can_rc == 0))
    note = ""
    if proxy_rc is not None and not agree:
        note = ("proxy missed (coverage gap)" if can_rc != 0 and proxy_rc == 0
                else "proxy over-specified (unsound)")
    print(f"  proxy={pf(0) if proxy_rc==0 else pf(1) if proxy_rc is not None else DIM+'n/a'+RST}"
          f"   canonical={pf(0) if can_rc==0 else pf(1)}"
          f"   {GRN+'agree'+RST if agree else (YEL+'DISAGREE: '+note+RST if note else '')}")
    append_lesson("vary", args.id, f"patch=`{label}`: proxy={proxy_v} canonical={can_v}"
                  + (f" — **DISAGREE**: {note}" if note else " — agree"))


# ── legal moves postcondition: dsr verdict <id> ───────────────────────────────
VERDICTS = {"RESOLVED", "NOT_RESOLVED", "REJECTED"}
ROUTES = {"design-doc", "implement-spec", "none"}


def cmd_verdict(args):
    f = Path(args.file)
    if not f.exists():
        die(f"no verdict artifact at {f} — pipeline produced no decision (treat as errored, not a verdict)")
    data = json.loads(f.read_text())
    v, route = data.get("verdict", ""), data.get("route", "")
    v_head = v.split()[0].rstrip(":") if v else ""
    ok_v, ok_r = v_head in VERDICTS, route in ROUTES
    print(f"{BOLD}VERDICT{RST} {v!r}  ->  {pf(0) if ok_v else pf(1)}")
    print(f"{BOLD}ROUTE{RST}   {route!r}  ->  {pf(0) if ok_r else pf(1)}")
    if not (ok_v and ok_r):
        die("postcondition FAILED — unrecognized verdict/route enum; route to human bin", 2)


# ── deterministic post-verify gate: dsr gate <id> <manifest> ──────────────────
# The mechanical stop-decision. NOT an LLM attestation — a pure boolean recomputed
# from build-tools' artifacts. Takes the stop decision away from verify-spec's
# prose verdict (poka-yoke). Certifies PROXY-GREEN, never grade-green: the proxy
# gate is spec-derived and may diverge from the hidden grader.
def cmd_gate(args):
    man = json.loads(Path(args.manifest).read_text())
    tid = man.get("task_id", args.id)
    print(f"{BOLD}GATE{RST} {tid}  {DIM}(deterministic; certifies PROXY-GREEN, not grade-green){RST}")

    checks = []  # (label, ok, detail)

    # 1. proxy gate runs green
    pg = man.get("proxy_gate", {})
    run = pg.get("run")
    if not run:
        checks.append(("proxy-gate", False, "manifest has no proxy_gate.run"))
    else:
        r = box_exec(tid, run, quiet=True)
        checks.append(("proxy-gate", r.returncode == 0, tail(r.stdout + r.stderr, 4)))

    # 2. no new regressions vs the captured baseline
    base_cmd = man.get("baseline_cmd")
    baseline_fails = set(man.get("baseline_fails", []))
    if base_cmd:
        r = box_exec(tid, base_cmd, quiet=True)
        # spec-independent existing suite; a clean exit means no regressions.
        # (baseline_fails lets a pre-red suite still pass the gate.)
        ok = r.returncode == 0 or bool(baseline_fails)
        detail = "clean" if r.returncode == 0 else f"suite rc={r.returncode}; baseline had {len(baseline_fails)} known-red"
        checks.append(("regression", ok, detail))

    # 3. verdict file present + enum valid (postcondition)
    vf = man.get("verdict_file") or (args.verdict_file if hasattr(args, "verdict_file") else None)
    if vf and Path(vf).exists():
        data = json.loads(Path(vf).read_text())
        v = (data.get("verdict") or "").split()[0].rstrip(":")
        ok = v in VERDICTS and data.get("route") in ROUTES
        checks.append(("verdict-enum", ok, f"{data.get('verdict')!r} / {data.get('route')!r}"))
    else:
        checks.append(("verdict-enum", False, f"no verdict artifact at {vf}"))

    for label, ok, detail in checks:
        print(f"  {pf(0) if ok else pf(1)}  {label:13} {DIM}{detail.splitlines()[0] if detail else ''}{RST}")
    passed = all(ok for _, ok, _ in checks)
    print(rule())
    if passed:
        print(f"{BOLD}{GRN}PROXY-GREEN{RST} — loop may halt (NOT a certified grade pass)")
        sys.exit(0)
    print(f"{BOLD}{RED}NOT GREEN{RST} — loop continues")
    sys.exit(1)


# ── regression baseline: dsr base <id> ────────────────────────────────────────
def base_reset(task_id: str):
    meta = load_meta(task_dir(task_id))
    b = meta.get("metadata", {}).get("base_commit_hash")
    box_exec(task_id, f"git reset --hard {b} -q && git clean -fdq -e /tmp/proxy", quiet=True)
    return b


def cmd_base(args):
    """Capture the existing suite's pass/fail on the CLEAN base. The set of
    already-failing tests is $BASELINE_FAILS — pre-existing reds that are NOT
    regressions. Mirrors the hidden grader's `test.sh base` mode."""
    base_reset(args.id)
    cmd = args.suite or "python -m pytest -q -m 'not network' --no-header -rf"
    print(f"{BOLD}BASELINE{RST} {args.id}  {DIM}(existing suite on clean base){RST}")
    r = box_exec(args.id, cmd, quiet=True)
    fails = re.findall(r'^FAILED (\S+)', r.stdout, re.M)
    print(tail(r.stdout, 3))
    print(rule())
    if fails:
        print(f"{YEL}$BASELINE_FAILS ({len(fails)} pre-existing — exclude from regressions):{RST}")
        for f in fails:
            print(f"  {f}")
    else:
        print(f"{GRN}$BASELINE_FAILS empty — clean base{RST}")
    out = REPO / "harness" / "feature" / "run" / f"{args.id}.baseline.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"task_id": args.id, "suite": cmd, "baseline_fails": fails}, indent=2))
    print(f"{DIM}written {out.relative_to(REPO)}{RST}")


# ── build-tools isolation mini-test: dsr isolate <id> <manifest> ──────────────
def cmd_isolate(args):
    """Measure build-tools' proxy gate INDEPENDENTLY of implement-spec.
    SOUND  = the gold/reference solution passes the proxy gate (a necessary bar
             must never reject a correct implementation; failure => over-specified).
    LIVE   = on clean base (feature absent) the proxy gate fails (it actually
             tests the feature; passing => dead bar).
    A good build-tools output is SOUND + LIVE. Coverage tightness is separate
    (that's the proxy-vs-grade gap)."""
    man = json.loads(Path(args.manifest).read_text())
    run = man.get("proxy_gate", {}).get("run")
    if not run:
        die("manifest has no proxy_gate.run")
    d = task_dir(args.id)

    print(f"{BOLD}ISOLATE{RST} {args.id}  {DIM}(build-tools proxy gate, no implement-spec){RST}")

    # LIVE: clean base -> proxy gate must FAIL
    base_reset(args.id)
    live = box_exec(args.id, run, quiet=True)
    is_live = live.returncode != 0
    print(f"  {pf(0) if is_live else pf(1)}  LIVE    {DIM}clean base -> proxy {'fails (good)' if is_live else 'PASSES (dead bar)'}{RST}")

    # SOUND: gold applied -> proxy gate must PASS
    name = ensure_box(args.id)
    subprocess.run(["docker", "cp", str(d / "solution" / "solution.patch"), f"{name}:/tmp/gold.patch"], check=True)
    box_exec(args.id, "git apply --whitespace=nowarn /tmp/gold.patch", quiet=True)
    sound = box_exec(args.id, run, quiet=True)
    is_sound = sound.returncode == 0
    print(f"  {pf(0) if is_sound else pf(1)}  SOUND   {DIM}gold applied -> proxy {'passes (good)' if is_sound else 'FAILS (over-specified)'}{RST}")
    if not is_sound:
        print(rule("proxy gate output under gold (these assertions exceed the PRD)"))
        print(tail(sound.stdout + sound.stderr, 14))
    base_reset(args.id)  # leave clean

    print(rule())
    verdict = "SOUND + LIVE" if (is_sound and is_live) else \
              ("UNSOUND" if not is_sound else "DEAD")
    col = GRN if (is_sound and is_live) else RED
    print(f"{BOLD}BUILD-TOOLS: {col}{verdict}{RST}{BOLD}{RST}  "
          f"{DIM}(necessary bar is {'usable' if is_sound and is_live else 'NOT usable as-is'}){RST}")
    append_lesson("isolate", args.id,
                  f"build-tools proxy gate: **{verdict}**  "
                  f"(sound={is_sound} gold-passes-proxy, live={is_live} base-fails-proxy)")
    sys.exit(0 if (is_sound and is_live) else 1)


# ── abduction diff: dsr compare <id> [manifest] ───────────────────────────────
# Bi-abduction over two test suites (june.kim/abduction). before = our spec-only
# proxy gate; after = the canonical hidden tests. XOR -> figure (what differs) vs
# ground (what both cover). Incorrectness polarity: the figure is the signal — the
# missed + over-specified behaviors. The figure feeds the abductive skill patch
# (/retro): infer the best explanation for each miss, encode it back into a skill.
# Reading the canonical tests is legitimate here: it is the RETROSPECTIVE step,
# run only after build-tools has frozen our spec-only artifacts.
# Test-shape buckets — industry-familiar names (unit / integration / e2e) that
# generalize across tasks. Shape, not behavior: a more legible default than
# repo-specific keyword bucketing.
FAMILIES = {
    "e2e": ["streaming", "aiter", "stream_closed", "stream_consumed", "consumes_and_closes",
            "closes_response", "closes_streaming", "chunk_boundaries", "end_to_end", "e2e"],
    "integration": ["repeatable", "in_memory", "inmemory", "integration", "roundtrip", "round_trip"],
}


def _family(name: str) -> str:
    n = name.lower()
    for fam, kws in FAMILIES.items():
        if any(k in n for k in kws):
            return fam
    return "unit"  # default: input-output behavior on plain values


def _tests_from_patch_text(text: str, target: str) -> list[str]:
    inblk, body = False, []
    for l in text.splitlines():
        if l.startswith(f"+++ b/{target}"):
            inblk = True; continue
        if inblk and l.startswith("diff --git"):
            break
        if inblk and l.startswith("+"):
            body.append(l[1:])
    return re.findall(r'^\s*(?:async )?def (test_\w+)', "\n".join(body), re.M)


def cmd_compare(args):
    d = task_dir(args.id)
    # after: canonical tests (retrospective — allowed once our artifacts are frozen)
    tp = (d / "tests" / "test.patch").read_text()
    target = next((m for m in re.findall(r'^\+\+\+ b/(\S+)', tp, re.M) if "test" in m and m.endswith(".py")), None)
    canonical = _tests_from_patch_text(tp, target) if target else []

    # before: our proxy gate tests (from manifest; read the gate file out of the container)
    ours: list[str] = []
    if args.manifest and Path(args.manifest).exists():
        man = json.loads(Path(args.manifest).read_text())
        path = man.get("proxy_gate", {}).get("path")
        if path:
            cat = box_exec(args.id, f"cat {path} 2>/dev/null", quiet=True)
            ours = re.findall(r'^\s*(?:async )?def (test_\w+)', cat.stdout, re.M)
        ours += [f"criterion:{c}" for c in man.get("proxy_gate", {}).get("criteria", []) if not ours]

    print(f"{BOLD}COMPARE{RST} {args.id}  {DIM}(bi-abduction: ours=before vs canonical=after){RST}")
    print(f"{DIM}canonical {len(canonical)} tests · ours {len(ours)} proxy tests{RST}")
    print(rule("figure/ground by behavioral family"))
    fig_missed, fig_cov = {}, {}
    for fam in ["unit", "integration", "e2e"]:
        c = [t for t in canonical if _family(t) == fam]
        o = [t for t in ours if _family(t) == fam]
        if not c and not o:
            continue
        covered = bool(o) and bool(c)
        missed = bool(c) and not o
        mark = f"{GRN}ground{RST}" if covered else (f"{RED}MISSED{RST}" if missed else f"{YEL}over?{RST}")
        print(f"  {mark:18} {fam:18} canonical={len(c):2}  ours={len(o):2}")
        if missed:
            fig_missed[fam] = c
        elif covered:
            fig_cov[fam] = (len(o), len(c))

    print(rule("FIGURE — missed families (abduction targets; incorrectness polarity)"))
    if fig_missed:
        for fam, tests in fig_missed.items():
            print(f"  {RED}{fam}{RST}: {len(tests)} canonical behaviors, 0 proxy — "
                  f"e.g. {', '.join(t[5:] for t in tests[:3])}")
    else:
        print(f"  {GRN}none — every canonical family has a proxy counterpart{RST}")

    out = REPO / "harness" / "feature" / "run" / args.id / "compare.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        "task_id": args.id, "canonical_count": len(canonical), "ours_count": len(ours),
        "figure_missed": {k: v for k, v in fig_missed.items()},
        "ground_covered": fig_cov,
    }, indent=2))
    # inner-loop log for the outer-loop supervisor
    lines = [f"canonical={len(canonical)} ours={len(ours)}"]
    if fig_missed:
        for fam, tests in fig_missed.items():
            lines.append(f"- MISSED **{fam}** ({len(tests)}): {', '.join(t[5:] for t in tests[:5])}")
    else:
        lines.append("- no missed families")
    append_lesson("compare/figure", args.id, "\n".join(lines))
    print(rule())
    print(f"{DIM}figure → {out.relative_to(REPO)} · lesson appended to build-tools-lessons.md → /retro{RST}")


# ── the inner loop: dsr inner <id> <manifest> ─────────────────────────────────
# build-tools (LLM, run before this) -> apply golden patch -> verify (proxy gate)
# -> compare (abduction figure) -> log. The golden patch is a known-correct
# implementer, so the result is PURE build-tools quality — implement-spec is out
# of the loop. The inner loop only executes + abducts; the outer loop (you) reads
# build-tools-lessons.md and patches the skills.
def cmd_inner(args):
    print(f"{BOLD}INNER LOOP{RST} {args.id}  {DIM}build-tools→gold→verify→compare→log{RST}")
    print(rule("verify: gold vs our proxy gate (soundness/liveness)"))
    iso = subprocess.run([sys.executable, __file__, "isolate", args.id, args.manifest])
    print(rule("abduct: our proxy vs canonical (coverage figure)"))
    subprocess.run([sys.executable, __file__, "compare", args.id, args.manifest])
    print(rule())
    print(f"{DIM}inner loop done · read build-tools-lessons.md for the outer-loop patch{RST}")
    sys.exit(iso.returncode)


def main():
    p = argparse.ArgumentParser(prog="dsr", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("task", help="identity precondition: gradeable? defect? PRD")
    sp.add_argument("id"); sp.set_defaults(func=cmd_task)
    sp = sub.add_parser("box", help="live state: run a command in the task container")
    sp.add_argument("id"); sp.add_argument("cmd", nargs=argparse.REMAINDER); sp.set_defaults(func=cmd_box)
    sp = sub.add_parser("grade", help="private oracle: run the hidden grader (proxy-vs-grade gap)")
    sp.add_argument("id"); sp.set_defaults(func=cmd_grade)
    sp = sub.add_parser("verdict", help="legal-moves postcondition: validate $VERDICT_FILE")
    sp.add_argument("file"); sp.add_argument("id", nargs="?"); sp.set_defaults(func=cmd_verdict)
    sp = sub.add_parser("base", help="capture $BASELINE_FAILS: existing suite on clean base")
    sp.add_argument("id"); sp.add_argument("--suite", default=None); sp.set_defaults(func=cmd_base)
    sp = sub.add_parser("gate", help="deterministic post-verify gate: PROXY-GREEN boolean from manifest")
    sp.add_argument("id"); sp.add_argument("manifest"); sp.set_defaults(func=cmd_gate)
    sp = sub.add_parser("isolate", help="build-tools mini-test: SOUND+LIVE proxy gate, no implement-spec")
    sp.add_argument("id"); sp.add_argument("manifest"); sp.set_defaults(func=cmd_isolate)
    sp = sub.add_parser("compare", help="abduction diff: our proxy tests vs canonical tests -> figure")
    sp.add_argument("id"); sp.add_argument("manifest", nargs="?"); sp.set_defaults(func=cmd_compare)
    sp = sub.add_parser("inner", help="inner loop: gold->verify->compare->log (build-tools + verify-spec integrity)")
    sp.add_argument("id"); sp.add_argument("manifest"); sp.set_defaults(func=cmd_inner)
    sp = sub.add_parser("vary", help="one repo, varying patch: proxy vs canonical catch (discriminating power)")
    sp.add_argument("id"); sp.add_argument("manifest")
    sp.add_argument("--patch", default=None); sp.add_argument("--name", default=None)
    sp.set_defaults(func=cmd_vary)
    sp = sub.add_parser("residue-lint", help="enforce RESIDUE.md content rules before Phase 4")
    sp.add_argument("path", help="path to RESIDUE.md (or '-' for stdin)")
    sp.add_argument("--quiet", action="store_true")
    sp.set_defaults(func=cmd_residue_lint)
    args = p.parse_args()
    args.func(args)


def cmd_residue_lint(args):
    """Phase 3.5 -> Phase 4 contamination check (FREEZE-CHECKLIST §VII).
    Delegates to harness/feature/residue_lint.py for the actual deny patterns
    so the same script can be invoked standalone in CI or by other tooling."""
    here = Path(__file__).resolve().parent
    lint_script = here / "residue_lint.py"
    cmd = [sys.executable, str(lint_script), args.path]
    if args.quiet:
        cmd.append("--quiet")
    sys.exit(subprocess.run(cmd).returncode)


if __name__ == "__main__":
    main()
