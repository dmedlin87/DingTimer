dofile("tests/mocks.lua")

local capturedFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name then
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

local NS = {
  C = { base = "", r = "" },
  ApplyThemeToFrame = function() end,
  FormatNumber = function(n) return tostring(n) end,
  Round = function(n) return math.floor(n + 0.5) end,
  fmtTime = function(seconds)
    if seconds == 60 then
      return "1m"
    end
    if seconds == math.huge then
      return "inf"
    end
    return tostring(math.floor(seconds + 0.5)) .. "s"
  end,
  ttlColor = function() return "" end,
  ttlDeltaText = function() return "" end,
  chat = function() end,
}

DingTimerDB = {
  enabled = false,
  float = true,
  floatLocked = true,
  windowSeconds = 60,
  coach = {
    goal = "ding",
  },
}



LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

SetTime(0)
SetXP(0, 1000)
NS.resetXPState()
NS.StartCoachTicker()

assert_true(heartbeatTicker ~= nil, "coach ticker should start")
assert_eq(heartbeatTicker.interval, 1, "coach ticker should tick every second")

SetTime(60)
SetXP(100, 1000)
NS.onXPUpdate()

assert_true(capturedFrame ~= nil, "floating HUD frame should be created")
assertStringMatch("6,000 XP/hr", capturedFrame.subText:GetText(), "HUD should show the rolling XP/hr immediately after a gain")
assert_eq(100, NS.state.windowXP, "window XP should include the fresh gain")
assert_true(string.find(capturedFrame.subText:GetText(), "Session 6,000", 1, true) ~= nil, "HUD should show session average")
assert_true(string.find(capturedFrame.subText:GetText(), "High 6,000", 1, true) == nil, "HUD should not duplicate session average as the goal benchmark")

SetTime(121)
heartbeatTicker:Fire()

assert_eq(0, #NS.state.events, "heartbeat refresh should prune expired XP events")
assert_eq(0, NS.state.windowXP, "window XP should decay when the rolling window expires")
assertStringMatch("No XP in 60s", capturedFrame.subText:GetText(), "HUD should show when the rolling window is empty")
assert_true(string.find(capturedFrame.subText:GetText(), "6,000 XP/hr", 1, true) == nil, "HUD should stop showing stale rolling XP/hr")

print("HUD rolling refresh test passed!")
