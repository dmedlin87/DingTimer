# Honor Tracking Proposal

## Overview
DingTimer currently provides top-tier tracking for XP and Gold. To support players focused on Player vs. Player (PvP) progression, we propose expanding DingTimer's core capabilities to track **Honor Points** and **Honor Kills (HKs)**.

This feature will mirror the existing highly-polished XP tracking but tailor the metrics for battlegrounds and world PvP. **Arena / conquest-style currency is explicitly out of scope for v1** pending verification of Ascension Bronzebeard's actual reward model (see Risks §1).

## Proposed Features

### 1. Honor Per Hour & HKs Per Hour
- **Rolling Window Calculation**: Just like XP/hr, Honor/hr will use a rolling time window to accurately reflect a player's current pacing in a battleground or PvP session, adapting to bursts of honor (like capturing an objective) and lulls.
- **HK Tracking**: Alongside Honor Points, track Honor Kills (HKs) per hour to give players a secondary metric for their PvP engagement.

### 2. Time To Goal (TTG)
- **Honor Cap Tracking**: Instead of "Time To Level" (TTL), the default PvP mode will track "Time to Cap", forecasting how long until the player reaches the maximum allowable Honor Points (e.g., 75,000 Honor).
- **Custom Item Goals**: Players can set a custom Honor goal (e.g., 30,000 Honor for a new weapon). The TTG metric will dynamically update based on their current Honor/hr pace.

### 3. Dedicated PvP Mode
- **Smart Auto-Switching**: DingTimer can detect when a player enters a Battleground and automatically transition the UI from "XP Mode" to "PvP Mode". Arena auto-switching is deferred to a later phase pending reward-model verification.
- **Manual Toggle**: Players at max level or doing World PvP can manually toggle PvP mode via slash command or through the Settings Hub. The full command surface is defined in Risks §6.

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

## Phased Rollout

Breaking this into phases reduces implementation risk and lets each layer be tested before the next is built.

| Phase | Scope | Gate |
|-------|-------|------|
| **1 — Core metrics** | Manual `/ding pvp` toggle; Honor/hr + HK/hr rolling window; HUD and Live Panel swap; session reset. BG and world PvP only. | API feasibility confirmed (see Risks §1) |
| **2 — Match recaps & history** | Auto-switch on BG zone-in; match-level recap on exit; PvP history rows in Insights with BG metadata. | Phase 1 shipped and stable |
| **3 — Persistent goals & coach** | TTG to cap; custom item goals that survive logout; coach alerts for Honor milestones. | Session/match/goal boundary definitions finalised (see Risks §3) |
| **4 — Arena / conquest (conditional)** | Arena currency tracking, arena-specific TTG, rating display. | Ascension arena reward model verified and distinct from Honor (see Risks §1) |

Each phase ships a schema migration (`Store.lua` v9, v10, …). Phases 1–3 assume the parallel-namespace approach (Option A in Risks §4) unless the team decides otherwise before Phase 1 starts.

---

## Open Questions / Risks

### 1. Realm and API Feasibility (Hard Blocker)

**This feature must not enter active development until the following is confirmed on Ascension Bronzebeard.**

DingTimer targets a private WotLK server (`## Interface: 30300`). Private servers vary in which Blizzard API events they implement, which events fire with correct payloads, and whether honor and HK data surfaces through the same paths as on official Blizzard WotLK. Because the addon's core state, store, and slash-command flows are still entirely XP-centric, discovering mid-implementation that a key event does not fire — or fires with wrong data — would invalidate significant work.

**Required verification before any code is written:**
- Does `HONOR_GAINED` (or the WotLK equivalent) fire on Ascension with a correct honor delta?
- Does `UPDATE_BATTLEFIELD_SCORE` fire at BG end with populated score data?
- Does `GetHonorInfo()` return current, max, and rank data accurately in-session?
- Are HK counts exposed through the score frame API or a separate event?
- **Arena currency:** Ascension's PvP documentation distinguishes Honor (BG progression) from Arena/Conquest points and rating. If arenas award a separate currency rather than Honor, then "Honor/hr in arena" is the wrong product framing entirely. Verify whether Bronzebeard arenas award Honor, arena points, both, or neither before scoping arena support.

