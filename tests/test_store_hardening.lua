dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)

it("initializes fresh SavedVariables with the active HUD defaults", function()
  DingTimerDB = nil
  SetTime(42)

  NS.InitStore()

  assert_true(type(DingTimerDB) == "table", "InitStore should create a SavedVariables table")
  assert_true(DingTimerDB.enabled, "chat output should default to enabled")
  assert_true(DingTimerDB.float, "HUD should default to visible")
  assert_true(DingTimerDB.floatLocked, "HUD should default to locked")
  assert_false(DingTimerDB.floatShowInCombat, "combat visibility should default to off")
  assert_eq(600, DingTimerDB.windowSeconds, "rolling window should default to 10 minutes")
  assert_eq("full", DingTimerDB.mode, "chat output mode should default to full")
  assert_eq(10, DingTimerDB.schemaVersion, "fresh stores should use the current schema")
  assert_eq(42, DingTimerDB.meta.createdAt, "fresh metadata should record creation time")
  assert_eq(42, DingTimerDB.meta.lastSeenAt, "fresh metadata should record last seen time")
end)

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
  assert_true(type(DingTimerDB.meta) == "table", "corrupted addon metadata should be repaired")
  assert_eq("1.1.2", DingTimerDB.meta["addonVersion"], "stored addon metadata should match the current release version")
end)

it("re-applies schema v10 cleanup idempotently without losing preserved legacy history", function()
  DingTimerDB = {
    schemaVersion = 10,
    enabled = true,
    float = true,
    windowSeconds = 600,
    mode = "full",
    graphVisible = true,
    mainWindowVisible = true,
    xp = {
      profiles = {
        default = {
          sessions = {
            { id = "xp-keep" },
          },
        },
      },
    },
    pvp = {
      profiles = {
        default = {
          sessions = {
            { id = "pvp-keep" },
          },
        },
      },
    },
    coach = {
      lastRecap = {
        headline = "Keep recap",
      },
    },
    meta = {
      createdAt = 12,
    },
  }

  SetTime(25)
  NS.InitStore()
  NS.InitStore()

  assert_eq(10, DingTimerDB.schemaVersion, "schema should remain at v10 after repeated init")
  assert_eq(nil, DingTimerDB.graphVisible, "dead graph state should stay cleared")
  assert_eq(nil, DingTimerDB.mainWindowVisible, "dead main-window state should stay cleared")
  assert_eq("xp-keep", DingTimerDB.xp.profiles.default.sessions[1].id, "legacy XP history should be preserved")
  assert_eq("pvp-keep", DingTimerDB.pvp.profiles.default.sessions[1].id, "legacy PvP history should be preserved")
  assert_eq("Keep recap", DingTimerDB.coach.lastRecap.headline, "legacy coach recap should be preserved")
  assert_eq(12, DingTimerDB.meta.createdAt, "createdAt should not be overwritten on repeated init")
  assert_eq(25, DingTimerDB.meta.lastSeenAt, "lastSeenAt should be refreshed on repeated init")
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
