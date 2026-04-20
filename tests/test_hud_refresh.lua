dofile("tests/mocks.lua")

local capturedFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not capturedFrame then
    capturedFrame = frame
  end
  return frame
end

local heartbeatTicker = nil
C_Timer.NewTicker = function(interval, callback)
  heartbeatTicker = {
    interval = interval,
    callback = callback,
    cancelled = false,
  }

  function heartbeatTicker:Cancel()
    self.cancelled = true
  end

  function heartbeatTicker:Fire()
    if not self.cancelled and self.callback then
      self.callback()
    end
  end

  return heartbeatTicker
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

DingTimerDB = {
  enabled = false,
  float = true,
  floatLocked = true,
  windowSeconds = 60,
  mode = "full",
}

NS.InitStore()
SetTime(0)
SetXP(0, 1000)
NS.resetXPState()
NS.StartHeartbeatTicker()

assert_true(heartbeatTicker ~= nil, "heartbeat ticker should start")
assert_eq(heartbeatTicker.interval, 1, "heartbeat ticker should tick every second")

SetTime(60)
SetXP(100, 1000)
NS.onXPUpdate()

assert_true(capturedFrame ~= nil, "floating HUD frame should be created")
assert_eq("9m 0s to level", capturedFrame.titleText:GetText(), "HUD should show only TTL text on the top line")
assertStringMatch("6,000 XP/hr", capturedFrame.subText:GetText(), "HUD should show the rolling XP/hr immediately after a gain")
assertStringMatch("Last +", capturedFrame.subText:GetText(), "HUD should show the most recent XP gain on the second line")
assertStringMatch("Last +100", capturedFrame.subText:GetText(), "HUD should show the exact most recent XP gain on the second line")
assertStringMatch("Need 900", capturedFrame.subText:GetText(), "HUD should show the remaining XP needed to level")
assert_true(string.find(capturedFrame.titleText:GetText(), "DingTimer", 1, true) == nil, "HUD title should not include the addon name")

SetTime(121)
heartbeatTicker:Fire()

assert_eq(0, #NS.state.events, "heartbeat refresh should prune expired XP events")
assert_eq(0, NS.state.windowXP, "window XP should decay when the rolling window expires")
assertStringMatch("No XP in 60s", capturedFrame.subText:GetText(), "HUD should show when the rolling window is empty")
assertStringMatch("Last +100", capturedFrame.subText:GetText(), "HUD should keep the last gain visible after the rolling window expires")
assertStringMatch("Need 900", capturedFrame.subText:GetText(), "HUD should keep the remaining XP needed visible after the rolling window expires")
assert_eq("?? to level", capturedFrame.titleText:GetText(), "HUD should fall back to TTL-only text when no pace is available")

print("HUD rolling refresh test passed!")
