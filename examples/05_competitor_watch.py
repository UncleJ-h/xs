"""
Example 5: Competitor watch — monitor your competitors' X activity

Use case: PM / founder / marketer who needs to track 5-10 competitors
without manually checking each profile.

Setup: cron daily at 8 AM
  0 8 * * * python /path/to/05_competitor_watch.py > ~/competitor-$(date +%F).md
"""
import json
import subprocess
from datetime import datetime, timedelta

COMPETITORS = [
    # Add your competitors' X handles here (without @)
    "openai",
    "anthropicai",
    "googledeepmind",
    "xai",
    "perplexity_ai",
]

YESTERDAY = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
TODAY = datetime.now().strftime("%Y-%m-%d")


def check_competitor(handle: str) -> dict:
    try:
        result = subprocess.run(
            [
                "xs", "--raw",
                f"What did @{handle} post or announce in the last 24 hours? "
                f"Include product launches, partnerships, or significant statements.",
                "--handle", handle,
                "--from", YESTERDAY,
                "--to", TODAY,
            ],
            capture_output=True,
            text=True,
            timeout=200,
        )
        if result.returncode != 0:
            return {"handle": handle, "error": result.stderr.strip()}
        return {"handle": handle, "data": json.loads(result.stdout)}
    except subprocess.TimeoutExpired:
        return {"handle": handle, "error": "timeout"}


def main() -> None:
    print(f"# Competitor Watch — {TODAY}\n")
    print(f"> Tracking {len(COMPETITORS)} accounts since {YESTERDAY}\n")

    for handle in COMPETITORS:
        result = check_competitor(handle)
        print(f"## @{handle}\n")
        if "error" in result:
            print(f"_[ERROR: {result['error']}]_\n")
            continue
        data = result["data"]
        print(data.get("answer", "_[no notable activity]_"))
        citations = data.get("citations", [])
        if citations:
            print(f"\n**Sources ({len(citations)}):**")
            for c in citations[:5]:
                print(f"- {c}")
        print()
        print("---\n")


if __name__ == "__main__":
    main()
