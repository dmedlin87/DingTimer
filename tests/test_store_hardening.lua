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

run_tests()
