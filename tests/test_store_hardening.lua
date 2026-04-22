dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

it("sanitizes corrupted SavedVariables during store init and drops dead surface state", function()
  DingTimerDB = {
    windowSeconds = "abc",
    minXPDeltaToPrint = true,
    mode = "weird",
    mainWindowVisible = true,
    lastOpenTab = 4,
    graphWindowSeconds = "not-a-number",
    graphScaleMode = "fixed",
    graphFixedMaxXPH = "20000",
    minimapHidden = true,
    meta = "corrupt",
  }

  local ok, err = pcall(function()
    NS.InitStore()
  end)

  assert_true(ok, "InitStore should not crash on corrupted numeric settings: " .. tostring(err))
  assert_eq(600, DingTimerDB.windowSeconds, "windowSeconds should fall back to the default")
  assert_eq(1, DingTimerDB.minXPDeltaToPrint, "minXPDeltaToPrint should fall back to the minimum safe value")
  assert_eq("full", DingTimerDB.mode, "invalid output modes should normalize to full")
  assert_eq(nil, DingTimerDB.mainWindowVisible, "legacy main-window state should be removed")
  assert_eq(nil, DingTimerDB.lastOpenTab, "legacy tab state should be removed")
  assert_eq(nil, DingTimerDB.graphWindowSeconds, "legacy graph state should be removed")
  assert_eq(nil, DingTimerDB.graphScaleMode, "legacy graph scale state should be removed")
  assert_eq(nil, DingTimerDB.graphFixedMaxXPH, "legacy graph cap state should be removed")
  assert_eq(nil, DingTimerDB.minimapHidden, "legacy minimap state should be removed")
  assert_eq(10, DingTimerDB.schemaVersion, "schemaVersion should advance to v10")
  assert_eq("1.1.2", DingTimerDB.meta.addonVersion, "stored addon metadata should match the current release version")
end)

it("drops invalid persisted HUD positions before HUD startup", function()
  DingTimerDB = {
    float = true,
    floatPosition = {
      point = nil,
      relativePoint = "CENTER",
      xOfs = 10,
      yOfs = 20,
    },
    meta = {},
  }

  NS.InitStore()
  assert_eq(nil, DingTimerDB.floatPosition, "invalid HUD anchor data should be discarded")

  local ok, err = pcall(function()
    NS.ensureFloat()
  end)
  assert_true(ok, "HUD startup should not crash after discarding invalid position data: " .. tostring(err))
end)

it("preserves valid persisted HUD positions with numeric offsets", function()
  DingTimerDB = {
    float = true,
    floatPosition = {
      point = "TOPLEFT",
      relativePoint = "BOTTOMRIGHT",
      xOfs = "15",
      yOfs = -25.5,
    },
    meta = {},
  }

  NS.InitStore()

  assert_true(DingTimerDB.floatPosition ~= nil, "valid HUD position should be preserved")
  assert_eq("TOPLEFT", DingTimerDB.floatPosition.point, "valid point should be preserved")
  assert_eq("BOTTOMRIGHT", DingTimerDB.floatPosition.relativePoint, "valid relative point should be preserved")
  assert_eq(15, DingTimerDB.floatPosition.xOfs, "string numeric x offset should normalize to a number")
  assert_eq(-25.5, DingTimerDB.floatPosition.yOfs, "numeric y offset should be preserved")
end)

it("protects runtime consumers from sanitized chat print thresholds", function()
  DingTimerDB = {
    enabled = true,
    windowSeconds = 600,
    minXPDeltaToPrint = "abc",
    float = false,
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

run_tests()
