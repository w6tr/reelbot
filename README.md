# Reel Bot: install guide

Share a reel from Instagram to your Telegram bot. The MacBook downloads it, transcribes it,
reads the on-screen text, researches the claims, saves a note to `~/ReelLibrary/notes/`, and
replies with a short summary.

```
Phone (Instagram → Share → Telegram bot)
   │
   ▼
MacBook, "reelbot" macOS account
   Hermes Agent ── Telegram gateway, memory, scheduled jobs
     └─ reel-research skill
          ├─ reel_pipeline.py: yt-dlp → Whisper → frames → Apple Vision OCR → reel.md
          ├─ web research (claims, sources, verdicts)
          └─ note → ~/ReelLibrary/notes/  +  short reply in Telegram
```

**Total time:** about 45 minutes, mostly waiting on downloads.
**You'll need:** the MacBook on power, your phone with Telegram, a burner Instagram account,
and a way to pay for the AI model (see Part C).

---

## Part A: on your normal Mac account (10 min)

1. **Create the bot's account.** System Settings → Users & Groups → Add User.
   Type **Standard** (not Administrator). Name it `reelbot` and give it its own password.
2. **Turn on the fast user-switching menu.** System Settings → Control Center →
   Fast User Switching → Show in Menu Bar. This lets you flip between accounts without
   logging out.
3. **Keep it awake on power.** System Settings → Battery → Options → turn on
   *Prevent automatic sleeping on power adapter when the display is off*.
   If you want it to keep working with the lid **closed**, install **Amphetamine** (free, Mac
   App Store) and set it to keep the Mac awake only while it's on power.
4. **Protect the battery (optional).** Install **AlDente** to cap charging at 80%. Switch to
   100% the night before a long day away from a charger.

> **One correction to what I told you earlier.** On macOS, Hermes runs its background service
> *inside a logged-in account*. It can't start from a cold boot with nobody logged in. So the
> `reelbot` account has to stay logged in in the background. After a restart, log into
> `reelbot` once, then use the menu-bar switcher to go back to your own account. It keeps
> running while you use yours. Restarts are rare, so this mostly matters after macOS updates.

---

## Part B: in the bot's account, install (20 min)

Log into the bot's Standard account (on this Mac it's called **Agent**). Do everything below
there. Apple's **Command Line Tools** must be installed first (they provide `git`); if
`xcode-select -p` prints an error, run `xcode-select --install` and enter an admin password.

### 1–2. Install Hermes and the reel bot (one command)
Put this `reelbot` folder in the bot account's **Public** folder (`~/Public/reelbot`), open
**Terminal** (Spotlight → "Terminal") and paste:
```bash
bash ~/Public/reelbot/install_all.sh
```
It installs Hermes (without its optional browser and screen-control add-ons), builds a private
Python environment, downloads the speech model (~1.6 GB), installs the Hermes skill, and ends
with a self-check that should say `"ok": true`. Everything it prints is also saved in
`~/Public/reelbot/logs/`. When it's done, **close Terminal and open it again** so the `hermes`
command is found.

### 3. Give it the burner Instagram login
1. Install **Firefox** in this account (from firefox.com: open the download, drag Firefox to
   Applications; a Standard account asks for an admin name and password once). Log into the
   **burner** Instagram account at instagram.com. Never use your main account.
2. Save the login and test a reel in one go (copy a reel link from your phone first):
   ```bash
   bash ~/Public/reelbot/test_reel.sh 'https://www.instagram.com/reel/XXXXXXXX/'
   ```
   Only Instagram's cookies are copied, and the file is readable only by this account. It should
   end with `"status": "ok"`. Open the report it names (`open ~/ReelLibrary/raw`) and check the
   transcript and on-screen text look right.

### 4. Tell it what "home" is (so it only downloads on your Wi-Fi)
While connected to your **home** Wi-Fi, run:
```bash
~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py network --save
```
It writes your router's ID into `~/reelbot/config.toml`. Run it again on another network you
trust to add that one too.

### 5. Test the pipeline on its own (any time)
```bash
~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py run 'https://www.instagram.com/reel/XXXXXXXX/'
```

---

## Part C: connect Hermes to a model and to Telegram (10 min)

### 6. Pick the AI model
```bash
hermes setup
```
Choose one of these:

| Option | Good for | Notes |
|---|---|---|
| **Anthropic API key** (Claude Sonnet) | Best research write-ups | Pay per use. A Claude **Pro** subscription can't be used here; the Hermes docs say it needs an API key instead. Get one at console.anthropic.com. |
| **Nous Portal** subscription | One login for many models plus built-in web tools | `hermes setup --portal` |
| **Your gaming PC's local model** | Free to run | The PC has to be on, and you'd need to make its model server reachable on your home network. Weaker at research. Better as a cheap helper model than the main one. |

