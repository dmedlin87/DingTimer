# Honor Tracking Proposal

## Overview
DingTimer currently provides top-tier tracking for XP and Gold. To support players focused on Player vs. Player (PvP) progression, we propose expanding DingTimer's core capabilities to track **Honor Points** and **Honor Kills (HKs)**.

This feature will mirror the existing highly-polished XP tracking but tailor the metrics for battlegrounds, world PvP, and arena grinds.

## Proposed Features

### 1. Honor Per Hour & HKs Per Hour
- **Rolling Window Calculation**: Just like XP/hr, Honor/hr will use a rolling time window to accurately reflect a player's current pacing in a battleground or PvP session, adapting to bursts of honor (like capturing an objective) and lulls.
- **HK Tracking**: Alongside Honor Points, track Honor Kills (HKs) per hour to give players a secondary metric for their PvP engagement.

### 2. Time To Goal (TTG)
- **Honor Cap Tracking**: Instead of "Time To Level" (TTL), the default PvP mode will track "Time to Cap", forecasting how long until the player reaches the maximum allowable Honor Points (e.g., 75,000 Honor).
- **Custom Item Goals**: Players can set a custom Honor goal (e.g., 30,000 Honor for a new weapon). The TTG metric will dynamically update based on their current Honor/hr pace.

### 3. Dedicated PvP Mode
- **Smart Auto-Switching**: DingTimer can detect when a player enters a Battleground or Arena and automatically transition the UI from "XP Mode" to "PvP Mode".
- **Manual Toggle**: Players at max level or doing World PvP can manually toggle PvP mode via a slash command (e.g., `/ding pvp`) or through the Settings Hub.

### 4. UI Integrations & High-Quality UX

#### Floating HUD
- When in PvP Mode, the Floating HUD will cleanly swap its top line to `[2h 14m] to Cap (or Goal)` and the bottom line to `4,230 Honor/hr | Session 2,801`.
- Clean, familiar, and stays out of the way during intense combat.

#### Live Panel
- The Live Panel will replace the "Progress to Level" bar with a "Progress to Honor Cap/Goal" bar.
- Metric cards will display: Session Honor, Current Honor/hr, Session Average, TTG, Session HKs, and HKs/hr.

#### Analysis Graph (Honor Graph)
- The existing XP graph architecture will be extended to visualize Honor gains.
- Huge spikes will visibly correlate with Battleground completions or major objective captures.
- Includes the same scale modes (Visible, Session, Fixed) for analyzing performance across a long Alterac Valley or multiple quick Warsong Gulch matches.

#### Session Insights (PvP History)
- The History tab will track PvP sessions separately from leveling sessions.
- Players can review their best Honor/hr sessions, median pacing, and performance across different battlegrounds.

### 5. Chat Announcements
- **Milestone Announcements**: Instead of "Ding!" level-up celebrations, the addon can announce when specific Honor milestones are reached (e.g., every 5,000 Honor, or upon reaching the cap).
- **Match Recap**: A summary output when leaving a battleground detailing Honor gained, HKs, and average Honor/hr for that match.

## Implementation Guidelines
- **Zero Code Clutter**: The underlying math engine for rolling windows and graph data should be abstracted so it can process generic "events" (XP, Gold, or Honor) rather than duplicating the logic.
- **Settings Segregation**: Keep PvP settings clearly grouped in the Settings Hub so players who only PvE aren't overwhelmed by Honor settings, and vice versa.
