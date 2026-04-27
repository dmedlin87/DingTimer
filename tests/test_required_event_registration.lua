dofile("tests/mocks.lua")

local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name then
    ---@diagnostic disable-next-line: duplicate-set-field
    frame.RegisterEvent = function(_, eventName)
      if eventName == "PLAYER_LOGIN" then
        error("simulated registration failure")
      end
    end
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/HUDText.lua", NS)
LoadAddonFile("DingTimer/HUDGraph.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)

local ok, err = pcall(function()
  LoadAddonFile("DingTimer/DingTimer.lua", NS)
end)

CreateFrame = baseCreateFrame

assert_false(ok, "DingTimer.lua should fail fast when required event registration fails")
assertStringMatch("Failed to register required event PLAYER_LOGIN", tostring(err), "required event failure should identify the event")

print("Required event registration test passed!")
