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

---@return TestEventFrame
local function requireEventFrame()
  assert_true(eventFrame ~= nil, "event frame should be created")
  return eventFrame
end

---@param frame TestEventFrame
---@return fun(self: TestEventFrame, event: string, ...: any)
local function requireOnEvent(frame)
  local handler = frame:GetScript("OnEvent")
  assert_true(handler ~= nil, "event frame should register an OnEvent handler")
  return handler
end

local eventFrameRef = requireEventFrame()
local onEvent = requireOnEvent(eventFrameRef)

local function loadFreshStore()
  DingTimerDB = {
    enabled = false,
    dingSoundEnabled = true,
    float = false,
    floatLocked = true,
    floatShowInCombat = false,
    windowSeconds = 600,
    mode = "full",
  }

  ClearPlayedSounds()
  SetLevel(1)
  SetTime(0)
  SetXP(900, 1000)
  SetMoney(0)
  NS.InitStore()
  onEvent(eventFrameRef, "PLAYER_LOGIN")
end

it("plays the level-up sound when the setting is enabled", function()
  loadFreshStore()

  SetTime(5)
  SetLevel(2)
  onEvent(eventFrameRef, "PLAYER_LEVEL_UP", 2)

  local played = GetPlayedSounds()
  assert_eq(1, #played, "level-up should play one sound when enabled")
  assert_eq(12891, played[1].soundKitID, "level-up should use the existing sound kit")
  assert_eq("Master", played[1].channel, "level-up should play on the Master channel")
end)

it("does not play the level-up sound when the setting is disabled", function()
  loadFreshStore()
  NS.SetDingSoundEnabled(false)

  SetTime(5)
  SetLevel(2)
  onEvent(eventFrameRef, "PLAYER_LEVEL_UP", 2)

  assert_eq(0, #GetPlayedSounds(), "level-up should not play a sound when disabled")
end)

run_tests()
