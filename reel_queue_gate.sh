#!/bin/bash
# Scheduled-job gate for Hermes. Lives in ~/.hermes/scripts/.
# Processes links that were queued while away from home. If nothing was processed it prints
# {"wakeAgent": false} so Hermes skips the AI step and costs nothing.
exec "$HOME/reelbot/.venv/bin/python" "$HOME/reelbot/reel_pipeline.py" drain
