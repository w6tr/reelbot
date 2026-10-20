#!/bin/bash
# One-step install for the bot's macOS account: Hermes Agent, then the reel pipeline.
#   bash ~/Public/reelbot/install_all.sh
# Everything it prints is also saved in ~/Public/reelbot/logs/ so Claude can read it.
# Safe to run again if something fails partway.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/logs"
LOG="$HERE/logs/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee "$LOG") 2>&1

step() { printf "\n\033[1;35m### %s\033[0m\n" "$1"; }
die()  { printf "\n\033[1;31m✗ %s\033[0m\n" "$1"; echo "(log: $LOG)"; exit 1; }

echo "Started $(date) as $(whoami) on macOS $(sw_vers -productVersion) ($(uname -m))"

step "1/3 Checking Apple's developer tools (they provide git)"
xcode-select -p >/dev/null 2>&1 || die "Apple's Command Line Tools aren't installed yet. Let that install finish, then run this again."
git --version || die "git doesn't work yet."

step "2/3 Installing Hermes Agent (a few minutes)"
export PATH="$HOME/.local/bin:$PATH"
if command -v hermes >/dev/null 2>&1; then
  echo "Hermes is already installed, skipping."
else
  # --skip-setup: we pick the AI model later (Part C) instead of mid-install
  # --skip-browser / --skip-computer-use: the bot reads web pages with its built-in web tools and
  #   never needs to drive a browser or the screen, so those big optional add-ons stay off.
  #   (Add later with: hermes pm install agent-browser)
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
    | bash -s -- --skip-setup --skip-browser --skip-computer-use \
    || die "The Hermes installer failed (see above)."
fi
hermes --version || die "The hermes command isn't working."

step "3/3 Installing the reel pipeline"
bash "$HERE/setup.sh" || die "setup.sh failed (see above)."

printf "\n\033[1;32mAll done.\033[0m Tell Claude it finished.\n"
