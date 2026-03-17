# Contributing

Thanks for helping improve DingTimer.

## Before You Open a PR

- Make sure the addon still loads in WoW and the relevant behavior has been exercised.
- Run the test suite from the repo root:
  - Windows: `.\coverage.ps1`
  - CI/Linux: the workflow runs `tests/test_*.lua` under Lua 5.1 and Lua 5.4
- Keep changes focused. Small, reviewable diffs are easier to validate.

## Code and Docs

- Preserve `DingTimer/DingTimer.toc` load order unless the code and tests are updated together.
- Keep docs aligned with the actual slash commands, UI labels, installer behavior, and release flow.
- Prefer changes that preserve backwards compatibility with existing SavedVariables and in-game behavior.

## Pull Requests

- Summarize what changed and why.
- Call out any behavior changes, migration effects, or new test coverage.
