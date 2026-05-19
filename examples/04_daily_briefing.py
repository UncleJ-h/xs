"""
Example 4: Auto daily briefing — 10 queries, one report, sent to your inbox

Use case: Investor / analyst / curious person who wants a daily snapshot
of multiple topics without manually searching.

Setup: cron at 9 AM daily
  0 9 * * * python /path/to/04_daily_briefing.py | tee ~/daily-brief-$(date +%F).md
"""
import subprocess
from datetime import datetime

TOPICS = [
    "Bitcoin price discussion today",
    "OpenAI announcements last 24 hours",
    "AI agent open source releases this week",
    "@elonmusk recent posts",
    "Anthropic Claude updates",
    "Apple WWDC rumors",
    "Tesla earnings discussion",
    "China AI policy news",
    "Y Combinator latest batch",
    "Vibe coding tools mentions",
]


def query(topic: str) -> str:
    try:
        result = subprocess.run(
            ["xs", "--answer-only", topic],
            capture_output=True,
            text=True,
            timeout=200,
        )
        if result.returncode != 0:
            return f"[FAIL] {result.stderr.strip()}"
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "[TIMEOUT after 200s]"


def main() -> None:
    today = datetime.now().strftime("%Y-%m-%d")
    print(f"# Daily Briefing — {today}\n")
    print("> Auto-generated via xs CLI (Grok x_search)\n")

    for i, topic in enumerate(TOPICS, 1):
        print(f"## {i}. {topic}\n")
        answer = query(topic)
        print(f"{answer}\n")
        print("---\n")

    print(f"\n_End of briefing. {len(TOPICS)} topics queried._")


if __name__ == "__main__":
    main()
