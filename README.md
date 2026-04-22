# DingTimer

```text
██████╗ ██╗███╗   ██╗ ██████╗ ████████╗██╗███╗   ███╗███████╗██████╗
██╔══██╗██║████╗  ██║██╔════╝    ██║   ██║████╗ ████║██╔════╝██╔══██╗
██║  ██║██║██╔██╗ ██║██║  ███╗   ██║   ██║██╔████╔██║█████╗  ██████╔╝
██║  ██║██║██║╚██╗██║██║   ██║   ██║   ██║██║╚██╔╝██║██╔══╝  ██╔══██╗
██████╔╝██║██║ ╚████║╚██████╔╝   ██║   ██║██║ ╚═╝ ██║███████╗██║  ██║
╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝
```

HUD-first XP tracking and time-to-level for World of Warcraft.

## Project Docs

- [ROADMAP](./ROADMAP.md)
- [AGENTS](./AGENTS.md)
- [CLAUDE](./CLAUDE.md)
- [CONTRIBUTING](./CONTRIBUTING.md)
- [SECURITY](./SECURITY.md)
- [CHANGELOG](./CHANGELOG.md)

## What DingTimer Is Now

DingTimer is now a compact leveling HUD addon.

The addon centers on one floating HUD and one tiny settings popup. The old tabbed dashboard, minimap launcher, graph view, history view, PvP mode, and coach-heavy surfaces are not part of the active build anymore.

## Features

- Floating HUD with live `TTL`, rolling `XP/hr`, an animated current-level XP bar, last gain, and XP needed to level
- Tiny popup for HUD visibility, lock state, combat visibility, chat mode, window presets, and reset
- Rolling-window XP tracking instead of stale long-session pace
- Optional chat output in `full` or `ttl` mode
- Level-up announcement with time spent in level and net money
- Persistent HUD position and core settings in `DingTimerDB`

## Installation

1. Download the latest release.
2. Extract the `DingTimer` folder into:

```text
<WoW client>\Interface\AddOns\DingTimer\
```

3. Enable **DingTimer** on the character select AddOns screen.
4. Log in.

The bundled PowerShell installer still supports both Retail and MoP Classic style client roots. You can pass either the client root or the direct `Interface\AddOns` path.

Examples:

```powershell
.\install_ding-timer.ps1
.\install_ding-timer.ps1 -Flavor retail
.\install_ding-timer.ps1 -WowPath "C:\Program Files (x86)\World of Warcraft\_classic_"
```

## Quick Start

- HUD is on by default for new installs.
- Right-click the HUD to open the popup.
- Left-drag moves the HUD when unlocked.
- Left-click toggles the popup when the HUD is locked.
- `/ding settings` opens the popup even if the HUD is hidden.

## Slash Commands

All commands work with either `/ding` or `/dt`.

| Command | What it does |
| --- | --- |
| `/ding` | Show help |
| `/ding help` | Show help |
| `/ding settings` | Open the HUD popup |
| `/ding on` | Enable chat output |
| `/ding off` | Disable chat output |
| `/ding mode full` | Print gain, `XP/hr`, and `TTL` to chat |
| `/ding mode ttl` | Print only `TTL` to chat |
| `/ding window <seconds>` | Set the rolling window, from `30` to `86400` seconds |
| `/ding float on` | Show the HUD |
| `/ding float off` | Hide the HUD |
| `/ding float lock` | Lock the HUD in place |
| `/ding float unlock` | Allow the HUD to be dragged |
| `/ding float reset` | Re-center and show the HUD |
| `/ding reset` | Reset the current session |

### Compatibility Note

Older dashboard commands such as `live`, `graph`, `history`, `insights`, `goal`, `split`, `recap`, and `pvp` are now compatibility shims. They print:

```text
Removed in HUD-first build; use /ding settings
```

## HUD Behavior

The floating HUD has two text lines plus an XP bar strip:

```text
9m 0s to level
6,000 XP/hr  |  Last +10  |  Need 100
```

- Top line: current `TTL`
- Bottom line: rolling `XP/hr`, idle age when the rate is from older retained XP, the most recent XP gain with an estimated number of same-size gains left in parentheses, and XP still needed
- XP bar: current level progress, with a short glow pulse when XP is gained
- When the rolling window is empty, the HUD shows `No XP in <window>`

The HUD hides automatically in combat unless `Show in combat` is enabled in the popup.

## Popup Controls

The popup contains only these controls:

- `HUD on/off`
- `Lock`
- `Show in combat`
- `Chat on/off`
- `Chat mode` with `Full` and `TTL`
- `Window` presets: `1m`, `5m`, `10m`, `15m`
- `Reset session`

There is no separate popup position. It anchors to the HUD while the HUD is visible, and it centers on `UIParent` when opened without the HUD.

## How XP/hr Is Calculated

DingTimer uses a rolling window instead of a long session average:

```text
1. Collect XP gains inside the current window
2. Sum the XP in that window
3. Use min(session elapsed, window size) as the elapsed time
4. XP/hr = (sum / elapsed) * 3600
```

Default window: `10 minutes`

When retained XP is still inside the rolling window but no fresh XP has arrived for 30+ seconds, the HUD adds an `idle <time>` label so the fixed-window average is not mistaken for a currently active pace.

This keeps the HUD responsive to what you are doing now instead of what you were doing half an hour ago.

## Saved Variables

`DingTimerDB` stores:

- HUD visibility, lock state, combat visibility, and position
- Rolling window setting
- Chat output enablement and mode
- Release metadata

Legacy history, PvP, and coach data are preserved in `DingTimerDB` for rollback safety if they already exist, but the HUD-first build does not update those records anymore.

## Running Tests

Windows:

```powershell
.\coverage.ps1
```

Or run a single Lua test:

```powershell
python .\run_tests.py tests\test_hud_popup.lua
```

## Releasing

Tag a commit with a leading `v` to publish a GitHub Release:

```bash
git tag v1.1.2
git push origin v1.1.2
```
