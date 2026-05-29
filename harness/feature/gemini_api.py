#!/usr/bin/env python3
"""gemini_api.py — direct Gemini API shim for headless prompt -> response.

Replaces gemini-cli in contexts where workspace-exploration is unwanted (e.g.
baseline-flash arm of run_arm.sh, where the kysely workspace at 800 MB causes
gemini-cli's `-p --approval-mode plan` to exceed 17 min while it reads files
through tool calls).

This shim:
- Reads prompt from stdin (or --prompt arg)
- Sends to gemini-3.5-flash via google.generativeai
- Prints response to stdout
- Exits 0 on success, 1 on auth/quota errors, 2 on other failures

Reproducibility note: requires GEMINI_API_KEY in env. No tool calls; the model
sees the prompt and returns text only. Equivalent in spirit to a single Gemini
API request — not a multi-turn agent.

Usage:
  echo "Implement X" | python3 gemini_api.py            # stdin
  python3 gemini_api.py --prompt "Implement X"          # arg
  python3 gemini_api.py -m gemini-3.5-flash --prompt "…"
"""

from __future__ import annotations

import argparse
import os
import sys


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("-m", "--model", default="gemini-3.5-flash",
                   help="model ID (default: gemini-3.5-flash)")
    p.add_argument("--prompt", default=None,
                   help="prompt string (otherwise read from stdin)")
    p.add_argument("--temperature", type=float, default=None,
                   help="optional temperature override")
    p.add_argument("--max-output-tokens", type=int, default=None,
                   help="optional output cap")
    args = p.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("FATAL: GEMINI_API_KEY not in env", file=sys.stderr)
        return 1

    if args.prompt is None:
        prompt = sys.stdin.read()
    else:
        prompt = args.prompt

    if not prompt.strip():
        print("FATAL: empty prompt", file=sys.stderr)
        return 2

    try:
        import google.generativeai as genai
    except ImportError:
        print("FATAL: google.generativeai not installed (pip install google-generativeai)",
              file=sys.stderr)
        return 2

    genai.configure(api_key=api_key)

    gen_kwargs: dict = {}
    if args.temperature is not None:
        gen_kwargs["temperature"] = args.temperature
    if args.max_output_tokens is not None:
        gen_kwargs["max_output_tokens"] = args.max_output_tokens

    try:
        model = genai.GenerativeModel(args.model)
        resp = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(**gen_kwargs) if gen_kwargs else None,
        )
    except Exception as e:
        cls = type(e).__name__
        print(f"FATAL: {cls}: {e}", file=sys.stderr)
        return 1 if "Auth" in cls or "Quota" in cls else 2

    text = resp.text or ""
    sys.stdout.write(text)
    if not text.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