**Outcome of verification:**
- If Honor events work cleanly → proceed with Phases 1–3 as designed.
- If Honor events are partial or unreliable → descope to polling `GetHonorInfo()` on a heartbeat and document the accuracy limitations.
- If arena awards a distinct currency → keep arena out of scope for all phases until a separate currency model is designed.

### 2. Honor/HK Measurement Contract (Highest Priority)

**Source of truth:** Honor and HK values must be sourced from specific WoW API events. The implementation must decide whether to rely on `HONOR_GAINED` (or equivalent), `UPDATE_BATTLEFIELD_SCORE`, periodic polling of `GetHonorInfo()`, or a combination. Each source has different timing and granularity characteristics.

**Duplicate and delayed reward problem:** Battleground honor is delivered in layers — kill-based honor arrives in-match while end-of-match bonus honor, objective rewards, and any corrected/late updates can arrive seconds or minutes later. Without explicit deduplication rules, the same honor may be counted twice or attributed to the wrong time window, producing a corrupted Honor/hr figure.

**Required contract before implementation:**
- Which WoW API event(s) are authoritative for honor increments?
- How are end-of-match lump-sum rewards distinguished from per-kill rewards in the event stream?
- What is the deduplication key (e.g., event timestamp + amount + source type)?
- Are HK counts sourced from the same event, or a separate kill-event listener?
- Does the rolling window receive the full lump sum at delivery time, or is it spread across the match duration?

### 3. Session / Match / Persistent-Goal Boundary Definitions (Highest Priority)

The proposal currently uses "match recap," "session honor," "TTG to cap," and "separate PvP history" interchangeably. They are distinct units and must be defined explicitly:

| Unit | Definition | Lifetime |
|------|-----------|---------|
| **Match** | One battleground or arena instance from zone-in to zone-out | Clears on instance exit |
| **PvP Session** | A continuous block of PvP mode time (manual or auto-switched), possibly spanning multiple matches | Clears on mode switch or `/ding reset` |
| **Persistent Goal** | "Time to cap" or "time to item" — a target denominated in cumulative honor that survives logouts, reloads, and honor spending | Lives in SavedVariables; must account for spending |

**Design decision required:** The rolling Honor/hr window is session-scoped or match-scoped? The HUD TTG number is driven by session pace or match pace? The History tab stores match rows, session rows, or both?

### 4. Schema and Migration Strategy (Highest Priority)

This feature is larger than a UI change. The current `DingTimerDB` schema is organized around XP-named fields (`xp`, `xpHistory`, graph fields with XP semantics). A concrete migration plan is required:

- **Option A — Parallel namespace:** Add `DingTimerDB.pvp` alongside `DingTimerDB.xp`. Each schema version bump adds PvP fields with nil-safe defaults. Lower risk of breaking existing XP data; higher long-term duplication.
- **Option B — Generic metric model:** Refactor both XP and Honor to store under a shared `DingTimerDB.metrics[type]` key. Cleaner long-term, but requires a more invasive migration and coordinated updates across `Store.lua`, `Core_DingTimer.lua`, `Insights.lua`, and `GraphMath.lua`.

**Required before implementation:**
- Decide Option A vs. B (or a hybrid).
- Write the migration in `Store.lua` as a new numbered step (currently v3–v8; next would be v9).
- Ensure backward compatibility so existing XP session history is not corrupted on upgrade.
- Document what happens to PvP data on a schema downgrade or addon disable.

### 5. Auto-Switching and Partial-Match Policy

"Enter BG = switch to PvP mode" is underspecified. Every case below must have an explicit rule before Phase 2 ships:

**Mode switching:**
- **Mixed play:** Player queues for a BG while leveling; returns to leveling after. Does XP mode resume automatically on BG exit?
- **World PvP at max level:** No BG zone entered; honor earned from open-world kills. Does auto-switch trigger, and on what event?
- **Queue time:** Player is in queue but not yet inside the instance. XP mode or PvP mode?
- **PvP zones without active honor:** Player is in Wintergrasp/Tol Barad during a non-battle window. Mode?
- **Default behavior:** Is auto-switching on by default or opt-in? Getting this wrong is invasive to PvE players and confusing to PvP players who never configured it.

**Partial-match and exit policy (must be first-class, not left to implementation):**
- **Queue time:** Is time spent in queue counted toward Honor/hr denominator? Almost certainly not — but this must be explicit.
- **Loading screen / instance transition time:** Counted or excluded from match duration?
- **Early leave (voluntary):** Match ends incomplete. Is a partial recap written to history? Is Honor/hr for that match marked as incomplete?
- **Disconnect mid-match:** Player reconnects inside or outside the instance. Is the gap in event timestamps treated as idle time, excluded time, or a session break?
- **Deserter debuff exit:** Same as early leave, but the client may not fire a clean zone-change event. Needs a separate detection path.

Each of these materially changes the Honor/hr number a user sees. A disconnected 20-minute AV where the player was offline for 15 minutes should not report 4× inflated Honor/hr.

### 6. Slash Command and Settings Contract

The proposal mentions `/ding pvp` but the addon has an explicit command dispatch model (`Commands.lua`). The full command surface must be defined before implementation to avoid UX ambiguity and rework:

**Proposed command surface (to be confirmed):**

| Command | Behavior |
|---------|----------|
| `/ding pvp on` | Force PvP mode; suppresses XP HUD output |
| `/ding pvp off` | Force XP mode; restores XP HUD output |
| `/ding pvp auto` | Enable auto-switching on BG zone-in/out (default) |
| `/ding pvp goal cap` | Set TTG target to honor cap (75,000) |
| `/ding pvp goal <amount>` | Set TTG target to a specific honor amount |
| `/ding pvp goal off` | Clear TTG goal; hide TTG field |
| `/ding pvp reset` | Clear current PvP session metrics (does not clear persistent goal progress) |
| `/ding pvp status` | Print current mode, goal, session honor, and Honor/hr to chat |

**Settings Hub decisions required:**
- Which of the above are also exposed as checkboxes/inputs in the Settings Hub PvP group?
- Does toggling PvP mode in Settings Hub immediately affect the HUD, or only take effect on next login/reload?
- Is there a "pause XP chat announcements while in PvP mode" toggle, separate from the global announcements setting?

### 7. Honor Cap / Spend / Overflow Behavior

The UI must define explicit states for boundary conditions:

- **Already capped on login:** TTG should show "Capped" or be hidden, not `0 min`.
- **Reaching cap mid-session:** Progress bar should clamp at 100%; Honor/hr continues displaying but TTG switches to "Capped."
- **Spending honor mid-session:** Current honor drops; TTG recalculates from new baseline. The rolling-window rate should not be affected (spending is not a negative honor event).
- **Overshooting a custom item goal:** Similar to cap — display "Goal Reached" rather than a negative or nonsensical TTG.
- **No goal set:** The TTG field must have a defined empty state (hidden, dashes, or "Set a goal").

### 8. Insights / History Normalization

"Best Honor/hr by battleground" requires metadata that is not currently stored. Before implementing History tab PvP rows, define the schema for each stored entry:

- Battleground name (Warsong Gulch, Alterac Valley, Arathi Basin, …)
- Match result (win / loss / incomplete / deserter)
- Match duration (in seconds, not estimated from rolling window)
- Session type that contains this match
- Whether queue time is included or excluded from duration

Without these fields, "best session" and "median pace" comparisons are noisy across battlegrounds with very different match durations (a 5-minute WSG vs. a 90-minute AV are not comparable on raw Honor/hr).

### 9. Graph Retention and Long-Goal Mismatch

The current graph retains up to 60 minutes of rolling event history — appropriate for XP pacing within a level. Honor goals can span many matches or multiple sessions. The proposal must decide:

- Does the Honor graph remain short-horizon only (60-minute rolling window), matching existing XP graph behavior?
- Or does PvP get an additional match-level view (honor per match, plotted across the session)?
- For multi-session goals like "time to item," is there a longer-horizon chart, or is that left to the History tab?

Leaving the graph at 60 minutes is a valid choice but should be a conscious one, documented so users understand why a long AV shows a truncated window.

### 10. Chat Spam and Notification Throttling

Honor and HK updates are noisier than level dings. Milestone announcements and match recaps need explicit throttle rules:

- **Milestone interval:** What is the default announcement interval (e.g., every 5,000 Honor)? Is it configurable?
- **Suppression during combat:** Should announcements be suppressed while in active combat to avoid UI noise at critical moments?
- **Match recap trigger:** Does the recap fire on `ZONE_CHANGED` (leaving instance) or on `UPDATE_BATTLEFIELD_SCORE` with end-of-match detection? What if the player disconnects mid-match?
- **Default state:** Are chat announcements on or off by default? PvP players in premade groups may not want addon spam visible to the raid.

### 11. SavedVariables Growth and Retention Budget

Storing BG metadata, per-match honor logs, and persistent goal progress will grow `DingTimerDB` faster than XP history alone. Without a retention policy, long-term PvP players can quietly accumulate bloated SavedVariables that slow addon load and increase corruption risk on unexpected logout.

**Decisions required:**
- **Max stored match rows:** What is the cap on PvP history entries per character? (Suggested starting point: 200 matches, same order of magnitude as XP session history.)
- **Per-event honor log persistence:** Is the raw event list (individual honor increments with timestamps) persisted to SavedVariables, or is it session-only memory that is summarised into a single match row on exit? Persisting raw events is expensive; summarising on exit is sufficient for all currently proposed UI features.
- **Trim policy:** When the match-row cap is exceeded, drop the oldest entries (FIFO), or keep the N highest Honor/hr rows plus the N most recent? FIFO is simpler; ranked retention preserves "best sessions" more reliably.
- **Arena data (if Phase 4 ships):** Arena currency rows use a different schema from Honor rows. The budget should account for both row types if they coexist.
- **Storage estimate:** At ~200 bytes per match row × 200 rows = ~40 KB per character. That is acceptable. Raw per-event logs could be 10–100× larger and should not be persisted.

### 12. Acceptance Criteria and Test Matrix

Before marking each phase complete, the following scenarios must produce correct output. These should be codified as test cases in `tests/test_honor*.lua`:

| Phase | Scenario | Expected Behavior |
|-------|----------|-----------------|
| 1 | Reload mid-match | Session honor and HK counts survive; TTG recalculates correctly |
| 1 | `/ding pvp on` while leveling | HUD swaps to PvP view; XP chat output suppressed |
| 1 | `/ding pvp off` in PvP mode | HUD restores XP view; XP tracking resumes |
| 1 | Honor already capped on login | TTG shows "Capped"; no division-by-zero or negative display |
| 1 | Honor spent mid-session | TTG recalculates from new baseline; Honor/hr rate unaffected |
| 1 | No goal configured | TTG field hidden or shows placeholder; no error |
| 1 | `/ding pvp reset` | Session metrics clear; persistent goal progress preserved |
| 2 | Leave BG instance cleanly | Match recap fires with correct Honor, HKs, duration; session continues |
| 2 | Disconnect mid-match, reconnect outside | Gap excluded from Honor/hr denominator; partial recap written |
| 2 | Early leave / deserter exit | Match marked incomplete in history; Honor/hr not inflated |
| 2 | BG end-of-match bonus arrives late | Attributed to correct match row; no double-count in session total |
| 3 | Logout and re-login | Persistent goal progress restored from SavedVariables; TTG correct |
| 3 | Custom goal reached mid-session | Progress bar clamps at 100%; TTG switches to "Goal Reached" |
| 3 | Auto-switch: BG zone-in while leveling | Mode switches to PvP; XP mode resumes on zone-out |
| 3 | PvP history exceeds retention cap | Oldest rows trimmed; no error; existing rows intact |
