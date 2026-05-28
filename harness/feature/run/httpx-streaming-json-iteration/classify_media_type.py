#!/usr/bin/env python3
"""classify_media_type — ground-truth oracle for Content-Type → JSON stream mode.

PRD-derived classifier. Returns one of:
  document  application/json or application/*+json
  ndjson    application/ndjson or application/x-ndjson
  json_seq  application/json-seq
  REJECT    anything else (including +json outside application/ tree, missing header)

Case-insensitive on type and subtree. Parameters allowed and ignored.

Usage:
  python3 classify_media_type.py 'application/json; charset=utf-8'
  python3 classify_media_type.py 'image/svg+json'   # → REJECT

NOT the feature implementation — this isolates the one deterministic distinction
the implementer would otherwise re-derive at each call site.
"""
from __future__ import annotations

import email.message
import sys


def classify(content_type: str | None) -> str:
    if content_type is None:
        return "REJECT"
    msg = email.message.Message()
    msg["content-type"] = content_type
    typ = msg.get_content_type()
    if not typ or "/" not in typ:
        return "REJECT"
    maintype, _, subtype = typ.partition("/")
    maintype = maintype.lower()
    subtype = subtype.lower()
    if maintype != "application":
        return "REJECT"
    if subtype == "json":
        return "document"
    if subtype.endswith("+json"):
        return "document"
    if subtype in ("ndjson", "x-ndjson"):
        return "ndjson"
    if subtype == "json-seq":
        return "json_seq"
    return "REJECT"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: classify_media_type.py '<Content-Type value>'", file=sys.stderr)
        return 2
    print(classify(sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
