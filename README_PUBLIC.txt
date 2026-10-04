ZEN MASTER USAGE WARDEN - PUBLIC EDITION
Windows / Codex usage desktop widget

WHAT IT DOES
Zen Master displays the Codex weekly usage allowance and reset countdown in a small desktop widget.
It attempts to refresh automatically from the user's own local Codex installation every five minutes.

PRIVACY
This package does NOT contain the creator's ChatGPT/Codex account information.
It does not ship with an email address, password, API key, browser cookie, OAuth token, or account ID.
It asks the user's locally installed Codex app-server for rate-limit information. Codex handles its own authentication.

INSTALL / START
1. Extract the entire ZIP to a normal folder. Do not run it from inside the ZIP.
2. Double-click "Start Zen Master.vbs".
3. If automatic sync works, the status will show "Auto: Codex synced".
4. "Refresh now" asks Codex for an immediate update.
5. Right-click the Auto status or Refresh button for:
   - Manual Update Usage
   - Show Auto Diagnostics

IF AUTO SYNC DOES NOT WORK
Run "Diagnose Codex Auto Sync.bat".
The widget searches:
- codex/codex.exe on Windows PATH
- CODEX_CLI_PATH if configured
- the local Codex Desktop executable cache under %LOCALAPPDATA%\OpenAI\Codex\bin

FEATURES
- Automatic weekly Codex usage percentage
- Automatic reset countdown
- Five-minute automatic refresh
- Normal and compact widget sizes
- Optional Always on Top
- Hide/minimize
- Manual usage fallback
- Zen Master pose/messages change with remaining usage

IMPORTANT
The automatic reader relies on Codex's local app-server interface. That interface may change in a future Codex release, which could temporarily break automatic sync.

SHARING
Please share this clean ZIP rather than re-zipping your already-used app folder, because a running copy can create a local settings.json containing usage/reset/preferences.

Zen Master Usage Warden is an unofficial community utility and is not an OpenAI product.
