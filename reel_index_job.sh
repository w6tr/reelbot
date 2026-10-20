#!/bin/bash
# Nightly, model-free: rebuild ~/ReelLibrary/notes/INDEX.md and list duplicate sources.
# Lives in ~/.hermes/scripts/ and runs as a Hermes "--no-agent" job (so it costs nothing).
# If ~/ReelLibrary is a git checkout (the private reel-library repo), the notes are also
# committed and pushed so the other machine can pull them. A failed push never fails the index.
"$HOME/reelbot/.venv/bin/python" "$HOME/reelbot/reel_pipeline.py" index
rc=$?
LIB="$HOME/ReelLibrary"
LOG="$HOME/reelbot/logs/library-push.log"
if [ -d "$LIB/.git" ]; then
  mkdir -p "$(dirname "$LOG")"
  {
    echo "== $(date '+%F %T')"
    git -C "$LIB" add -A notes archive 2>/dev/null || git -C "$LIB" add -A notes
    # INDEX.md changes on every rebuild (timestamp line); only push when a note changed
    if git -C "$LIB" diff --cached --quiet -- . ':(exclude)notes/INDEX.md'; then
      git -C "$LIB" reset -q
      echo "nothing new to push"
    else
      git -C "$LIB" commit -q -m "notes: nightly index $(date +%F)" && git -C "$LIB" push -q origin HEAD
    fi
  } >>"$LOG" 2>&1
fi
exit $rc
