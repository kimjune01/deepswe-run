"""Dev probe: resolve a selector expression to (suppressed_id_set, is_blanket).

Reference oracle for the operator grammar. Not exhaustive — implementer should match
or exceed this behavior. Implements: empty/all → blanket; none → no-op; tokens
unioned on whitespace/comma; |,&,-,! operators with parentheses; glob B* prefix.

Usage:
  python3 probe_resolve_selector.py '(B6*) & (B602|B607)' B101 B602 B607 B404
  -> blanket=False ids={'B602', 'B607'}
"""
import re
import sys


def _tokens(text):
    return [t for t in re.split(r"[\s,]+", text) if t]


def _expand_glob(tok, enabled):
    if "*" in tok:
        pat = re.compile("^" + re.escape(tok).replace(r"\*", ".*") + "$", re.IGNORECASE)
        return {e for e in enabled if pat.match(e)}
    return {tok} if tok in enabled else set()


def _resolve_atom(tok, enabled):
    if tok.lower() == "all":
        return set(enabled), True
    if tok.lower() == "none":
        return set(), False
    return _expand_glob(tok, enabled), False


_TOKEN_RE = re.compile(r"\s*([()|&!\-]|[A-Za-z0-9_*]+)")


def _tokenize_expr(text):
    pos = 0
    out = []
    while pos < len(text):
        m = _TOKEN_RE.match(text, pos)
        if not m:
            return None
        out.append(m.group(1))
        pos = m.end()
    return out


def _parse(tokens, enabled):
    # Pratt-like recursive parser: | (lowest), -, &, ! (unary), atoms/parens.
    pos = [0]

    def peek():
        return tokens[pos[0]] if pos[0] < len(tokens) else None

    def eat():
        t = tokens[pos[0]]
        pos[0] += 1
        return t

    def parse_or():
        s, blank = parse_diff()
        while peek() == "|":
            eat()
            s2, b2 = parse_diff()
            s |= s2
            blank = blank or b2
        return s, blank

    def parse_diff():
        s, blank = parse_and()
        while peek() == "-":
            eat()
            s2, _ = parse_and()
            s -= s2
        return s, blank

    def parse_and():
        s, blank = parse_unary()
        while peek() == "&":
            eat()
            s2, b2 = parse_unary()
            s &= s2
            blank = blank and b2
        return s, blank

    def parse_unary():
        if peek() == "!":
            eat()
            s, _ = parse_unary()
            return set(enabled) - s, False
        return parse_atom()

    def parse_atom():
        t = peek()
        if t == "(":
            eat()
            s, blank = parse_or()
            if peek() == ")":
                eat()
            return s, blank
        if t is None or t in ("|", "&", "-", "!", ")"):
            return set(), False
        eat()
        return _resolve_atom(t, enabled)

    return parse_or()


def resolve(expr, enabled):
    enabled = set(enabled)
    text = expr.strip()
    if not text:
        return set(enabled), True  # empty -> blanket
    # Try operator-grammar parse first
    toks = _tokenize_expr(text)
    if toks is not None and any(t in ("(", ")", "|", "&", "-", "!") for t in toks):
        try:
            s, _ = _parse(toks, enabled)
            return s, (s == enabled)
        except Exception:
            pass
    # Plain whitespace/comma fallback
    parts = _tokens(text)
    if [p.lower() for p in parts] == ["all"]:
        return set(enabled), True
    if [p.lower() for p in parts] == ["none"]:
        return set(), False
    out = set()
    for p in parts:
        if p.lower() == "all":
            return set(enabled), True
        if p.lower() == "none":
            continue
        out |= _expand_glob(p, enabled)
    return out, False


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit("usage: probe_resolve_selector.py <expr> <enabled-id>...")
    expr = sys.argv[1]
    enabled = sys.argv[2:]
    ids, blanket = resolve(expr, enabled)
    print(f"blanket={blanket} ids={sorted(ids)}")
