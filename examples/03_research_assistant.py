"""
Example 3: Research assistant for content creation

Use case: You're about to write a blog post / Twitter thread on a topic.
Before writing, pull the latest X discussion + citations to inform your angle.

This is what professional writers do manually for hours.
You do it in 60 seconds.

Usage:
  python 03_research_assistant.py "topic"

Output: Markdown research brief, ready to paste into your editor.
"""
import json
import subprocess
import sys
from datetime import datetime


def research(topic: str) -> dict:
    result = subprocess.run(
        ["xs", "--raw", topic],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def render_brief(topic: str, data: dict) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    answer = data.get("answer", "")
    citations = data.get("citations", [])

    md = f"""# Research Brief: {topic}

> Generated: {now}
> Source: Grok x_search via SuperGrok
> Model: {data.get('model')}

## What's Being Said

{answer}

## Source Tweets ({len(citations)})

"""
    for i, c in enumerate(citations[:15], 1):
        md += f"{i}. {c}\n"

    md += """
---

## Suggested Angles

- Contrarian: what assumption in the discussion is wrong?
- Synthesis: which 2-3 sources together reveal a non-obvious pattern?
- Personal: where do you (the writer) have first-hand experience to add?
"""
    return md


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python 03_research_assistant.py 'topic'", file=sys.stderr)
        sys.exit(1)

    topic = " ".join(sys.argv[1:])
    print("[research] querying...", file=sys.stderr)
    data = research(topic)
    print(render_brief(topic, data))


if __name__ == "__main__":
    main()
