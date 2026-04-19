dofile("tests/mocks.lua")

SetProfileIdentity("MoPTester", "Azeroth", "PRIEST", 90, "Priest")

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
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

local ok, err = pcall(function()
  LoadAddonFile("DingTimer/Pvp.lua", NS)
  LoadAddonFile("DingTimer/DingTimer.lua", NS)
end)

CreateFrame = baseCreateFrame

assert_true(ok, "DingTimer.lua should load when a client rejects HONOR_XP_UPDATE: " .. tostring(err))
assert_true(eventFrame ~= nil, "event frame should be created")

local registered = eventFrame and eventFrame._registeredEvents or {}
assert_true(#registered > 0, "supported events should still be registered")

local sawLogin = false
for i = 1, #registered do
  if registered[i] == "PLAYER_LOGIN" then
    sawLogin = true
    break
  end
end

assert_true(sawLogin, "client-safe registration should keep core events active")

print("Event registration compatibility test passed!")
