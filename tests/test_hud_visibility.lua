dofile("tests/mocks.lua")

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
local floatFrame = NS.GetFloatFrame()
assert_true(floatFrame ~= nil, "HUD should create a floating frame when shown")
assert_true(floatFrame:IsShown(), "HUD should show out of combat by default")

DingTimerDB.floatShowInCombat = true
NS.setFloatVisible(true)
assert_true(floatFrame:IsShown(), "HUD should stay visible when combat visibility is enabled")

local baseInCombatLockdown = InCombatLockdown
InCombatLockdown = function()
  return true
end

DingTimerDB.floatShowInCombat = false
NS.setFloatVisible(true)
assert_false(floatFrame:IsShown(), "HUD should hide in combat when combat visibility is disabled")

DingTimerDB.floatShowInCombat = true
NS.setFloatVisible(true)
assert_true(floatFrame:IsShown(), "HUD should show in combat when combat visibility is enabled")

InCombatLockdown = baseInCombatLockdown

print("HUD visibility toggle test passed!")
