# AGENTS.md

Repository guidance for automated and human contributors.

## Source of Truth

- `README.md` is the primary user-facing overview.
- `CLAUDE.md` contains agent handoff notes and module-specific warnings.
- `DingTimer/DingTimer.toc` defines addon load order and must stay in sync with code.
- `install_ding-timer.ps1` and `.github/workflows/*.yml` define install and release behavior.

## Working Rules

- Preserve `.toc` ordering unless the code and tests are updated together.
- Treat `tests/test_*.lua` as the compatibility and regression suite.
- Use `coverage.ps1` on Windows when validating coverage-sensitive changes.
- Keep docs aligned with the actual tab labels, slash commands, install paths, and release triggers in code.
