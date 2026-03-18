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

---

## Open Questions / Risks

### 1. Honor/HK Measurement Contract (Highest Priority)

**Source of truth:** Honor and HK values must be sourced from specific WoW API events. The implementation must decide whether to rely on `HONOR_GAINED` (or equivalent), `UPDATE_BATTLEFIELD_SCORE`, periodic polling of `GetHonorInfo()`, or a combination. Each source has different timing and granularity characteristics.

**Duplicate and delayed reward problem:** Battleground honor is delivered in layers — kill-based honor arrives in-match while end-of-match bonus honor, objective rewards, and any corrected/late updates can arrive seconds or minutes later. Without explicit deduplication rules, the same honor may be counted twice or attributed to the wrong time window, producing a corrupted Honor/hr figure.

**Required contract before implementation:**
- Which WoW API event(s) are authoritative for honor increments?
- How are end-of-match lump-sum rewards distinguished from per-kill rewards in the event stream?
- What is the deduplication key (e.g., event timestamp + amount + source type)?
- Are HK counts sourced from the same event, or a separate kill-event listener?
- Does the rolling window receive the full lump sum at delivery time, or is it spread across the match duration?

### 2. Session / Match / Persistent-Goal Boundary Definitions (Highest Priority)

The proposal currently uses "match recap," "session honor," "TTG to cap," and "separate PvP history" interchangeably. They are distinct units and must be defined explicitly:

| Unit | Definition | Lifetime |
|------|-----------|---------|
| **Match** | One battleground or arena instance from zone-in to zone-out | Clears on instance exit |
| **PvP Session** | A continuous block of PvP mode time (manual or auto-switched), possibly spanning multiple matches | Clears on mode switch or `/ding reset` |
| **Persistent Goal** | "Time to cap" or "time to item" — a target denominated in cumulative honor that survives logouts, reloads, and honor spending | Lives in SavedVariables; must account for spending |

**Design decision required:** The rolling Honor/hr window is session-scoped or match-scoped? The HUD TTG number is driven by session pace or match pace? The History tab stores match rows, session rows, or both?

### 3. Schema and Migration Strategy (Highest Priority)

This feature is larger than a UI change. The current `DingTimerDB` schema is organized around XP-named fields (`xp`, `xpHistory`, graph fields with XP semantics). A concrete migration plan is required:

- **Option A — Parallel namespace:** Add `DingTimerDB.pvp` alongside `DingTimerDB.xp`. Each schema version bump adds PvP fields with nil-safe defaults. Lower risk of breaking existing XP data; higher long-term duplication.
- **Option B — Generic metric model:** Refactor both XP and Honor to store under a shared `DingTimerDB.metrics[type]` key. Cleaner long-term, but requires a more invasive migration and coordinated updates across `Store.lua`, `Core_DingTimer.lua`, `Insights.lua`, and `GraphMath.lua`.

**Required before implementation:**
- Decide Option A vs. B (or a hybrid).
- Write the migration in `Store.lua` as a new numbered step (currently v3–v8; next would be v9).
- Ensure backward compatibility so existing XP session history is not corrupted on upgrade.
- Document what happens to PvP data on a schema downgrade or addon disable.

### 4. Auto-Switching Edge Cases

"Enter BG/Arena = switch to PvP mode" is underspecified. The following cases must each have an explicit rule:

- **Mixed play:** Player queues for a BG while leveling; returns to leveling after. Does XP mode resume automatically?
- **World PvP at max level:** No BG zone entered; honor earned from open-world kills. Does auto-switch trigger? On what event?
- **Queue time:** Player is in queue but not yet in the instance. Is this PvP mode or XP mode?
- **PvP zones without honor:** Player is in Wintergrasp/Tol Barad during a non-active battle. Mode?
- **Default behavior:** Is auto-switching on by default, or opt-in? A wrong default will feel invasive to PvE players and confusing to PvP players who never configured it.

### 5. Honor Cap / Spend / Overflow Behavior

The UI must define explicit states for boundary conditions:

- **Already capped on login:** TTG should show "Capped" or be hidden, not `0 min`.
- **Reaching cap mid-session:** Progress bar should clamp at 100%; Honor/hr continues displaying but TTG switches to "Capped."
- **Spending honor mid-session:** Current honor drops; TTG recalculates from new baseline. The rolling-window rate should not be affected (spending is not a negative honor event).
- **Overshooting a custom item goal:** Similar to cap — display "Goal Reached" rather than a negative or nonsensical TTG.
- **No goal set:** The TTG field must have a defined empty state (hidden, dashes, or "Set a goal").

### 6. Insights / History Normalization

"Best Honor/hr by battleground" requires metadata that is not currently stored. Before implementing History tab PvP rows, define the schema for each stored entry:

- Battleground name (Warsong Gulch, Alterac Valley, Arathi Basin, …)
- Match result (win / loss / incomplete / deserter)
- Match duration (in seconds, not estimated from rolling window)
- Session type that contains this match
- Whether queue time is included or excluded from duration

Without these fields, "best session" and "median pace" comparisons are noisy across battlegrounds with very different match durations (a 5-minute WSG vs. a 90-minute AV are not comparable on raw Honor/hr).

### 7. Graph Retention and Long-Goal Mismatch

The current graph retains up to 60 minutes of rolling event history — appropriate for XP pacing within a level. Honor goals can span many matches or multiple sessions. The proposal must decide:

- Does the Honor graph remain short-horizon only (60-minute rolling window), matching existing XP graph behavior?
- Or does PvP get an additional match-level view (honor per match, plotted across the session)?
- For multi-session goals like "time to item," is there a longer-horizon chart, or is that left to the History tab?

Leaving the graph at 60 minutes is a valid choice but should be a conscious one, documented so users understand why a long AV shows a truncated window.

### 8. Chat Spam and Notification Throttling

Honor and HK updates are noisier than level dings. Milestone announcements and match recaps need explicit throttle rules:

- **Milestone interval:** What is the default announcement interval (e.g., every 5,000 Honor)? Is it configurable?
- **Suppression during combat:** Should announcements be suppressed while in active combat to avoid UI noise at critical moments?
- **Match recap trigger:** Does the recap fire on `ZONE_CHANGED` (leaving instance) or on `UPDATE_BATTLEFIELD_SCORE` with end-of-match detection? What if the player disconnects mid-match?
- **Default state:** Are chat announcements on or off by default? PvP players in premade groups may not want addon spam visible to the raid.

### 9. Acceptance Criteria and Test Matrix

Before marking this feature complete, the following scenarios must each produce correct, trustworthy output. These should be codified as test cases in `tests/test_honor*.lua`:

| Scenario | Expected Behavior |
|----------|-----------------|
| Reload mid-match | Session honor and HK counts survive; TTG recalculates correctly |
| Logout and re-login | Persistent goal progress is restored from SavedVariables |
| Leave BG instance | Match recap fires; session continues if still in PvP mode |
| BG end-of-match bonus arrives late | Attributed to correct time window; no double-count |
| Auto-switch disabled, manual `/ding pvp` | PvP mode activates; XP tracking pauses |
| Honor already capped on login | TTG shows "Capped"; no division-by-zero or negative display |
| Custom goal reached mid-session | Progress bar clamps at 100%; TTG switches to "Goal Reached" |
| Honor spent mid-session | TTG recalculates; Honor/hr unaffected |
| No goal configured | TTG field hidden or shows placeholder; no error |
| Manual reset (`/ding reset`) | Session metrics clear; persistent goal progress preserved |
