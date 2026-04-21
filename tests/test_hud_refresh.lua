dofile("tests/mocks.lua")

---@class TestFontRegion
---@field GetText fun(self: TestFontRegion): string

---@class TestHeartbeatTicker
---@field interval number
---@field callback fun()?
---@field cancelled boolean
---@field Cancel fun(self: TestHeartbeatTicker)
---@field Fire fun(self: TestHeartbeatTicker)

---@class TestHUDFrame
---@field titleText TestFontRegion
---@field subText TestFontRegion

---@type TestHUDFrame?
local capturedFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not capturedFrame then
    ---@cast frame TestHUDFrame
    capturedFrame = frame
  end
  return frame
end

---@type TestHeartbeatTicker?
local heartbeatTicker = nil
---@diagnostic disable-next-line: duplicate-set-field
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

local ticker = heartbeatTicker
assert_true(heartbeatTicker ~= nil, "heartbeat ticker should start")
---@cast ticker TestHeartbeatTicker
assert_eq(ticker.interval, 1, "heartbeat ticker should tick every second")

SetTime(60)
SetXP(100, 1000)
NS.onXPUpdate()

local frame = capturedFrame
assert_true(capturedFrame ~= nil, "floating HUD frame should be created")
---@cast frame TestHUDFrame
assert_eq("9m 0s to level", frame.titleText:GetText(), "HUD should show only TTL text on the top line")
assertStringMatch("6,000 XP/hr", frame.subText:GetText(), "HUD should show the rolling XP/hr immediately after a gain")
assertStringMatch("Last +", frame.subText:GetText(), "HUD should show the most recent XP gain on the second line")
assertStringMatch("Last +100 (9)", frame.subText:GetText(), "HUD should show the most recent XP gain and gains remaining estimate on the second line")
assertStringMatch("Need 900", frame.subText:GetText(), "HUD should show the remaining XP needed to level")
assert_true(string.find(frame.titleText:GetText(), "DingTimer", 1, true) == nil, "HUD title should not include the addon name")

SetTime(121)
ticker:Fire()

assert_eq(0, #NS.state.events, "heartbeat refresh should prune expired XP events")
assert_eq(0, NS.state.windowXP, "window XP should decay when the rolling window expires")
assertStringMatch("No XP in 60s", frame.subText:GetText(), "HUD should show when the rolling window is empty")
assertStringMatch("Last +100 (9)", frame.subText:GetText(), "HUD should keep the last gain and gains remaining estimate visible after the rolling window expires")
assertStringMatch("Need 900", frame.subText:GetText(), "HUD should keep the remaining XP needed visible after the rolling window expires")
assert_eq("?? to level", frame.titleText:GetText(), "HUD should fall back to TTL-only text when no pace is available")

print("HUD rolling refresh test passed!")
