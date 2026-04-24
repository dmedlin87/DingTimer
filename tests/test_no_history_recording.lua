dofile("tests/mocks.lua")

---@class TestEventFrame
---@field GetScript fun(self: TestEventFrame, scriptName: string): function?

---@type TestEventFrame?
local eventFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not eventFrame then
    ---@cast frame TestEventFrame
    eventFrame = frame
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/HUDText.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

CreateFrame = baseCreateFrame

DingTimerDB = {
  enabled = false,
  float = false,
  floatLocked = true,
  floatShowInCombat = false,
  windowSeconds = 600,
  mode = "full",
}

NS.InitStore()
NS.resetXPState()

local recordCalls = 0
NS.RecordSession = function()
  recordCalls = recordCalls + 1
end

it("reset remains a pure runtime reset without writing history", function()
  SetTime(10)
  SetXP(100, 1000)
  NS.onXPUpdate()

  NS.ResetSession("MANUAL_RESET")

  assert_eq(0, recordCalls, "runtime reset should not write history")
  assert_eq(0, NS.state.sessionXP, "runtime reset should clear session XP")
  assert_eq(0, #NS.state.events, "runtime reset should clear rolling XP events")
end)

it("level-up no longer appends history records", function()
  local frame = eventFrame
  assert_true(eventFrame ~= nil, "event frame should be created")
  ---@cast frame TestEventFrame

  local onEvent = frame:GetScript("OnEvent")
  assert_true(onEvent ~= nil, "event frame should register an OnEvent handler")
  SetTime(40)
  SetXP(300, 1000)
  NS.onXPUpdate()

  ---@cast onEvent fun(self: TestEventFrame, event: string, ...: any)
  onEvent(frame, "PLAYER_LEVEL_UP", 2)

  assert_eq(0, recordCalls, "level-up should not write history in the HUD-first build")
end)

it("level-up keeps rolling XP pace continuous across the bar reset", function()
  local frame = eventFrame
  assert_true(eventFrame ~= nil, "event frame should be created")
  ---@cast frame TestEventFrame

  local onEvent = frame:GetScript("OnEvent")
  assert_true(onEvent ~= nil, "event frame should register an OnEvent handler")

  SetTime(100)
  SetLevel(1)
  SetXP(0, 1000)
  NS.resetXPState()

  SetTime(110)
  SetXP(900, 1000)
  NS.onXPUpdate()

  SetTime(120)
  SetLevel(2)
  ---@cast onEvent fun(self: TestEventFrame, event: string, ...: any)
  onEvent(frame, "PLAYER_LEVEL_UP", 2)

  SetTime(121)
  SetXP(50, 1000)
  onEvent(frame, "PLAYER_XP_UPDATE", "player")

  assert_eq(1050, NS.state.sessionXP, "session XP should remain continuous after level-up")
  assert_eq(1050, NS.state.windowXP, "rolling XP/hr should include XP from both sides of the level-up")
  assert_eq(2, #NS.state.events, "level-up should not clear rolling XP events")
  assert_eq(150, NS.state.lastXPGain, "the first post-level XP update should count rollover XP")
end)

run_tests()
