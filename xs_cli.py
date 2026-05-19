"""
xs - Minimal CLI for Grok's X (Twitter) Search via SuperGrok subscription

What this does:
  Calls Hermes Agent's internal x_search_tool function directly,
  bypassing the full Hermes runtime. Uses your existing SuperGrok
  (or X Premium+ with SuperGrok) OAuth credential — no extra cost.

What this does NOT do:
  - Does NOT use X Developer API (which costs $200+/month)
  - Does NOT scrape X website
  - Returns Grok's synthesized answer + citations, NOT raw tweets

Prerequisites:
  1. Active SuperGrok subscription (X Premium+ includes this)
  2. Hermes Agent installed: brew install hermes-agent
  3. OAuth complete: hermes auth add xai-oauth

Usage:
  xs "your query"
  xs "AI agent" --from 2026-05-01 --to 2026-05-19
  xs "Elon's latest" --handle elonmusk
  xs --raw "give me the JSON"
  xs --answer-only "just the answer"

Repo: https://github.com/UncleJ-h/xs
Author: @UncleJAI
License: MIT
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def _find_hermes_dir() -> Path:
    """Locate Hermes Agent installation directory.

    Search order:
      1. $HERMES_DIR env var
      2. ~/.hermes/hermes-agent (default brew/pip install)
      3. ~/Library/Application Support/hermes/hermes-agent (macOS app)
    """
    candidates = []
    if env_dir := os.environ.get("HERMES_DIR"):
        candidates.append(Path(env_dir))
    candidates.extend([
        Path.home() / ".hermes" / "hermes-agent",
        Path.home() / "Library" / "Application Support" / "hermes" / "hermes-agent",
    ])
    for c in candidates:
        if (c / "tools" / "x_search_tool.py").exists():
            return c
    sys.stderr.write(
        "[xs] ERROR: Hermes Agent not found.\n"
        "  Install: brew install hermes-agent\n"
        "  Or set HERMES_DIR env var to your install path.\n"
    )
    sys.exit(1)


def main() -> None:
    hermes_dir = _find_hermes_dir()
    sys.path.insert(0, str(hermes_dir))
    hermes_home = hermes_dir.parent
    os.chdir(hermes_home)

    from tools.x_search_tool import x_search_tool, check_x_search_requirements  # noqa: E402

    parser = argparse.ArgumentParser(
        prog="xs",
        description="X Search via SuperGrok subscription (no X API cost)",
    )
    parser.add_argument("query", nargs="+", help="search query")
    parser.add_argument("--handle", "-H", action="append",
                        help="limit to @handle (repeatable, max 10)")
    parser.add_argument("--exclude", "-X", action="append",
                        help="exclude @handle (repeatable, max 10)")
    parser.add_argument("--from", dest="from_date", default="",
                        help="start date YYYY-MM-DD")
    parser.add_argument("--to", dest="to_date", default="",
                        help="end date YYYY-MM-DD")
    parser.add_argument("--raw", action="store_true",
                        help="output raw JSON")
    parser.add_argument("--no-citations", action="store_true",
                        help="suppress citations block")
    parser.add_argument("--answer-only", action="store_true",
                        help="output answer text only (pipeable)")
    args = parser.parse_args()

    if not check_x_search_requirements():
        sys.stderr.write(
            "[xs] ERROR: xAI credentials missing.\n"
            "  Run: hermes auth add xai-oauth\n"
        )
        sys.exit(1)

    query = " ".join(args.query)

    if not args.raw:
        sys.stderr.write(f"[xs] querying: {query!r}\n")
        if args.handle:
            sys.stderr.write(f"[xs] handles: {args.handle}\n")
        sys.stderr.write("[xs] calling Grok x_search (30-180s)...\n\n")

    result_json = x_search_tool(
        query=query,
        allowed_x_handles=args.handle,
        excluded_x_handles=args.exclude,
        from_date=args.from_date,
        to_date=args.to_date,
    )
    result = json.loads(result_json)

    if not result.get("success"):
        sys.stderr.write(f"[xs] FAIL: {result.get('error', result)}\n")
        sys.exit(2)

    if args.raw:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    if args.answer_only:
        print(result.get("answer", ""))
        return

    print(result.get("answer", "[no answer]"))

    citations = result.get("citations", [])
    if citations and not args.no_citations:
        print()
        print("─" * 60)
        print(f"🔗 {len(citations)} sources:")
        for i, c in enumerate(citations[:15], 1):
            print(f"  [{i}] {c}")

    sys.stderr.write(
        f"\n[xs] model={result.get('model')} | "
        f"credential={result.get('credential_source')}\n"
    )


if __name__ == "__main__":
    main()
