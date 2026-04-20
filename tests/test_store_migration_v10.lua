dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

it("migrates legacy surface state to schema v10 while preserving HUD settings and old history data", function()
  DingTimerDB = {
    schemaVersion = 9,
    enabled = false,
    float = true,
    floatLocked = false,
    floatShowInCombat = true,
    floatPosition = {
      point = "TOP",
      relativePoint = "TOP",
      xOfs = 12,
      yOfs = -34,
    },
    windowSeconds = "300",
    mode = "ttl",
    mainWindowVisible = true,
    mainWindowPosition = { point = "CENTER" },
    mainWindowSize = { width = 900, height = 600 },
    lastOpenTab = 4,
    minimapHidden = true,
    minimapAngle = 42,
    graphWindowSeconds = 300,
    graphScaleMode = "fixed",
    graphFixedMaxXPH = 20000,
    xp = {
      profiles = {
        default = {
          sessions = {
            { id = "xp-1" },
          },
        },
      },
    },
    pvp = {
      profiles = {
        default = {
          sessions = {
            { id = "pvp-1" },
          },
        },
      },
    },
    coach = {
      lastRecap = {
        headline = "Old recap",
      },
    },
    meta = {
      createdAt = 12,
    },
  }

  NS.InitStore()

  assert_eq(10, DingTimerDB.schemaVersion, "schema should migrate to v10")
  assert_false(DingTimerDB.enabled, "existing chat setting should be preserved")
  assert_true(DingTimerDB.float, "HUD visibility should be preserved")
  assert_false(DingTimerDB.floatLocked, "HUD lock state should be preserved")
  assert_true(DingTimerDB.floatShowInCombat, "combat visibility should be preserved")
  assert_eq(300, DingTimerDB.windowSeconds, "rolling window should be normalized and preserved")
  assert_eq("ttl", DingTimerDB.mode, "chat mode should be preserved")
  assert_eq("TOP", DingTimerDB.floatPosition.point, "HUD position should be preserved")

  assert_eq(nil, DingTimerDB.mainWindowVisible, "legacy main-window visibility should be removed")
  assert_eq(nil, DingTimerDB.mainWindowPosition, "legacy main-window position should be removed")
  assert_eq(nil, DingTimerDB.mainWindowSize, "legacy main-window size should be removed")
  assert_eq(nil, DingTimerDB.lastOpenTab, "legacy tab selection should be removed")
  assert_eq(nil, DingTimerDB.minimapHidden, "legacy minimap state should be removed")
  assert_eq(nil, DingTimerDB.minimapAngle, "legacy minimap angle should be removed")
  assert_eq(nil, DingTimerDB.graphWindowSeconds, "legacy graph zoom should be removed")
  assert_eq(nil, DingTimerDB.graphScaleMode, "legacy graph scale should be removed")
  assert_eq(nil, DingTimerDB.graphFixedMaxXPH, "legacy graph cap should be removed")

  assert_eq("xp-1", DingTimerDB.xp.profiles.default.sessions[1].id, "legacy XP history should be preserved for rollback safety")
  assert_eq("pvp-1", DingTimerDB.pvp.profiles.default.sessions[1].id, "legacy PvP history should be preserved for rollback safety")
  assert_eq("Old recap", DingTimerDB.coach.lastRecap.headline, "legacy coach data should be preserved for rollback safety")
  assert_eq(12, DingTimerDB.meta.createdAt, "existing metadata should be preserved")
  assert_eq("1.1.2", DingTimerDB.meta.addonVersion, "addon version metadata should be refreshed")
end)

run_tests()
