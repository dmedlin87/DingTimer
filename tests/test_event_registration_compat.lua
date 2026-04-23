dofile("tests/mocks.lua")

local eventFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not eventFrame then
    eventFrame = frame

    local baseRegisterEvent = frame.RegisterEvent
    frame._registeredEvents = {}
    frame.RegisterEvent = function(self, eventName)
      if eventName == "HONOR_XP_UPDATE" then
        error('Frame:RegisterEvent(): Attempt to register unknown event "HONOR_XP_UPDATE"')
      end
      table.insert(self._registeredEvents, eventName)
      return baseRegisterEvent(self, eventName)
    end
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

local ok, err = pcall(function()
  LoadAddonFile("DingTimer/DingTimer.lua", NS)
end)

CreateFrame = baseCreateFrame

assert_true(ok, "DingTimer.lua should load without registering removed PvP events: " .. tostring(err))
assert_true(eventFrame ~= nil, "event frame should be created")

local registered = eventFrame and eventFrame._registeredEvents or {}
assert_true(#registered > 0, "core events should still be registered")

local sawLogin = false
local sawRegenDisabled = false
local sawLogout = false
local sawRemovedHonor = false
for i = 1, #registered do
  if registered[i] == "PLAYER_LOGIN" then
    sawLogin = true
  elseif registered[i] == "PLAYER_REGEN_DISABLED" then
    sawRegenDisabled = true
  elseif registered[i] == "PLAYER_LOGOUT" then
    sawLogout = true
  elseif registered[i] == "HONOR_XP_UPDATE" then
    sawRemovedHonor = true
  end
end

assert_true(sawLogin, "client-safe registration should keep core login handling active")
assert_true(sawRegenDisabled, "HUD visibility should watch combat entry without secure state drivers")
assert_false(sawLogout, "HUD-first build should not register the removed logout no-op")
assert_false(sawRemovedHonor, "HUD-first build should not register removed PvP events")

print("Event registration compatibility test passed!")
