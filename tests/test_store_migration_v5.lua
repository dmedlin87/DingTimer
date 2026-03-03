dofile("tests/mocks.lua")

SetProfileIdentity("Hero", "Azeroth", "HUNTER", 70, "Hunter")

local NS = {}
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

DingTimerDB = {
  enabled = false,
  windowSeconds = 900,
  schemaVersion = 4,
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

assert_eq(DingTimerDB.schemaVersion, 5, "schemaVersion should migrate to 5")
assert_eq(DingTimerDB.enabled, false, "existing settings should be preserved")
assert_eq(DingTimerDB.xp.keepSessions, 12, "keepSessions should be preserved")
assert_true(DingTimerDB.xp.sessions == nil, "legacy xp.sessions should be removed")
assert_true(profile ~= nil, "profile should exist for current character")
assert_eq(#profile.sessions, 1, "legacy sessions should migrate into profile")
assert_eq(profile.sessions[1].id, "legacy-1", "legacy session payload should be preserved")
assert_eq(DingTimerDB.insightsWindowVisible, false, "insights visibility default should exist")

print("Store v5 migration test passed!")
