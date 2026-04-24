dofile("tests/mocks.lua")

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

---@type table|nil
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
---@cast eventFrame table
local onEvent = eventFrame.GetScript and eventFrame:GetScript("OnEvent")
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

it("keeps rolling XP continuous when level-up arrives before the XP bar drop", function()
  startNearLevelEnd()

  SetTime(10)
  SetLevel(2)
  onEvent(eventFrame, "PLAYER_LEVEL_UP", 2)

  assert_eq(NS.state.sessionXP, 0, "level-up should not add XP by itself")

  SetXP(50, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 150, "post-level XP drop should count completed-level rollover XP")
  assert_eq(#NS.state.events, 1, "post-level XP drop should create a rolling event")
  assert_eq(NS.state.lastXP, 50, "post-level XP update should refresh the baseline")

  SetTime(20)
  SetXP(100, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 200, "later XP gains should continue from the rollover total")
  assert_eq(#NS.state.events, 2, "later XP gains should append to the continuous rolling events")
end)

it("keeps rolling XP continuous when XP update arrives before level-up", function()
  startNearLevelEnd()

  SetTime(10)
  SetLevel(2)
  SetXP(50, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 150, "pre-level-up XP update should count old-level rollover XP")

  onEvent(eventFrame, "PLAYER_LEVEL_UP", 2)

  assert_eq(NS.state.sessionXP, 150, "level-up should preserve the continuous XP session")
  assert_eq(#NS.state.events, 1, "level-up should preserve old rolling XP events")
  assert_eq(NS.state.lastXP, 50, "new level should start from the post-rollover XP value")

  SetTime(20)
  SetXP(100, 1200)
  onEvent(eventFrame, "PLAYER_XP_UPDATE", "player")

  assert_eq(NS.state.sessionXP, 200, "new-level XP should continue from the rollover total")
  assert_eq(#NS.state.events, 2, "new-level XP should append one rolling event")
end)

run_tests()
