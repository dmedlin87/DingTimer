dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)

local eventFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not eventFrame then
    eventFrame = frame
  end
  return frame
end

LoadAddonFile("DingTimer/DingTimer.lua", "DingTimer", NS)
CreateFrame = baseCreateFrame

assert_true(eventFrame ~= nil, "event frame should be created")
local onEvent = eventFrame:GetScript("OnEvent")
assert_true(onEvent ~= nil, "event frame should register an OnEvent handler")

local function startNearLevelEnd()
  DingTimerDB = {
    enabled = false,
    float = false,
    floatLocked = true,
    floatShowInCombat = false,
    windowSeconds = 600,
    mode = "full",
  }

  ClearChatLog()
  SetLevel(1)
  SetTime(0)
  SetXP(900, 1000)
  SetMoney(0)

  NS.InitStore()
  onEvent(eventFrame, "PLAYER_LOGIN")

  assert_eq(NS.state.lastXP, 900, "precondition: runtime should start near the old level cap")
  assert_eq(NS.state.sessionXP, 0, "precondition: login should start a clean session")
end

it("keeps completed-level rollover XP out of the new session when level-up arrives first", function()
  startNearLevelEnd()

  SetTime(10)
  SetLevel(2)
  onEvent(eventFrame, "PLAYER_LEVEL_UP", 2)

  assert_eq(NS.state.sessionXP, 0, "level-up should reset the completed level session")

  SetXP(50, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 0, "post-level XP drop should become the new level baseline")
  assert_eq(#NS.state.events, 0, "post-level XP drop should not create a rolling event")
  assert_eq(NS.state.lastXP, 50, "post-level XP update should refresh the baseline")

  SetTime(20)
  SetXP(100, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 50, "later XP gains in the new level should be recorded normally")
  assert_eq(#NS.state.events, 1, "later XP gains should create rolling events normally")
end)

it("keeps rollover XP in the completed level when XP update arrives before level-up", function()
  startNearLevelEnd()

  SetTime(10)
  SetLevel(2)
  SetXP(50, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 150, "pre-level-up XP update should count old-level rollover XP")

  onEvent(eventFrame, "PLAYER_LEVEL_UP", 2)

  assert_eq(NS.state.sessionXP, 0, "level-up should reset the new level session after the summary")
  assert_eq(#NS.state.events, 0, "level-up should clear old rolling XP events")
  assert_eq(NS.state.lastXP, 50, "new level should start from the post-rollover XP value")

  SetTime(20)
  SetXP(100, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 50, "new-level XP after reset should be counted from the new baseline")
  assert_eq(#NS.state.events, 1, "new-level XP after reset should create one rolling event")
end)

run_tests()
