#!/usr/bin/env bash
# Example 1: Monitor a KOL hourly
#
# Use case: You follow Elon Musk but don't want to refresh X every 10 minutes.
# This cron job runs hourly, fetches what he's said in the last hour,
# and pipes to your notification tool of choice (here: macOS osascript).
#
# Setup:
#   crontab -e
#   0 * * * * /path/to/this/script.sh
#
# Customize: change @handle, time window, or notification method.

HANDLE="elonmusk"
SINCE=$(date -u -v-1H +%Y-%m-%d 2>/dev/null || date -u -d "1 hour ago" +%Y-%m-%d)

RESULT=$(xs --answer-only "What did @$HANDLE post in the last hour?" \
    --handle "$HANDLE" \
    --from "$SINCE")

if [ -n "$RESULT" ] && [ "$RESULT" != "[no answer]" ]; then
    osascript -e "display notification \"$RESULT\" with title \"@$HANDLE update\""
    echo "[$(date)] @$HANDLE: $RESULT" >> ~/kol-monitor.log
fi
