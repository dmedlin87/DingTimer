dofile("tests/mocks.lua")

local eventFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not eventFrame then
    eventFrame = frame
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

CreateFrame = baseCreateFrame

DingTimerDB = {
  enabled = true,
  float = true,
  floatLocked = true,
  floatShowInCombat = true,
  windowSeconds = 600,
  mode = "full",
}

local baseInCombatLockdown = InCombatLockdown
InCombatLockdown = function()
  return true
end

assert_true(eventFrame ~= nil, "event frame should be created")
local onEvent = eventFrame:GetScript("OnEvent")
assert_true(onEvent ~= nil, "event frame should register an OnEvent handler")

onEvent(eventFrame, "ADDON_LOADED", "DingTimer")
onEvent(eventFrame, "PLAYER_LOGIN")

local floatFrame = NS.GetFloatFrame()
assert_true(floatFrame ~= nil, "HUD frame should exist after login")
assert_true(floatFrame:IsShown(), "HUD should show on login when show-in-combat is enabled")

InCombatLockdown = baseInCombatLockdown

print("Login HUD visibility test passed!")
