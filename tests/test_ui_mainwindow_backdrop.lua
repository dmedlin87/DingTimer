dofile("tests/mocks.lua")

local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if template ~= "BackdropTemplate" then
    frame.SetBackdrop = nil
    frame.SetBackdropColor = nil
    frame.SetBackdropBorderColor = nil
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)

DingTimerDB = {
  lastOpenTab = 1,
}

local ok, err = pcall(function()
  NS.ToggleMainWindow(1)
end)

CreateFrame = baseCreateFrame

assert_true(ok, "main window should initialize on clients where only BackdropTemplate frames expose SetBackdrop: " .. tostring(err))
---@diagnostic disable-next-line: undefined-global
assert_true(DingTimerMainContent ~= nil, "main content frame should be created")

print("Main window backdrop compatibility test passed!")
