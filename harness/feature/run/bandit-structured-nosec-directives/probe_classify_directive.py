"""Dev probe: classify a comment string as one of the new directive kinds (or 'plain'/'none').

Implementation reference oracle the implementer can sanity-check against. Not the
implementation — just answers "what kind of directive does this comment line denote?"
case-insensitively, and what the SELECTOR text is (post-keyword).

Usage:
  python3 probe_classify_directive.py '# Nosec-Begin B602, B607'
  -> kind=nosec-begin selector='B602, B607'
"""
import re
import sys

_DIR_RE = re.compile(
    r"^\s*#\s*(?P<kind>nosec-begin|nosec-end|nosec-next-line)\b\s*(?P<sel>.*)$",
    re.IGNORECASE,
)
_PLAIN_NOSEC = re.compile(r"^\s*#\s*nosec\b", re.IGNORECASE)


def classify(comment_line: str):
    m = _DIR_RE.match(comment_line)
    if m:
        return m.group("kind").lower(), m.group("sel").strip()
    if _PLAIN_NOSEC.match(comment_line):
        return "nosec-inline", ""
    return "none", ""


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: probe_classify_directive.py <comment-line>")
    kind, sel = classify(sys.argv[1])
    print(f"kind={kind} selector={sel!r}")
