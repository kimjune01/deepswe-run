#!/usr/bin/env python3
"""residue-lint — enforce RESIDUE.md content rules (FREEZE-CHECKLIST §VII).

Phase 3.5's `RESIDUE.md` carries SPECULATION-typed findings forward to Phase 4.
That carry-forward is a contamination channel: speculative critique can in
principle leak gold-shape hints to the impl-time adversary review. Per the
prereg amendment 2026-05-29 (codex critical review), RESIDUE.md content is
bounded by deny patterns; this script enforces them before Phase 4 starts.

Allowed: type-classification reasoning, verbatim PRD-ambiguity quotes,
discriminating-input shapes (PRD-shaped inputs that would convert SPECULATION
to ENTAILMENT), and adversary identity.

Forbidden:
- Patch sketches (model-shaped output describing what code to write)
- File-level implementation plans
- References to hidden test names or test files
- References to or inferences from the gold patch
- Hidden-grader internal references

Exit 0 iff residue is clean. Exit 2 with a list of violations otherwise.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Deny patterns. Each tuple: (category, regex, why).
# Patterns are intentionally conservative — false positives are surfaced as
# warnings the operator must explicitly clear, not silent acceptance.
DENY = [
    ("patch_sketch",
     re.compile(r"\b(should add|add a |add the |implement|create a|create the)\b.*\b(function|method|class|file|module|hook)\b", re.I),
     "patch sketch — describes impl shape, not PRD ambiguity"),

    ("patch_sketch_diff",
     re.compile(r"```(?:diff|patch)\b", re.I),
     "patch sketch — fenced diff/patch block"),

    ("file_plan",
     re.compile(r"\b(modify|edit|change|update)\s+[`'\"]?[\w./-]+\.(py|ts|js|go|rs|java|c|cpp|h)[`'\"]?", re.I),
     "file-level impl plan — names a file to modify"),

    ("hidden_test_name",
     re.compile(r"\btest_[a-z][a-z0-9_]{4,}\b"),
     "looks like a hidden-test name; spec should be PRD-shaped, not test-shaped"),

    ("hidden_test_file",
     re.compile(r"\btest\.(patch|sh)\b|/tests/test\.|test\.patch", re.I),
     "reference to the hidden grader's files"),

    ("gold_reference",
     re.compile(r"\b(gold|reference)\s+(patch|solution|impl|implementation)\b", re.I),
     "reference to gold/reference patch the agent should never have seen"),

    ("grader_internals",
     re.compile(r"\bn_passed\b|\breward\.txt\b|\bproxy[-_]?vs[-_]?grade\b", re.I),
     "hidden-grader internal reference"),
]

# Phrases the operator can use as in-line waivers when a false positive needs
# to pass (e.g. PRD itself quotes one of these words). Format:
#   <!-- residue-lint allow: <category> --> text-of-quoted-PRD-clause
WAIVER_RE = re.compile(r"<!--\s*residue-lint\s+allow:\s*([\w_-]+)\s*-->")


def lint(text: str) -> list[tuple[str, int, str, str]]:
    """Return (category, line_number, line_text, why) for each violation."""
    violations: list[tuple[str, int, str, str]] = []
    lines = text.splitlines()
    waived_categories: set[str] = set()
    for idx, line in enumerate(lines, start=1):
        m = WAIVER_RE.search(line)
        if m:
            waived_categories.add(m.group(1))
            continue
        for category, pattern, why in DENY:
            if category in waived_categories:
                continue
            if pattern.search(line):
                violations.append((category, idx, line.strip(), why))
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("residue", help="path to RESIDUE.md (or '-' for stdin)")
    parser.add_argument("--quiet", action="store_true",
                        help="emit no output on success")
    args = parser.parse_args()

    if args.residue == "-":
        text = sys.stdin.read()
    else:
        path = Path(args.residue)
        if not path.exists():
            # An absent RESIDUE.md is *fine* — it just means Phase 3.5
            # produced no SPECULATION-typed findings. Empty residue is clean.
            if not args.quiet:
                print(f"residue-lint: {path} absent — treating as empty (clean)")
            return 0
        text = path.read_text()

    violations = lint(text)
    if not violations:
        if not args.quiet:
            print(f"residue-lint: {args.residue} clean ({len(text)} bytes)")
        return 0

    print(f"residue-lint: {args.residue} has {len(violations)} violation(s):", file=sys.stderr)
    for category, lineno, line, why in violations:
        print(f"  L{lineno} [{category}] {why}", file=sys.stderr)
        print(f"    > {line[:120]}", file=sys.stderr)
    print(f"\nTo waive a false positive, add this comment ABOVE the offending line:", file=sys.stderr)
    print(f"  <!-- residue-lint allow: <category> -->", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
