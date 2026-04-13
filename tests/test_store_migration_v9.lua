dofile("tests/mocks.lua")

SetProfileIdentity("Migrator", "Azeroth", "PALADIN", 80, "Paladin")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

DingTimerDB = {
  schemaVersion = 8,
  enabled = true,
  windowSeconds = 600,
  minXPDeltaToPrint = 1,
  mode = "full",
  float = false,
  floatLocked = true,
  floatShowInCombat = false,
  graphWindowSeconds = 300,
  graphScaleMode = "visible",
  graphFixedMaxXPH = 100000,
  insightsWindowVisible = false,
  minimapHidden = false,
  mainWindowVisible = false,
  lastOpenTab = 1,
  coach = { goal = "ding" },
  xp = {
    keepSessions = 30,
    profiles = {
      ["Azeroth:Migrator:PALADIN"] = {
        sessions = {
          {
            id = "legacy",
            durationSec = 60,
            avgXph = 1000,
            xpGained = 100,
            segments = {},
          },
        },
      },
    },
  },
}

NS.InitStore()

assert_eq(9, DingTimerDB.schemaVersion, "schema should migrate to v9")
assert_eq("xp", DingTimerDB.activeMode, "active mode should default to xp after migration")
assert_true(DingTimerDB.pvp ~= nil, "pvp namespace should be created")
assert_true(DingTimerDB.pvp.settings ~= nil, "pvp settings should be initialized")
assert_eq(false, DingTimerDB.pvp.settings.autoSwitchBattlegrounds, "battleground auto-switch should default off")
assert_eq("cap", DingTimerDB.pvp.settings.goalMode, "goal mode should default to cap")
assert_eq(15000, DingTimerDB.pvp.settings.honorCap, "honor cap should default to the retail value")
assert_eq(30, DingTimerDB.pvp.settings.keepSessions, "pvp history retention should default to 30")
assert_true(DingTimerDB.pvp.profiles["Azeroth:Migrator:PALADIN"] ~= nil, "pvp profile bucket should exist for current character")
assert_eq(1, #DingTimerDB.xp.profiles["Azeroth:Migrator:PALADIN"].sessions, "existing xp history should remain intact")

print("Store v9 migration tests passed!")
