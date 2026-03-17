# DingTimer

WoW addon (Lua 5.1) for real-time XP/hr tracking, time-to-ding, session coaching, and leveling analytics.

## Project Layout

```
DingTimer/          # Addon source (this folder is what gets zipped for release)
  DingTimer.toc     # Addon manifest + load order
  DingTimer.lua     # Entry point: event registration, slash command wiring
  Core_DingTimer.lua # XP/hr rate calculation, session state, floating HUD
  Store.lua         # SavedVariables init and schema migrations (v3–v8)
  SessionCoach.lua  # Coach goals, alerts, segment tracking, recap
  Insights.lua      # Per-character session history and analytics
  Commands.lua      # Slash command dispatch table (/ding, /dt)
  GraphMath.lua     # Pure stateless graph math (easily testable)
  Util.lua          # Formatting, shared UI helpers, theme
  UI_*.lua          # UI panels (MainWindow, StatsWindow, XPGraphWindow, etc.)
tests/
  mocks.lua         # WoW API mock + test framework (it/run_tests/assert_*)
  test_*.lua        # One file per module
```

## Running Tests

**Windows (preferred):**
```powershell
.\coverage.ps1
```
Requires Lua + LuaRocks installed at `%LOCALAPPDATA%\Programs\Lua\`. Runs all `tests/test_*.lua` with luacov coverage.

**Linux / CI:**
```bash
for f in tests/test_*.lua; do lua5.4 "$f" || exit 1; done
```

`run_tests.py` is Linux-only (uses `.so` shared libs) — don't use it on Windows.

## Release

Tag a commit with `v*` to trigger CI. The `test` job runs first; `release` only fires if tests pass. The zip packages `DingTimer/` only (not the repo root).

```bash
git tag v0.7.0 && git push origin v0.7.0
```

## Key Gotchas

**WoW target:** Private WotLK server (Bronzebeard). `## Interface: 30300` and the `_retail_` install path are both correct — do not change them.

**Load order matters:** `DingTimer.toc` file order is significant. `Store.lua` must load before `SessionCoach.lua` because Store provides fallback stubs for `GetCoachDefaults` and `EnsureCoachConfig` (used only when SessionCoach is absent). SessionCoach overrides these and defines `InitCoachState`, `NoteCoachXP`, `NoteCoachMoney`, etc. See the comment in the `.toc`.

**Shared namespace:** All modules share a single `NS` table passed as the second vararg (`local ADDON, NS = ...`). Runtime state lives in `NS.state`; persistent state in `DingTimerDB` (SavedVariables).

**Running totals:** `NS.state.windowXP` and `NS.state.windowMoney` are maintained as running sums by `pruneEvents`. Any reset must clear both the events list and the running total atomically — `resetXPState()` does this correctly.

**`GetSessionSnapshot` has a pruning side effect:** It calls `computeXPPerHour` → `pruneEvents`, which removes expired events from `NS.state.events` and decrements `NS.state.windowXP`. This is idempotent for a given `now` value (calling it twice with the same timestamp is safe), but it is not a pure read. `sessionPeakXph` is updated separately in `onXPUpdate`, not here.

**Test styles:** The test suite has two styles — `it()/run_tests()` (preferred) and bare function calls. Both work; new tests should use `it()/run_tests()`.

## Architecture Notes

- `GraphMath.lua` is pure/stateless — all inputs are explicit parameters, making it the easiest module to test
- UI panels are lazily initialized (created on first tab access) via factory callbacks registered on `NS`
- The coach heartbeat runs every 1 second via `C_Timer.NewTicker` started at login
- Schema migrations in `Store.lua` run sequentially (v3 → v8); add new migrations at the end