Web search works with no extra setup: Hermes rotates through free search providers.

### 7. Create the Telegram bot
```bash
hermes dashboard
```
In the page that opens, go to **Messaging → Telegram → Create with QR**, scan it with your
phone's Telegram, and Hermes creates the bot. It also locks the bot to **your** Telegram
account only.
(Manual alternative: make a bot with @BotFather, then run `hermes gateway setup`.)

Then, in Telegram, open the chat with your new bot and send **`/sethome`**. That makes this chat
the place scheduled jobs (step 9) send their results; the QR setup doesn't set it for you.

### 8. Run it in the background
```bash
hermes gateway install
hermes gateway start
hermes gateway status
```

### 9. Schedule the "process what I shared while away" job
```bash
hermes cron create "every 30m" \
  "The pre-run script just processed reels that were queued while I was away (its output is above). For each item under processed, follow the reel-research skill from step 3: read the report, extract the claims as stated, save the note, rebuild the index with reel_pipeline.py index, and send me the short summary. No fact-checking. For anything under gave_up, tell me it failed and why." \
  --skill reel-research --script reel_queue_gate.sh --deliver telegram --name reel-queue
```
When nothing is queued, the script tells Hermes to skip the AI step, so idle runs cost nothing.

### 10. Lock it down
These are Hermes's defaults, so normally there's nothing to change. Check with
`grep -A3 '^approvals' ~/.hermes/config.yaml`, and if they're missing or different, set:
```yaml
approvals:
  mode: smart          # a helper model judges risky commands; unclear ones need your OK in Telegram
  cron_mode: deny      # scheduled runs can never run risky commands
```
Hermes already refuses messages from anyone except your Telegram account.

---

## Part D: your phone (2 min)

1. In Telegram, open the new bot and send `hi` to check it answers.
2. In Instagram, open any reel → tap the **share** (paper plane) icon → in the row of apps at
   the bottom, find **Telegram** (it may be under **More** / **Share to…**). Pick your bot.
   Telegram remembers recent chats, so after the first time it's two taps.
3. Share a reel. You should get a summary back in about a minute. Then try a follow-up:
   *"dig deeper on the second claim"* or *"what reels have I saved about creatine?"*

Notes live in `~/ReelLibrary/notes/` with an `INDEX.md`. You can point Obsidian at
`~/ReelLibrary` if you want a nicer view.

---

## Upkeep

| When | Do this (in the `reelbot` account) |
|---|---|
| Downloads start failing with "login" errors | Log into the burner account in Firefox again, then rerun the `cookies` command (step 3). |
| Instagram changes something and downloads break | `~/reelbot/.venv/bin/python -m pip install -U yt-dlp` |
| Monthly | `bash ~/reelbot/backup_hermes.sh && hermes update`, then check the bot still answers. If it says "credit balance too low" again, re-apply the API-key patch below and run `hermes auth reset anthropic`. |
| API-key patch (Hermes bug: keys starting `sk-ant-u` are mistaken for subscription logins) | `sed -i '' 's/key.startswith("sk-ant-api")/key.startswith(("sk-ant-api", "sk-ant-u"))/' ~/.hermes/hermes-agent/agent/anthropic_credentials.py` |
| Nightly 3 am | `reel-index` job rebuilds `notes/INDEX.md` and lists duplicates (no AI, free). Run by hand: `~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py index` |
| Every 5 min | A watchdog (`~/Library/LaunchAgents/ai.reelbot.watchdog.plist`) restarts the gateway if it died. Log: `~/reelbot/logs/watchdog.log` |
| You edited the skill file | `hermes gateway restart` (or send `/reload-skills` to the bot). A Telegram chat that already loaded the skill keeps the old text in its context: send `/new` to the bot to start a fresh session. |
| After a Mac restart | Log into the bot's account, then switch back to yours. |
| Check health | `~/reelbot/.venv/bin/python ~/reelbot/reel_pipeline.py doctor` |

## Files

| File | What it is |
|---|---|
| `reel_pipeline.py` | The pipeline: download, transcribe, frames, OCR, report, queue |
| `config.example.toml` | Settings template (setup copies it to `config.toml`) |
| `hermes-skill/reel-research/SKILL.md` | Tells Hermes how to capture a reel, file the note and rebuild `INDEX.md` |
| `reel_queue_gate.sh` | The scheduled job's script: drains the away-from-home queue |
| `setup.sh` | Installs the pipeline and the skill (Hermes must already be installed) |
| `install_all.sh` | Installs Hermes, then runs `setup.sh`; logs to `logs/` |
| `test_reel.sh` | Saves the burner login, runs the self-check and a test reel; logs to `logs/` |
