#!/usr/bin/env python3
"""Quantify H8 discipline density in a proxy-gate file.

Metrics:
- test_count: number of test_ methods
- prd_quoted: methods whose docstring contains 'PRD' or a quoted clause (double-quoted span)
- prd_negative_clause: methods whose docstring contains 'PRD-negative' or 'negative' marker
- axis_crossing: methods named or docstringed for cross-axis / combination cases
- discriminating: methods with both positive AND negative assertions (assertIn/assertNotIn,
  assertEqual on issue_ids AND on a different list)
"""
import ast
import re
import sys

KEYWORDS_AXIS = re.compile(r"axis|cross|combine|nested|stack|multi|interaction|compositional|overlap", re.I)

def analyze(path):
    src = open(path).read()
    tree = ast.parse(src)
    tests = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_"):
            doc = ast.get_docstring(node) or ""
            body_src = ast.unparse(node) if hasattr(ast, 'unparse') else ""
            t = {
                "name": node.name,
                "doc": doc,
                "prd_quoted": bool(re.search(r'PRD[:\s]', doc) or re.search(r'"[^"]{15,}"', doc)),
                "prd_negative": "PRD-negative" in doc or "negative:" in doc.lower(),
                "axis_keyword": bool(KEYWORDS_AXIS.search(node.name) or KEYWORDS_AXIS.search(doc)),
                "has_positive_neg_assertions": bool(
                    ("assertIn" in body_src and "assertNotIn" in body_src) or
                    ("assertEqual" in body_src and "assertNotEqual" in body_src)
                ),
                "body": body_src,
            }
            tests.append(t)
    return tests

def report(path):
    tests = analyze(path)
    n = len(tests)
    if n == 0:
        return print(f"{path}: NO TESTS")
    cnt_prd = sum(t["prd_quoted"] for t in tests)
    cnt_neg = sum(t["prd_negative"] for t in tests)
    cnt_axis = sum(t["axis_keyword"] for t in tests)
    cnt_disc = sum(t["has_positive_neg_assertions"] for t in tests)
    print(f"== {path} ==")
    print(f"  tests: {n}")
    print(f"  PRD-quoted docstrings: {cnt_prd}/{n} = {100*cnt_prd/n:.0f}%")
    print(f"  PRD-negative clauses:  {cnt_neg}/{n} = {100*cnt_neg/n:.0f}%")
    print(f"  axis-crossing keyword: {cnt_axis}/{n} = {100*cnt_axis/n:.0f}%")
    print(f"  discriminating inputs: {cnt_disc}/{n} = {100*cnt_disc/n:.0f}%")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p)
