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
---@field progressBar table
---@field progressFill table
---@field progressPulse table
---@field progressSpark table

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

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)

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
NS.setFloatVisible(true)

local ticker = C_Timer._lastTicker
assert_true(ticker ~= nil, "heartbeat ticker should start")
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
assert_true(frame.progressBar ~= nil, "HUD should create an internal XP progress bar")
local barPoint, barRelativeTo, barRelativePoint, _, barYOffset = frame.progressBar:GetPoint()
assert_eq("BOTTOM", barPoint, "HUD XP bar should sit below the detail label")
assert_eq(frame, barRelativeTo, "HUD XP bar should anchor to the HUD frame")
assert_eq("BOTTOM", barRelativePoint, "HUD XP bar should stay at the bottom of the HUD")
assert_eq(11, barYOffset, "HUD XP bar should leave room for the bottom border")
local subPoint, subRelativeTo, subRelativePoint = frame.subText:GetPoint()
assert_eq("BOTTOM", subPoint, "HUD detail label should sit above the XP bar")
assert_eq(frame.progressBar, subRelativeTo, "HUD detail label should anchor to the XP bar")
assert_eq("TOP", subRelativePoint, "HUD detail label should stay above the XP bar")
assert_false(frame._dingGlow and frame._dingGlow:IsShown(), "HUD should hide the shared top glow behind the TTL label")
assert_false(frame._dingAccent and frame._dingAccent:IsShown(), "HUD should hide the shared top accent behind the TTL label")
assert_true(frame.progressPulse ~= nil, "HUD should create a gain pulse texture")
assert_true(frame.progressSpark ~= nil, "HUD should create a gain spark texture")
assert_true(frame:GetScript("OnUpdate") ~= nil, "HUD should animate when XP is gained")

local onUpdate = frame:GetScript("OnUpdate")
---@cast onUpdate fun(self: TestHUDFrame, elapsed: number)
onUpdate(frame, 0.3)

local expectedFillWidth = math.floor((frame.progressBar:GetWidth() * 0.1) + 0.5)
if expectedFillWidth < 2 then
  expectedFillWidth = 2
end

assert_eq(expectedFillWidth, frame.progressFill:GetWidth(), "HUD XP bar should reflect the current level progress")
assert_true(frame.progressPulse:IsShown(), "HUD should show a pulse texture after gaining XP")
assert_true(frame.progressPulse:GetAlpha() > 0, "HUD pulse should fade instead of remaining static")
assert_true(frame.progressSpark:IsShown(), "HUD should show a spark at the leading edge while the gain pulse is active")

onUpdate(frame, 1)
assert_true(frame:GetScript("OnUpdate") == nil, "HUD should stop animating once the pulse finishes")
assert_false(frame.progressPulse:IsShown(), "HUD pulse should hide after the animation completes")

SetTime(121)
ticker:Fire()

assert_eq(0, #NS.state.events, "heartbeat refresh should prune expired XP events")
assert_eq(0, NS.state.windowXP, "window XP should decay when the rolling window expires")
assertStringMatch("No XP in 60s", frame.subText:GetText(), "HUD should show when the rolling window is empty")
assertStringMatch("Last +100 (9)", frame.subText:GetText(), "HUD should keep the last gain and gains remaining estimate visible after the rolling window expires")
assertStringMatch("Need 900", frame.subText:GetText(), "HUD should keep the remaining XP needed visible after the rolling window expires")
assert_eq("?? to level", frame.titleText:GetText(), "HUD should fall back to TTL-only text when no pace is available")
assert_eq(expectedFillWidth, frame.progressFill:GetWidth(), "HUD XP bar should keep the player's actual level progress after the rolling window expires")

SetTime(200)
SetXP(100000000, 1000000000)
NS.resetXPState()
SetTime(210)
SetXP(200000000, 1000000000)
NS.onXPUpdate()

assertStringMatch("36.0B XP/hr", frame.subText:GetText(), "HUD should compact very large XP/hr values")
assertStringMatch("Last +100.0M (8)", frame.subText:GetText(), "HUD should compact very large last-gain text")
assertStringMatch("Need 800.0M", frame.subText:GetText(), "HUD should compact very large remaining-XP text")

print("HUD rolling refresh test passed!")
