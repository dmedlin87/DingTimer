dofile("tests/mocks.lua")

SetProfileIdentity("Hero", "Azeroth", "HUNTER", 70, "Hunter")

local NS = {}
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

DingTimerDB = {
  enabled = false,
  windowSeconds = 900,
  schemaVersion = 4,
  graphVisible = true,
  graphLocked = false,
  graphWindowSize = {
    width = 400,
    height = 200,
  },
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

assert_eq(DingTimerDB.schemaVersion, 9, "schemaVersion should migrate to 9")
assert_eq(DingTimerDB.enabled, false, "existing settings should be preserved")
assert_eq(DingTimerDB.xp.keepSessions, 12, "keepSessions should be preserved")
assert_true(DingTimerDB.xp.sessions == nil, "legacy xp.sessions should be removed")
assert_true(profile ~= nil, "profile should exist for current character")
assert_eq(#profile.sessions, 1, "legacy sessions should migrate into profile")
assert_eq(profile.sessions[1].id, "legacy-1", "legacy session payload should be preserved")
assert_eq(DingTimerDB.insightsWindowVisible, false, "insights visibility default should exist")
assert_true(DingTimerDB.settingsWindowPosition == nil, "obsolete settings window position should be removed")
assert_eq(DingTimerDB.graphScaleMode, "visible", "legacy fixed default should migrate to visible scale")
assert_true(DingTimerDB.graphWindowSize == nil, "obsolete graph window size should be removed")
assert_true(DingTimerDB.graphVisible == nil, "obsolete graph visibility flag should be removed")
assert_true(DingTimerDB.graphLocked == nil, "obsolete graph lock flag should be removed")
assert_eq(DingTimerDB.mainWindowVisible, false, "main window visibility default should exist")
assert_eq(DingTimerDB.lastOpenTab, 1, "main window tab default should exist")
assert_eq(DingTimerDB.coach.goal, "ding", "coach goal should default during migration")
assert_eq(DingTimerDB.coach.idleSeconds, 90, "coach idle threshold should default during migration")
assert_true(DingTimerDB.pvp ~= nil, "pvp namespace should be created during migration")
assert_eq(DingTimerDB.pvp.settings.goalMode, "cap", "pvp goal mode should default during migration")

print("Store v7 migration test passed!")
