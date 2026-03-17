dofile("tests/mocks.lua")

local registeredDriver = nil
RegisterStateDriver = function(frame, state, value)
  registeredDriver = {
    frame = frame,
    state = state,
    value = value,
  }
end

local NS = {
  C = { base = "", r = "" },
  ApplyThemeToFrame = function() end,
  fmtTime = function(seconds)
    return tostring(seconds)
  end,
  FormatNumber = function(n)
    return tostring(n)
  end,
  Round = function(n)
    return math.floor((n or 0) + 0.5)
  end,
  GetSessionSnapshot = function()
    return {
      ttl = 1,
      currentXph = 0,
      rollingWindow = 60,
      sessionXph = 0,
    }
  end,
  GetCoachStatus = function()
    return nil
  end,
}

DingTimerDB = {
  float = true,
  floatLocked = true,
  floatShowInCombat = false,
}

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

NS.setFloatVisible(true)
assert_eq(registeredDriver.state, "visibility", "HUD should register the visibility state driver")
assert_eq(registeredDriver.value, "[combat] hide; show", "HUD should hide during combat by default")

DingTimerDB.floatShowInCombat = true
NS.setFloatVisible(true)
assert_eq(registeredDriver.value, "show", "HUD should stay visible during combat when enabled")

print("HUD visibility toggle test passed!")
