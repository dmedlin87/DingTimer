-- Tests that settingsWindowPosition is initialised from Store defaults
-- and survives schema migrations from older saved-variable data.

dofile("tests/mocks.lua")

SetProfileIdentity("Hero", "Azeroth", "WARRIOR", 60, "Warrior")

local NS = {}
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

-- ---------------------------------------------------------------------------
-- Case 1: fresh install (no DingTimerDB) → settingsWindowPosition defaults to nil
-- ---------------------------------------------------------------------------

DingTimerDB = nil
NS.InitStore()

assert_true(DingTimerDB ~= nil, "DingTimerDB should be created on fresh install")
assert_true(DingTimerDB.settingsWindowPosition == nil,
  "settingsWindowPosition should default to nil on fresh install")
print("  [PASS] fresh install: settingsWindowPosition defaults to nil")

-- ---------------------------------------------------------------------------
-- Case 2: existing DB at schemaVersion 5 without the key
--         (simulate a DB written before this field was added)
-- ---------------------------------------------------------------------------

DingTimerDB = {
  schemaVersion = 5,
  enabled = true,
  windowSeconds = 600,
  graphVisible = false,
  graphWindowSeconds = 300,
  graphScaleMode = "fixed",
  graphFixedMaxXPH = 100000,
  graphLocked = true,
  insightsWindowVisible = false,
  insightsWindowPosition = nil,
  -- settingsWindowPosition intentionally absent
  meta = { addonVersion = "0.3.0", createdAt = 0, lastSeenAt = 0 },
  xp = { keepSessions = 30, profiles = {} },
}

NS.InitStore()

assert_true(DingTimerDB.settingsWindowPosition == nil,
  "missing settingsWindowPosition should default to nil after InitStore")
assert_eq(DingTimerDB.schemaVersion, 5, "schemaVersion should stay at 5")
assert_eq(DingTimerDB.enabled, true, "existing settings should be preserved")
print("  [PASS] v5 DB without settingsWindowPosition gets nil default")

-- ---------------------------------------------------------------------------
-- Case 3: existing DB that already has settingsWindowPosition set
--         (simulate a user who has moved the window)
-- ---------------------------------------------------------------------------

DingTimerDB = {
  schemaVersion = 5,
  enabled = true,
  windowSeconds = 600,
  graphVisible = false,
  graphWindowSeconds = 300,
  graphScaleMode = "fixed",
  graphFixedMaxXPH = 100000,
  graphLocked = true,
  insightsWindowVisible = false,
  insightsWindowPosition = nil,
  settingsWindowPosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", xOfs = 120, yOfs = -80 },
  meta = { addonVersion = "0.4.0", createdAt = 0, lastSeenAt = 0 },
  xp = { keepSessions = 30, profiles = {} },
}

NS.InitStore()

assert_true(DingTimerDB.settingsWindowPosition ~= nil,
  "existing settingsWindowPosition should be preserved")
assert_eq(DingTimerDB.settingsWindowPosition.xOfs, 120, "xOfs should be preserved")
assert_eq(DingTimerDB.settingsWindowPosition.yOfs, -80, "yOfs should be preserved")
print("  [PASS] existing settingsWindowPosition is preserved across InitStore")

print("\nStore settingsWindowPosition tests passed!")
