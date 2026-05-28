#!/usr/bin/env python3
"""detect_json_encoding — ground-truth oracle for JSON encoding detection.

Implements the RFC 8259 § 8.1 / RFC 4627 algorithm for sniffing JSON encoding
from the first 4 bytes, plus the UTF-8 BOM. Returns one of:
  utf-8 / utf-8-sig / utf-16-le / utf-16-be / utf-32-le / utf-32-be

Usage:
  python3 detect_json_encoding.py <hex>
  e.g.  python3 detect_json_encoding.py efbbbf7b227d  (UTF-8 BOM + {})

NOT the feature implementation — this isolates one distinction the implementer
would otherwise re-derive each time charset is absent.
"""
from __future__ import annotations

import sys


def detect(prefix: bytes) -> str:
    # UTF-8 BOM
    if prefix.startswith(b"\xef\xbb\xbf"):
        return "utf-8-sig"
    # UTF-32 BOMs
    if prefix.startswith(b"\xff\xfe\x00\x00"):
        return "utf-32-le"
    if prefix.startswith(b"\x00\x00\xfe\xff"):
        return "utf-32-be"
    # UTF-16 BOMs (check after UTF-32, since they share the first 2 bytes)
    if prefix.startswith(b"\xff\xfe"):
        return "utf-16-le"
    if prefix.startswith(b"\xfe\xff"):
        return "utf-16-be"
    # zero-pattern sniff over first 4 bytes (RFC 4627 §3): JSON text starts with
    # an ASCII char, so the encoding shows up as the zero-byte positions.
    if len(prefix) >= 4:
        b0, b1, b2, b3 = prefix[0], prefix[1], prefix[2], prefix[3]
        if b0 == 0 and b1 == 0 and b2 == 0 and b3 != 0:
            return "utf-32-be"
        if b0 != 0 and b1 == 0 and b2 == 0 and b3 == 0:
            return "utf-32-le"
        if b0 == 0 and b1 != 0:
            return "utf-16-be"
        if b0 != 0 and b1 == 0:
            return "utf-16-le"
    elif len(prefix) >= 2:
        if prefix[0] == 0 and prefix[1] != 0:
            return "utf-16-be"
        if prefix[0] != 0 and prefix[1] == 0:
            return "utf-16-le"
    return "utf-8"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: detect_json_encoding.py <hex-bytes>", file=sys.stderr)
        return 2
    try:
        data = bytes.fromhex(sys.argv[1])
    except ValueError:
        print("invalid hex", file=sys.stderr)
        return 2
    print(detect(data[:4] if len(data) >= 4 else data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
