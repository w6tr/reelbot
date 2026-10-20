#!/bin/bash
# Applies the Oct 19 upgrade to an installed reel bot:
#   bash ~/Public/reelbot/upgrade.sh
# - new pipeline (reads text from every frame, uses TikTok/YouTube captions, anonymous-first downloads, index command)
# - new skill (neutral extraction note with typed front matter)
# - nightly index job, 5-minute gateway watchdog, backups, tighter file permissions
# Safe to run again.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
H="${HERMES_HOME:-$HOME/.hermes}"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HERE/logs"; LOG="$HERE/logs/upgrade-$(date +%Y%m%d-%H%M%S).log"; exec > >(tee "$LOG") 2>&1
step() { printf "\n\033[1;35m### %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32m✓\033[0m %s\n" "$1"; }

step "1/6 Backing up Hermes settings first"
cp "$HERE/backup_hermes.sh" "$HOME/reelbot/backup_hermes.sh" && bash "$HOME/reelbot/backup_hermes.sh"

step "2/6 Updating the pipeline and its packages (adds curl-cffi for anonymous Instagram downloads)"
for f in reel_pipeline.py config.example.toml requirements-mac.txt reel_queue_gate.sh reel_index_job.sh gateway_watchdog.sh README.md; do
  cp "$HERE/$f" "$HOME/reelbot/$f"
done
chmod +x "$HOME/reelbot"/*.sh "$HOME/reelbot/reel_pipeline.py"
"$HOME/reelbot/.venv/bin/python" -m pip install -q --upgrade -r "$HOME/reelbot/requirements-mac.txt" && ok "packages up to date"
grep -q '^ocr_every_frame' "$HOME/reelbot/config.toml" || cat >> "$HOME/reelbot/config.toml" <<'EOF'

# Added by the Oct 19 upgrade: read text from every frame and merge by text (captions change words
# without the picture changing); use the platform's own captions when it has them.
ocr_every_frame = true
prefer_platform_subtitles = true
watermark_min_share = 0.6
EOF
"$HOME/reelbot/.venv/bin/python" "$HOME/reelbot/reel_pipeline.py" doctor >/dev/null && ok "pipeline self-check passed"

step "3/6 Installing the new skill and scripts into Hermes"
mkdir -p "$H/skills/media/reel-research" "$H/scripts"
cp "$HERE/hermes-skill/reel-research/SKILL.md" "$H/skills/media/reel-research/SKILL.md"
cp "$HOME/reelbot/reel_queue_gate.sh" "$HOME/reelbot/reel_index_job.sh" "$H/scripts/"
chmod +x "$H/scripts/"*.sh && ok "skill + scripts installed"

step "4/6 Tightening permissions on secrets"
[[ -f "$H/.env" ]] && chmod 600 "$H/.env" && ok "~/.hermes/.env is private"
[[ -f "$H/auth.json" ]] && chmod 600 "$H/auth.json"
[[ -f "$HOME/reelbot/cookies.txt" ]] && chmod 600 "$HOME/reelbot/cookies.txt"

step "5/6 Nightly index job (no AI, free) and the 5-minute gateway watchdog"
if hermes cron list 2>/dev/null | grep -q "reel-index"; then
  ok "nightly index job already exists"
else
  hermes cron create "0 3 * * *" --no-agent --script reel_index_job.sh --name reel-index --deliver local >/dev/null \
    && ok "nightly index job created (3:00 am)"
fi
PL="$HOME/Library/LaunchAgents/ai.reelbot.watchdog.plist"
sed "s#__HOME__#$HOME#g" "$HERE/ai.reelbot.watchdog.plist" > "$PL"
launchctl bootout "gui/$(id -u)/ai.reelbot.watchdog" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$PL" && ok "watchdog installed (checks every 5 min)"

step "6/6 Restarting the Hermes gateway so it picks up the new skill"
hermes gateway restart >/dev/null 2>&1; sleep 4
hermes gateway status | tail -2
"$HOME/reelbot/.venv/bin/python" "$HOME/reelbot/reel_pipeline.py" index >/dev/null && ok "INDEX.md rebuilt"
printf "\n\033[1;32mUpgrade done.\033[0m Log: %s\n" "$LOG"
