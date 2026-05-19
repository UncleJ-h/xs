# xs — Grok's X Search as a CLI

> **You paid for X Premium+. You're using 5% of it.**
> Here's a 50-line CLI that turns your SuperGrok quota into a programmable X intelligence system.

```bash
xs "What's the AI agent community saying about Hermes today?"
```

That's it. One command, gets Grok's synthesized answer + tweet citations, **uses zero X API budget**.

---

## What this is

`xs` is a thin wrapper around [Hermes Agent](https://github.com/NousResearch/hermes-agent)'s internal `x_search_tool`, which calls Grok's built-in X (Twitter) search.

**It uses your existing SuperGrok subscription** (included in X Premium+). No X Developer API key. No extra subscription. No $200/month X API tier.

You already pay $40/month for Premium+. This makes that subscription actually useful.

## What it is NOT

- ❌ Not a free X API. You don't get raw tweet JSON.
- ❌ Not a scraper. It uses official xAI infrastructure.
- ❌ Not magic. Each call takes 30-180 seconds (Grok thinks, then searches, then synthesizes).

You get **Grok's synthesized answer + tweet links (citations)**. That's the trade.

## Why this exists

I subscribed to X Premium+ a year ago. I used it for:
- Ad-free feed ✓
- Longer posts ✓
- Blue check ✓
- SuperGrok quota? Sometimes chat, that's it.
- `x_search`? Never heard of it until last week.

Then I found out Grok has an internal `x_search` tool that:
1. Runs against your SuperGrok quota (you've already paid)
2. Returns structured Markdown with tweet citations
3. Can be scripted

The official path is to run the full Hermes Agent (~1GB install, TUI, learning loop, etc.) and ask it to "use x_search to...". That works but adds two layers of LLM interpretation — Grok answers, Hermes re-explains, you get the third draft.

`xs` skips the middleman. **Direct Python call to `x_search_tool`. ~50 lines of code. Same auth, same data, no middleman.**

---

## Install

### Prerequisites

1. **SuperGrok subscription** (X Premium+ includes it)
2. **Hermes Agent**:
   ```bash
   brew install hermes-agent
   # or: pip install hermes-agent
   ```
3. **xAI OAuth**:
   ```bash
   hermes auth add xai-oauth
   ```
   Browser opens → log in with X → done. (Token auto-refreshes.)

### Install xs

```bash
git clone https://github.com/UncleJ-h/xs.git
cd xs
bash install.sh
```

The installer:
- Verifies Hermes + OAuth
- Copies `xs` to `~/.local/bin/`
- Runs a smoke test
- Tells you if your PATH needs updating

Done. Type `xs "hello"` to test.

---

## Usage

### Basic

```bash
xs "What are people saying about Claude Opus 4 on X today?"
```

Output: Grok's answer (Markdown) + citation links.

### Filter by account

```bash
xs "latest takes" --handle elonmusk --handle paulg
xs "AI hype" --exclude marketingbot1 --exclude spamacct
```

### Filter by date

```bash
xs "Y Combinator W26 batch" --from 2026-05-01 --to 2026-05-19
```

### For scripts

```bash
# Just the answer (pipeable)
xs --answer-only "topic" | tee research.md

# Full JSON (parse with jq or Python)
xs --raw "topic" | jq '.citations'
```

### All options

```bash
xs --help
```

---

## 5 Real Use Cases

Each one is a script in [`examples/`](examples/). Copy, customize, deploy.

### 1. Monitor a KOL hourly → [`examples/01_monitor_kol.sh`](examples/01_monitor_kol.sh)

You follow Elon but don't want to refresh X every 10 minutes. Cron job fetches what he said in the last hour, pings you via macOS notification (or Telegram/Feishu/Slack).

### 2. Find engagement gold → [`examples/02_engagement_hunter.sh`](examples/02_engagement_hunter.sh)

High-impressions + low-replies tweets in your niche = highest visibility-per-reply ratio. Hunt them.

### 3. Auto-research before writing → [`examples/03_research_assistant.py`](examples/03_research_assistant.py)

Writing a blog post or thread? Run this first. Get a structured Markdown brief — "what's being said + 15 citations + suggested angles" — in 60 seconds.

### 4. Daily briefing on N topics → [`examples/04_daily_briefing.py`](examples/04_daily_briefing.py)

10 topics, one Markdown report, every morning at 9 AM. Investor / analyst / curious person's daily snapshot.

### 5. Competitor watch → [`examples/05_competitor_watch.py`](examples/05_competitor_watch.py)

Monitor 5-10 competitor handles. Daily auto-report. Pipe to Notion / Slack / email.

---

## How it works (technical)

```
┌──────────────────┐
│  xs "your query" │
└────────┬─────────┘
         ↓
┌─────────────────────────────────┐
│  ~/.local/bin/xs (bash)         │
│  → finds Hermes venv Python     │
│  → exec's xs_cli.py             │
└────────┬────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  xs_cli.py                           │
│  → imports tools.x_search_tool       │
│  → check_x_search_requirements()     │
│  → x_search_tool(query=...)          │
└────────┬─────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  Hermes x_search_tool                │
│  → reads OAuth token from auth.json  │
│  → POSTs to api.x.ai/v1/responses    │
│  → returns JSON                      │
└────────┬─────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  Grok (server side)                  │
│  → searches X                        │
│  → synthesizes answer                │
│  → returns answer + citations        │
└──────────────────────────────────────┘
```

That's it. No magic. The whole "trick" is that Hermes exposes `x_search_tool` as an importable function, and the OAuth token auto-refreshes in the background.

---

## FAQ

**Q: Will this get my X account banned?**
A: No. It uses official xAI OAuth and official xAI Responses API. Same channel as Grok.com.

**Q: Does this cost money?**
A: Only your existing SuperGrok subscription ($40/month via X Premium+, or $30/month for standalone SuperGrok). Heavy use can hit rate limits but you don't get billed extra.

**Q: Can I run this on a VPS?**
A: Yes. OAuth on your laptop first, then copy `~/.hermes/auth.json` to the VPS. Token works across machines.

**Q: Why is it slow?**
A: Grok thinks before searching, searches X, then synthesizes. 30-180s per call. Use `--from`/`--to` to narrow the search window.

**Q: Can I use this with Claude / GPT / local models?**
A: Yes — that's the whole point. Pipe `xs --answer-only` or `xs --raw` into any LLM workflow.

**Q: What if Hermes updates and breaks the import?**
A: `xs_cli.py` imports `tools.x_search_tool` by name. As long as Hermes keeps that module path stable (it has, for v0.14.x), `xs` works. If it changes, PR welcome.

---

## License

MIT — see [LICENSE](LICENSE)

## Author

**J叔 (@UncleJAI)** — AI builder, X Premium+ user trying to actually use what I paid for.

If this helped you wake up your SuperGrok quota, follow on X for more: [@UncleJAI](https://x.com/UncleJAI).

---

## Related

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) — the underlying agent framework
- [xAI Grok OAuth docs](https://hermes-agent.nousresearch.com/docs/guides/xai-grok-oauth) — official auth flow
- [x_search official docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/x-search) — parameter reference
