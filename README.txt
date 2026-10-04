ZEN MASTER USAGE WARDEN v5

1. Extract the whole folder.
2. Double-click "Start Zen Master.vbs".
3. Only the Zen Master widget should appear; PowerShell should NOT appear on the taskbar.
4. Click the small circle near the X to toggle Always on Top.
5. Hide minimizes the widget so other windows/movies can cover it.
6. Update usage lets you enter the current percentage and weekly reset time.

This version rebuilds the visual layout around the concept image: transparent Zen Master art overlapping a compact Codex Fuel meter.


VERSION 6
- White high-contrast meter text.
- Zen Master moved up so he no longer covers the title.
- Window can be resized smaller/larger by dragging a corner.
- Minimum and maximum sizes prevent accidental unusable scaling.


VERSION 7
- Removed the white Windows title bar completely.
- Added custom borderless corner/edge resizing.
- Replaced the scaling bug with responsive layout, so controls stay visible when resized.
- Zen Master and the meter resize together without overlapping the title.


VERSION 8
- Removed the custom compiled resize code that prevented v7 from opening on some Windows systems.
- Restored stable borderless startup.
- Added a minus/square button to switch between Normal and Compact sizes safely.
- Added Start Zen Master DEBUG.bat for visible troubleshooting if normal startup ever fails.


VERSION 9 - AUTOMATIC CODEX USAGE
- Zen Master now attempts to read Codex usage automatically from the local Codex app-server.
- It uses the read-only account/rateLimits/read JSON-RPC method.
- It prefers the weekly 10,080-minute window and converts usedPercent into percent remaining.
- It updates the weekly reset time automatically.
- Default refresh interval: 5 minutes.
- No ChatGPT password, browser cookie, or OAuth token is read by this widget; Codex app-server handles its own authentication.
- If Codex CLI/app-server is unavailable or not on PATH, the widget keeps the last known value and the manual Update Usage button remains available.
- The status text shows Auto: Codex synced or Auto: unavailable.


VERSION 10 - WINDOWS CODEX DISCOVERY
- Searches normal PATH first.
- Honors CODEX_CLI_PATH if set.
- Searches the Codex Desktop local executable cache under:
  %LOCALAPPDATA%\OpenAI\Codex\bin\...\codex.exe
- Prefers a complete cache directory containing Codex companion executables.
- Uses app-server --listen stdio:// and account/rateLimits/read.
- Refresh now attempts an immediate automatic sync.
- Right-click the status text or Refresh now for Manual Update Usage or Show Auto Diagnostics.
- Diagnose Codex Auto Sync.bat reports which Codex executable Windows can actually find.
