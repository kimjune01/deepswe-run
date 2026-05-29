#!/usr/bin/env python3
"""Score H₉ overlap on Composer↔codex reviews of the Flash-authored proxy gate.

Reads `codex-review.txt` and `composer-review.txt` from the same dir.
For each: parse the numbered findings (F1, F2, ...) under each of the three
sections (Soundness, Discrimination, Missing coverage).

Overlap is computed on the *semantic claim* of each finding, not the F-number.
This pass is manual: the script prints findings side by side and asks the
reviewer (me, the agent) to mark pairs. Outputs `overlap.json` with:
  - a_count, b_count
  - pairs: [(a_id, b_id), ...]
  - overlap = |pairs| / |union|
  - decision: ">70% → H₉ collapses to mostly self-review"

Usage:
  python3 score-overlap.py        # interactive pairing
  python3 score-overlap.py --auto # heuristic pairing on shared keywords
"""

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).parent

def parse_findings(path):
    """Pull lines starting with F<digits> as findings."""
    if not path.exists():
        return []
    out = []
    for line in path.read_text().splitlines():
        m = re.match(r"^\s*(?:[-*]\s*)?\*?\*?F(\d+)\*?\*?[:.\s\-]\s*(.+)$", line)
        if m:
            out.append((int(m.group(1)), m.group(2).strip()))
    return out

def main():
    a = parse_findings(HERE / "codex-review.txt")
    b = parse_findings(HERE / "composer-review.txt")
    print(f"codex findings: {len(a)}")
    print(f"composer findings: {len(b)}")
    if not a or not b:
        print("Missing one or both review files; cannot score.")
        sys.exit(2)
    print("\n=== codex ===")
    for fid, txt in a:
        print(f"  F{fid}: {txt[:140]}")
    print("\n=== composer ===")
    for fid, txt in b:
        print(f"  F{fid}: {txt[:140]}")
    print("\nNow do manual pairing → write overlap.json by hand.")

if __name__ == "__main__":
    main()
