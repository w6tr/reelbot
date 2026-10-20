#!/bin/bash
# Back up the Hermes settings that would hurt to lose (a Hermes update once wiped ~/.hermes for
# some users). Run before "hermes update", or any time:   bash ~/reelbot/backup_hermes.sh
# Keeps the last 10 backups in ~/reelbot/backups/. Also backs up the reel bot's config and cookies.
set -euo pipefail
H="${HERMES_HOME:-$HOME/.hermes}"
OUT="$HOME/reelbot/backups"
mkdir -p "$OUT"
STAMP="$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"
mkdir -p "$TMP/hermes" "$TMP/reelbot"
for f in .env config.yaml auth.json; do [[ -f "$H/$f" ]] && cp "$H/$f" "$TMP/hermes/"; done
for d in skills scripts cron memories; do [[ -d "$H/$d" ]] && cp -R "$H/$d" "$TMP/hermes/"; done
[[ -f "$H/MEMORY.md" ]] && cp "$H/MEMORY.md" "$TMP/hermes/"
for f in config.toml cookies.txt; do [[ -f "$HOME/reelbot/$f" ]] && cp "$HOME/reelbot/$f" "$TMP/reelbot/"; done
# the one-line patch that makes Hermes accept sk-ant-u… API keys (see README "Upkeep")
grep -q 'sk-ant-u' "$H/hermes-agent/agent/anthropic_credentials.py" 2>/dev/null \
  && echo "patched" > "$TMP/hermes/api-key-patch.txt" || echo "NOT patched" > "$TMP/hermes/api-key-patch.txt"
tar -czf "$OUT/hermes-backup-$STAMP.tgz" -C "$TMP" . && rm -rf "$TMP"
chmod 600 "$OUT/hermes-backup-$STAMP.tgz"
ls -t "$OUT"/hermes-backup-*.tgz | tail -n +11 | xargs -I{} rm -f {}
echo "backed up to $OUT/hermes-backup-$STAMP.tgz"
