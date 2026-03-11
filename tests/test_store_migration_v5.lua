dofile("tests/mocks.lua")

SetProfileIdentity("Hero", "Azeroth", "HUNTER", 70, "Hunter")

local NS = {}
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

DingTimerDB = {
  enabled = false,
  windowSeconds = 900,
  schemaVersion = 4,
  graphScaleMode = "fixed",
  graphFixedMaxXPH = 100000,
  settingsWindowPosition = {
    point = "TOPLEFT",
    relativePoint = "TOPLEFT",
    xOfs = 12,
    yOfs = -34,
  },
  xp = {
    keepSessions = 12,
    sessions = {
      { id = "legacy-1", avgXph = 22222 }
    },
  },
}

NS.InitStore()

local key = NS.GetProfileKey()
local profile = DingTimerDB.xp.profiles[key]

assert_eq(DingTimerDB.schemaVersion, 6, "schemaVersion should migrate to 6")
assert_eq(DingTimerDB.enabled, false, "existing settings should be preserved")
assert_eq(DingTimerDB.xp.keepSessions, 12, "keepSessions should be preserved")
assert_true(DingTimerDB.xp.sessions == nil, "legacy xp.sessions should be removed")
assert_true(profile ~= nil, "profile should exist for current character")
assert_eq(#profile.sessions, 1, "legacy sessions should migrate into profile")
assert_eq(profile.sessions[1].id, "legacy-1", "legacy session payload should be preserved")
assert_eq(DingTimerDB.insightsWindowVisible, false, "insights visibility default should exist")
assert_true(DingTimerDB.settingsWindowPosition ~= nil, "settings window position should be preserved")
assert_eq(DingTimerDB.settingsWindowPosition.xOfs, 12, "settings window position payload should survive init")
assert_eq(DingTimerDB.graphScaleMode, "visible", "legacy fixed default should migrate to visible scale")
assert_true(DingTimerDB.graphWindowSize ~= nil, "graph window size should be created")
assert_true(DingTimerDB.graphWindowSize.width >= 540, "graph window width should be clamped to the new minimum")

print("Store v6 migration test passed!")
