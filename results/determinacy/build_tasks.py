#!/usr/bin/env python3
"""Adapter: datacurve-ai/deep-swe task dirs -> determinacy tasks.jsonl.

Emits one row per task with the fields the determinacy tool's field-map expects:
instance_id, problem_statement, gold_patch, test_patch, fail_to_pass, repo, base_commit.
"""
import json, re, sys, tomllib
from pathlib import Path

TASKS_DIR = Path("/tmp/deep-swe/tasks")
OUT = Path("/tmp/deepswe-determinacy/tasks.jsonl")

def repo_slug(url: str) -> str:
    m = re.search(r"github\.com[/:]([^/]+/[^/]+?)(?:\.git)?/?$", url.strip())
    return m.group(1) if m else url

rows, skipped = [], []
for d in sorted(TASKS_DIR.iterdir()):
    if not d.is_dir():
        continue
    tt, cfg = d / "task.toml", d / "tests" / "config.json"
    instr = d / "instruction.md"
    gold = d / "solution" / "solution.patch"
    testp = d / "tests" / "test.patch"
    missing = [p.name for p in (tt, cfg, instr, gold, testp) if not p.exists()]
    if missing:
        skipped.append((d.name, "missing:" + ",".join(missing)))
        continue
    meta = tomllib.loads(tt.read_text())
    conf = json.loads(cfg.read_text())
    repo_url = meta.get("metadata", {}).get("repository_url", "")
    base = conf.get("base_commit") or meta.get("metadata", {}).get("base_commit_hash", "")
    f2p = conf.get("f2p_node_ids", [])
    row = {
        "instance_id": d.name,
        "problem_statement": instr.read_text(),
        "gold_patch": gold.read_text(),
        "test_patch": testp.read_text(),
        "fail_to_pass": f2p,
        "repo": repo_slug(repo_url),
        "base_commit": base,
    }
    if not (row["problem_statement"].strip() and row["gold_patch"].strip()
            and row["repo"] and row["base_commit"] and row["fail_to_pass"]):
        skipped.append((d.name, "empty-required-field"))
        continue
    rows.append(row)

OUT.parent.mkdir(parents=True, exist_ok=True)
with OUT.open("w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")

print(f"emitted {len(rows)} tasks -> {OUT}")
if skipped:
    print(f"skipped {len(skipped)}:")
    for name, why in skipped:
        print(f"  {name}: {why}")
