#!/usr/bin/env bash
# Example 2: Find high-engagement, low-reply tweets in your niche
#
# Use case: You want to grow on X via thoughtful replies.
# Best targets = posts with high impressions but few replies = your reply
# has highest visibility-per-effort ratio.

NICHE="AI agent open source"

xs "Find tweets about '$NICHE' posted today with high impressions but fewer than 50 replies. Give me the top 5 with direct links." \
    --from "$(date -u +%Y-%m-%d)"
