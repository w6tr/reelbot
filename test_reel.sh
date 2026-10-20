#!/bin/bash
# Run after logging into the BURNER Instagram account in Firefox (in this macOS account):
#   bash ~/Public/reelbot/test_reel.sh 'https://www.instagram.com/reel/XXXXXXXX/'
# Saves the burner login for the bot, runs the self-check, then processes the reel.
# Output is also saved in ~/Public/reelbot/logs/ so Claude can read it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/logs"
LOG="$HERE/logs/test-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee "$LOG") 2>&1

step() { printf "\n\033[1;35m### %s\033[0m\n" "$1"; }
PY="$HOME/reelbot/.venv/bin/python"
RP="$HOME/reelbot/reel_pipeline.py"
[[ -x "$PY" ]] || { echo "The pipeline isn't installed yet. Run install_all.sh first."; exit 1; }

step "1/3 Saving the burner account's Instagram login from Firefox"
"$PY" "$RP" cookies --browser firefox

step "2/3 Self-check"
"$PY" "$RP" doctor

step "3/3 Processing the test reel (first run can take a minute)"
if [[ $# -ge 1 ]]; then
  "$PY" "$RP" run "$1"
else
  echo "No link given, so no test reel. Put the link in single quotes after the command."
fi

printf "\n\033[1;32mFinished.\033[0m Tell Claude.\n"
