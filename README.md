# DingTimer

```text
██████╗ ██╗███╗   ██╗ ██████╗ ████████╗██╗███╗   ███╗███████╗██████╗
██╔══██╗██║████╗  ██║██╔════╝    ██║   ██║████╗ ████║██╔════╝██╔══██╗
██║  ██║██║██╔██╗ ██║██║  ███╗   ██║   ██║██╔████╔██║█████╗  ██████╔╝
██║  ██║██║██║╚██╗██║██║   ██║   ██║   ██║██║╚██╔╝██║██╔══╝  ██╔══██╗
██████╔╝██║██║ ╚████║╚██████╔╝   ██║   ██║██║ ╚═╝ ██║███████╗██║  ██║
╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝
```

Real-time XP tracking, leveling analytics, and time-to-ding for World of Warcraft

![Version](https://img.shields.io/badge/version-0.6.0-blue?style=flat-square)
![WoW](https://img.shields.io/badge/WoW-WotLK%20Classic%2030300-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Lua](https://img.shields.io/badge/Lua-5.1-purple?style=flat-square)

---

## What is DingTimer?

DingTimer is a **leveling efficiency addon** that answers the eternal question every grinder has asked: *"How long until I ding?"*

No more alt-tabbing to calculators. No more rough guesses. DingTimer tracks your XP gains in real time, calculates your XP/hr using a rolling time window, and tells you exactly how long that last level is going to take — all from inside the game.

**It also tracks your gold.** Because gold per hour is just as important as XP per hour.

---

## Features

- **XP Per Hour** — Rolling-window calculation that adapts to your current pace, not your average from an hour ago
- **Time To Level (TTL)** — Live countdown to your next ding, updated every second
- **Money Per Hour** — Track your gold income alongside your XP gains
- **Session Coach** — Goal presets, pace-drop alerts, idle nudges, best-segment callouts, and end-of-run recap
- **Analysis Graph** — Dedicated graph view with visible/session/fixed scale modes, summary cards, goal comparisons, and recent segment rows
- **History View** — Per-character history with best/median rates, trend tracking, zone leaders, recap storage, and recent-session breakdowns
- **Floating HUD** — A cleaner two-line HUD showing TTL, current pace, session pace, and timed-goal pace when relevant
- **Live Panel** — A refreshed home view for progress, coach status, recent alerts, and quick actions
- **Settings Hub** — Grouped controls for output, HUD, coach, graph, and data maintenance
- **Minimap Button** — Left-click for Live, middle-click for Analysis, right-click for Settings, drag to reposition
- **Level-Up Announcements** — Celebrates every ding with your time in level and gold earned
- **Persistent Sessions** — Settings, main window/HUD placement, and per-character session history saved between sessions

---

## Installation

1. Download the latest release
2. Extract the `DingTimer` folder into your addons directory:

   ```text
   World of Warcraft\_classic_\Interface\AddOns\DingTimer\
   ```

3. Launch WoW and enable **DingTimer** in the AddOns menu on the character select screen
4. Log in — DingTimer activates automatically

> The minimap button will appear on login. Left-click it to toggle the Dashboard tab.

---

## Quick Start

| You want to...        | Do this                                            |
| --------------------- | -------------------------------------------------- |
| Open Live             | Left-click the minimap button or `/ding live`      |
| Change settings       | Right-click the minimap button or `/ding settings` |
| Open Analysis         | Middle-click the minimap button or `/ding graph`   |
| Open History          | `/ding history` or `/ding insights`                |
| Set a coach goal      | `/ding goal ding` or `/ding goal 30m`              |
| Record a checkpoint   | `/ding split`                                      |
| Show the latest recap | `/ding recap`                                      |

---

## Slash Commands

All commands work with either `/ding` or `/dt`.

### Core

| Command                 | What it does                                  |
| ----------------------- | --------------------------------------------- |
| `/ding`                 | Show the help menu                            |
| `/ding help <command>`  | Detailed help for a specific command          |
| `/ding ui`              | Toggle the Live tab                           |
| `/ding live`            | Same as above                                 |
| `/ding stats`           | Same as above                                 |
| `/ding settings`        | Open the settings window                      |
| `/ding history`         | Toggle the History window                     |
| `/ding insights`        | Alias for History                             |
| `/ding reset`           | Reset current session data                    |
| `/ding goal <preset>`   | Set the coach goal: `off`, `ding`, `30m`, `60m` |
| `/ding split`           | Record a manual checkpoint                    |
| `/ding recap`           | Print the latest session recap                |
| `/ding on`              | Enable chat output                            |
| `/ding off`             | Disable chat output                           |

### Output Mode

| Command           | What it does                                          |
| ----------------- | ----------------------------------------------------- |
| `/ding mode full` | Chat prints `+XP`, `XP/hr`, and `TTL` on every gain   |
| `/ding mode ttl`  | Chat prints TTL only                                  |

### Rolling Window

| Command                   | What it does                                                       |
| ------------------------- | ------------------------------------------------------------------ |
| `/ding window <seconds>`  | Set the rolling window size for XP/hr calculation without resetting the session (minimum: 30s)   |

> **Example:** `/ding window 300` uses the last 5 minutes to calculate your XP/hr. Shorter windows react faster to pace changes; longer windows smooth out gaps.

### Float Commands

| Command              | What it does                |
| -------------------- | --------------------------- |
| `/ding float on`     | Show the floating HUD       |
| `/ding float off`    | Hide the floating HUD       |
| `/ding float lock`   | Lock the HUD in place       |
| `/ding float unlock` | Allow the HUD to be dragged |

> The floating frame hides automatically during combat and reappears when combat ends.

### Graph Commands

| Command                       | What it does                                            |
| ----------------------------- | ------------------------------------------------------- |
| `/ding graph`                 | Toggle the graph window                                 |
| `/ding graph on`              | Open the Graph tab                                      |
| `/ding graph off`             | Close the main window if the Graph tab is active        |
| `/ding graph zoom <level>`    | Set the time window: `3m`, `5m`, `15m`, `30m`, or `60m` |
| `/ding graph scale <mode>`    | Set the Y-axis mode: `visible`, `session`, or `fixed`   |
| `/ding graph fit`             | Snap the graph back to visible-data scaling              |
| `/ding graph max <xp/hr>`     | Set the fixed Y-axis cap and switch to fixed mode        |
### Insights Commands

| Command                     | What it does                                          |
| --------------------------- | ----------------------------------------------------- |
| `/ding insights`            | Toggle the Session Insights window                    |
| `/ding insights clear`      | Clear insights history for your current character     |
| `/ding insights keep <n>`   | Keep between 5 and 100 sessions (default: 30)         |

---

## UI Breakdown

### Minimap Button

The minimap button lives on the edge of your minimap and is your primary launcher.

- **Left-click** — Toggle the Dashboard tab
- **Middle-click** — Toggle the Graph tab
- **Right-click** — Toggle the Control Center tab
- **Drag** — Slide it anywhere around the minimap rim

You can hide it entirely from the Settings Window if you prefer slash commands.

---

### Stats Dashboard

A denser live dashboard showing your entire session at a glance.

- Progress header with current level XP, percent complete, and remaining XP
- Eight live metric cards: session time, session XP, current XP/hr, session average, TTL, pace delta, session money, and money/hr
- Quick-action buttons for Graph, Insights, Settings, and Reset

All values update every second. The window is draggable and remembers its position.

---

### Floating HUD

A minimal HUD that sits above your character showing:

```text
[2h 14m] to level
47,230 XP/hr  |  Session 42,801
```

Designed to stay out of your way. Hides in combat. Drag it anywhere when unlocked.

---

### XP Graph Tab

A dedicated graph tab inside the main window, updated every second while visible.

**Bar colors:**

- **Green** — XP/hr is higher than the previous segment (you're speeding up)
- **Red** — XP/hr is lower than the previous segment (you're slowing down)
- **Gray** — No XP was gained in that segment

**The gold line** across the chart is your session-wide average XP/hr up to each point in time — a useful baseline to see whether your current pace beats your overall average.

**Scale modes:**

- **Visible** — Fits the graph to the biggest bar currently on screen
- **Session** — Fits the graph to the biggest retained bar in the last 60 minutes
- **Fixed** — Uses the max XP/hr cap you set with `/ding graph max <xp/hr>`

**Header cards** show your current pace, session average, visible/session peak, and the active scale mode.

**Hover over any bar** to see a tooltip with:

- The time range for that segment
- XP gained in that segment
- XP/hr for that segment
- Session average up to that point

**Zoom levels:** `3m` · `5m` · `15m` · `30m` · `60m`

> DingTimer retains up to 60 minutes of graph data. Switching zoom levels never loses history.

---

### Session Insights Window

A dedicated analysis window for long-term improvement over multiple leveling sessions.

- Tracks history per character profile (`realm:name:class`)
- Shows median XP/hr, best XP/hr, average time in level, and trend percent
- Includes a mini trend chart built from your most recent sessions
- Lists the latest 10 sessions with level range, duration, XP/hr, money, zone, and trigger reason
- Supports history controls via `/ding insights clear` and `/ding insights keep <n>`

---

### Control Center

A larger control hub for all major options:

- Quick-open buttons for Dashboard, Graph, Insights, and Graph Reset
- Visibility toggles for chat output, floating HUD, graph, and minimap button
- Output controls for chat mode and rolling-window presets
- Graph controls for scale mode, fixed max, zoom presets, and remembered size
- Session reset with confirmation

---

## How XP/hr is Calculated

DingTimer uses a **rolling time window** rather than a session average. Here's why that matters:

- **Session average:** If you grinded 100k XP/hr for an hour, then went AFK for 30 minutes, your session average would show ~67k. Misleading.
- **Rolling window:** Only events within the last N seconds count. Your rate reflects what you're actually doing *right now*.

**The math:**

```text
1. Collect all XP gain events within the last [window] seconds
2. Sum the XP from those events
3. Elapsed = min(time since session start, window size)
4. XP/hr = (sum / elapsed) × 3600
```

The default window is **10 minutes (600 seconds)**. Use `/ding window <seconds>` to tune it.

---

## Level-Up Announcements

Every ding triggers a chat message with your session summary:

```text
[DingTimer] ★ LEVEL UP! ★  (Level 72)
  Time in level: 43m 17s
  Money earned:  12g 44s 3c
```

After the announcement, your session data resets automatically so your XP/hr reflects the new level.

---

## Saved Variables

DingTimer stores all data in the account-wide `DingTimerDB` SavedVariable. Session history is bucketed per character profile inside that database. This includes:

- All settings and toggle states
- Main window and floating HUD positions
- Historical sessions per character profile (last 30 kept by default)
- Graph presentation settings (zoom, scale mode, fixed max)
- Minimap button angle

Deleting `DingTimerDB` from your SavedVariables folder resets everything to defaults.

---

## Compatibility

| Package target           | Status                    |
| ------------------------ | ------------------------- |
| `## Interface: 30300`    | Supported by this package |
| Other clients            | Unverified                |

---

## Contributing

Bug reports, feature requests, and pull requests are welcome.

1. Fork the repo
2. Create a branch: `git checkout -b my-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push: `git push origin my-feature`
5. Open a pull request

Please include a description of what changed and why.

---

## Coverage

Run Lua coverage from repo root:

```powershell
.\coverage.ps1
```

This generates `luacov.report.out` and `luacov.stats.out` in the project root.

---

## License

MIT — do whatever you want with it, just don't blame me if your /played skyrockets because you got addicted to optimizing your XP/hr.

---

*May your queues be short, your pulls be clean, and your XP/hr be ever upward.*

[Report a Bug](https://github.com/dmedlin87/DingTimer/issues) · [Request a Feature](https://github.com/dmedlin87/DingTimer/issues)
