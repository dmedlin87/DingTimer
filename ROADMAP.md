# ROADMAP.md

## Current Goals

- Keep the addon centered on the floating HUD and compact settings popup.
- Preserve the current slash-command compatibility shims and HUD-first startup flow.
- Favor small maintenance changes that improve correctness, clarity, and test coverage.

## Non-Goals

- Reintroducing dashboard, graph, history, insights, coach, minimap, or PvP surfaces.
- Large architecture rewrites or speculative subsystem churn.
- Expanding the addon beyond leveling HUD behavior without a deliberate product change.

## Maintenance Priorities

- Keep `DingTimer.toc`, docs, and tests aligned with the active runtime files.
- Preserve Lua 5.1 / WoW addon compatibility and safe SavedVariables migrations.
- Prefer pure helpers and narrow ownership cleanup when they make HUD behavior easier to verify.
