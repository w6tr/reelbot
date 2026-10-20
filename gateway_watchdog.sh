#!/bin/bash
# Every 5 minutes (via launchd): if the Hermes gateway isn't running, start it. Hermes's own
# service can silently stop on some macOS versions; this gets it back without you noticing.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
LOG="$HOME/reelbot/logs/watchdog.log"
mkdir -p "$(dirname "$LOG")"
if hermes gateway status 2>/dev/null | grep -q "Gateway is supervised by launchd\|running"; then
  exit 0
fi
echo "$(date '+%F %T') gateway not running, starting" >> "$LOG"
hermes gateway start >> "$LOG" 2>&1 || echo "$(date '+%F %T') start failed" >> "$LOG"
