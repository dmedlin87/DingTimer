# DingTimer

See [AGENTS.md](./AGENTS.md) for repo-wide operating rules.

HUD-first addon notes for contributors and agents.

## Active Runtime Shape

The shipped addon now loads only these modules through [`DingTimer/DingTimer.toc`](./DingTimer/DingTimer.toc):

- `Util.lua`
- `Store.lua`
- `Core_DingTimer.lua`
- `Actions.lua`
- `Commands.lua`
- `UI_HUDPopup.lua`
- `DingTimer.lua`

Older files such as `UI_MainWindow.lua`, `UI_SettingsWindow.lua`, `UI_XPGraphWindow.lua`, `UI_InsightsWindow.lua`, `UI_MinimapButton.lua`, `SessionCoach.lua`, `Insights.lua`, `Pvp.lua`, and `GraphMath.lua` may still exist in the repo as historical reference, but they are not part of the active addon load path.

## Source Layout

```text
DingTimer/
  DingTimer.toc      # Active load order
  Util.lua           # Formatting, colors, shared UI helpers
  Store.lua          # SavedVariables init and schema v10 cleanup
  Core_DingTimer.lua # Rolling XP state, HUD, and heartbeat ticker
  Actions.lua        # Popup-facing actions and session reset
  Commands.lua       # Slash command routing and compatibility shims
  UI_HUDPopup.lua    # Compact popup anchored to HUD or UIParent
  DingTimer.lua      # Event registration and startup flow
tests/
  mocks.lua
  test_*.lua
```

## Current Product Contract

- DingTimer is leveling-only in the active build.
- The floating HUD is the primary interface.
- The popup is the only active settings surface.
- Removed dashboard commands must print `Removed in HUD-first build; use /ding settings`.
- Runtime reset, level-up, and logout must not write history, coach, or PvP recap data.
- Legacy `xp`, `pvp`, and `coach` tables in `DingTimerDB` must be preserved if they already exist, but no new records should be added by this build.

## Important Runtime Details

- `Core_DingTimer.lua` owns the 1-second ticker and the floating HUD.
- `NS.GetSessionSnapshot()` is still derived from rolling XP events and remains the source for HUD text.
- `Store.lua` now migrates to `schemaVersion = 10` and clears dead window, graph, minimap, and tab state.
- The popup has no persisted position. It anchors below the HUD when the HUD is visible and centers on `UIParent` otherwise.
- New installs should land in the HUD-first flow. Existing saved HUD preferences must still win.

## Tests

Preferred validation on Windows:

```powershell
.\coverage.ps1
```

Useful targeted runs:

```powershell
python .\run_tests.py tests\test_hud_visibility.lua
python .\run_tests.py tests\test_hud_refresh.lua
python .\run_tests.py tests\test_hud_popup.lua
python .\run_tests.py tests\test_commands_compat.lua
python .\run_tests.py tests\test_store_migration_v10.lua
python .\run_tests.py tests\test_no_history_recording.lua
```

## Editing Warnings

- Keep [`DingTimer/DingTimer.toc`](./DingTimer/DingTimer.toc) aligned with the actual active modules.
- Do not reintroduce references to the removed tabbed dashboard or minimap launcher without updating tests and docs together.
- If you expand the popup, keep it compact; the product direction is intentionally minimal.
- If you change command behavior, update README command tables and compatibility notes in the same change.
