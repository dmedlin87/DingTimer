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

it("level-up and logout no longer append history records", function()
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
  onEvent(frame, "PLAYER_LOGOUT")

  assert_eq(0, recordCalls, "level-up and logout should not write history in the HUD-first build")
end)

run_tests()
