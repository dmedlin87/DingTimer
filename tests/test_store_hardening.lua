dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)

it("sanitizes corrupted numeric SavedVariables during store init", function()
  DingTimerDB = {
    windowSeconds = "abc",
    minXPDeltaToPrint = true,
    graphWindowSeconds = "not-a-number",
    graphScaleMode = "fixed",
    graphFixedMaxXPH = "20000",
    mode = "weird",
    meta = {},
  }

  local ok, err = pcall(function()
    NS.InitStore()
  end)

  assert_true(ok, "InitStore should not crash on corrupted numeric settings: " .. tostring(err))
  assert_eq(600, DingTimerDB.windowSeconds, "windowSeconds should fall back to the default")
  assert_eq(1, DingTimerDB.minXPDeltaToPrint, "minXPDeltaToPrint should fall back to the minimum safe value")
  assert_eq(300, DingTimerDB.graphWindowSeconds, "graphWindowSeconds should fall back to the default zoom")
  assert_eq(DingTimerDB.graphScaleMode, "fixed", "valid fixed graph scaling should survive store sanitization")
  assert_eq(20000, DingTimerDB.graphFixedMaxXPH, "graphFixedMaxXPH should be coerced from string input")
  assert_eq("full", DingTimerDB.mode, "invalid output modes should normalize to full")
  assert_eq("1.1.2", DingTimerDB.meta.addonVersion, "stored addon metadata should match the current release version")
end)

it("protects runtime consumers from sanitized chat print thresholds", function()
  DingTimerDB = {
    enabled = true,
    windowSeconds = 600,
    minXPDeltaToPrint = "abc",
  }

  NS.InitStore()
  NS.resetXPState()
  SetTime(10)
  SetXP(100, 1000)

  local ok, err = pcall(function()
    NS.onXPUpdate()
  end)

  assert_true(ok, "XP updates should not crash after sanitizing minXPDeltaToPrint: " .. tostring(err))
  assert_eq(100, NS.state.sessionXP, "XP updates should still record session gains")
end)

it("sanitizes graph zoom settings before graph math consumes them", function()
  DingTimerDB = {
    graphWindowSeconds = true,
  }

  NS.InitStore()

  local ok, err = pcall(function()
    local bars = NS.ComputeBarCount(DingTimerDB.graphWindowSeconds, 15, 10, 60)
    assert_eq(20, bars, "default 5m zoom should still compute the expected bar count")
  end)

  assert_true(ok, "graph math should not crash on sanitized zoom settings: " .. tostring(err))
  assert_eq(300, DingTimerDB.graphWindowSeconds, "invalid graph zoom settings should normalize to the default")
end)

it("recomputes stored historical rates from actual durations and clears invalid custom PvP goals", function()
  DingTimerDB = {
    schemaVersion = 9,
    xp = {
      activeProfile = "default",
      profiles = {
        default = {
          sessions = {
            {
              durationSec = 100,
              xpGained = 2500,
              moneyNetCopper = 500,
              avgXph = 5000,
              avgMoneyPh = 2000,
            },
          },
        },
      },
    },
    pvp = {
      activeProfile = "default",
      settings = {
        goalMode = "custom",
        customGoalHonor = 0.5,
      },
      profiles = {
        default = {
          sessions = {
            {
              durationSec = 20,
              honorGained = 200,
              hkGained = 3,
              avgHonorPerHour = 400,
              avgHKPerHour = 10,
            },
          },
        },
      },
    },
  }

  NS.InitStore()

  local profileKey = nil
  for key, profile in pairs(DingTimerDB.xp.profiles) do
    if profile.sessions and #profile.sessions > 0 then
      profileKey = key
      break
    end
  end
  assert_true(profileKey ~= nil, "the fixture should preserve one populated XP profile after store init")

  local xpSession = DingTimerDB.xp.profiles[profileKey].sessions[1]
  assert_near((2500 / 100) * 3600, xpSession.avgXph, 0.01, "xp history should be recomputed from the recorded duration")
  assert_near((500 / 100) * 3600, xpSession.avgMoneyPh, 0.01, "money history should be recomputed from the recorded duration")

  local pvpSession = DingTimerDB.pvp.profiles[profileKey].sessions[1]
  assert_near((200 / 20) * 3600, pvpSession.avgHonorPerHour, 0.01, "honor history should be recomputed from the recorded duration")
  assert_near((3 / 20) * 3600, pvpSession.avgHKPerHour, 0.01, "HK history should be recomputed from the recorded duration")
  assert_eq("cap", DingTimerDB.pvp.settings.goalMode, "invalid custom goals should fall back to the default goal mode")
  assert_eq(nil, DingTimerDB.pvp.settings.customGoalHonor, "invalid custom goals should be cleared during store init")
end)

run_tests()
