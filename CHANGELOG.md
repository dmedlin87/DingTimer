# Changelog

## Unreleased

- Promoted `dingSoundEnabled` into a documented saved setting with popup control, normalization, and level-up sound coverage.
- Trimmed slash-command compatibility handling into a smaller helper, removed the no-op logout event registration, and added explicit heartbeat ticker stop coverage.
- Fixed Windows coverage setup when LuaRocks emits quoted environment assignments.
- Fixed level-up event ordering so completed-level rollover XP is not counted in the fresh session when `PLAYER_LEVEL_UP` arrives before `PLAYER_XP_UPDATE`.

## 1.1.1

- Added installer-ready GitHub Release packaging with `DingTimer-vX.Y.Z.zip` and `addon-manifest.json` assets for AscensionUp.

## 1.1.0

- Added PvP mode with Honor and HK tracking across commands, UI panels, persistence, and session resume behavior.
- Normalized historical XP and Honor rates for rapid turn-ins and multi-return Honor API results.
- Improved settings layout, tab navigation behavior, and release/test automation coverage.

## 0.6.0

- Current package version from `DingTimer/DingTimer.toc`.
- Existing addon functionality includes XP/hr tracking, TTL, session coaching, analysis graphs, history, and floating HUD support.
