#!/bin/bash
# Reel bot installer for macOS (Apple Silicon).
# Run it from the unzipped reelbot folder, logged into the account the bot will run as:
#     bash setup.sh
# Safe to run again: it updates what's there and keeps your config.toml and cookies.
set -euo pipefail

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32m✓\033[0m %s\n" "$1"; }
die()  { printf "\n\033[1;31m✗ %s\033[0m\n" "$1"; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS."
[[ "$(uname -m)" == "arm64" ]] || die "This needs an Apple Silicon Mac (M1 or newer)."

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/reelbot"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

say "Copying the bot to $DEST"
mkdir -p "$DEST"
if [[ "$SRC" != "$DEST" ]]; then
  for f in reel_pipeline.py config.example.toml requirements-mac.txt reel_queue_gate.sh README.md; do
    cp "$SRC/$f" "$DEST/"
  done
  rm -rf "$DEST/hermes-skill" && cp -R "$SRC/hermes-skill" "$DEST/"
fi
ok "files in place"

say "Finding uv (the Python installer Hermes uses)"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  # Hermes keeps its own copy of uv here instead of on PATH
  for cand in "$HERMES_HOME"/tools/uv-*/uv; do
    if [[ -x "$cand" ]]; then export PATH="$(dirname "$cand"):$PATH"; break; fi
  done
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "    uv not found, installing it (about 30 seconds)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || die "uv still isn't available. Close Terminal, reopen it, and run setup.sh again."
ok "uv $(uv --version | awk '{print $2}')"

say "Building the bot's private Python environment (first run downloads ~1 GB, a few minutes)"
# --seed puts pip in the environment, so later updates need only ".venv/bin/python -m pip"
uv venv --quiet --allow-existing --seed --python 3.12 "$DEST/.venv"
uv pip install --quiet --upgrade --python "$DEST/.venv/bin/python" -r "$DEST/requirements-mac.txt"
ok "Python packages installed"

if [[ ! -f "$DEST/config.toml" ]]; then
  cp "$DEST/config.example.toml" "$DEST/config.toml"
  ok "created config.toml"
else
  ok "kept your existing config.toml"
fi
mkdir -p "$HOME/ReelLibrary/notes" "$HOME/ReelLibrary/raw"

say "Installing the Hermes skill and scheduled-job script"
mkdir -p "$HERMES_HOME/skills/media/reel-research" "$HERMES_HOME/scripts"
cp "$DEST/hermes-skill/reel-research/SKILL.md" "$HERMES_HOME/skills/media/reel-research/SKILL.md"
cp "$DEST/reel_queue_gate.sh" "$HERMES_HOME/scripts/reel_queue_gate.sh"
chmod +x "$HERMES_HOME/scripts/reel_queue_gate.sh"
ok "skill → $HERMES_HOME/skills/media/reel-research/"
ok "script → $HERMES_HOME/scripts/reel_queue_gate.sh"
# Hermes caches its skill list, so a gateway that's already running needs a restart to see it
if [[ -f "$HOME/Library/LaunchAgents/ai.hermes.gateway.plist" ]] && command -v hermes >/dev/null 2>&1; then
  hermes gateway restart >/dev/null 2>&1 && ok "restarted the Hermes gateway so it picks up the skill"
fi

say "Downloading the speech-to-text model (~1.6 GB, one time)"
"$DEST/.venv/bin/python" - <<'PY'
import os, sys
sys.path.insert(0, os.path.expanduser("~/reelbot"))
import reel_pipeline as rp
rp.ensure_ffmpeg_on_path()                   # links the bundled ffmpeg into the venv as "ffmpeg"
cfg = rp.load_config(None)
if rp.pick_transcriber(cfg) == "mlx":
    import numpy as np, mlx_whisper
    # one second of silence is enough to make it download the model
    mlx_whisper.transcribe(np.zeros(16000, dtype=np.float32), path_or_hf_repo=cfg["whisper_model_mlx"])
    print("    model ready")
else:
    sys.exit("    mlx-whisper didn't load, so there's no speech-to-text. Send this output to Claude.")
PY

say "Checking everything"
if "$DEST/.venv/bin/python" "$DEST/reel_pipeline.py" doctor; then
  ok "all good"
else
  die "Something above says false. Send that output to Claude."
fi

cat <<EOF

$(printf "\033[1;32m")Installed.$(printf "\033[0m") Next steps (README.md has details):
  1. Log into the burner Instagram account in Firefox (in this macOS account), then run:
       ~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py cookies --browser firefox
  2. While on your HOME Wi-Fi, run this to remember your home router:
       ~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py network --save
  3. Test it on a reel:
       ~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py run 'https://www.instagram.com/reel/...'
EOF
