dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()

local ok, err = pcall(function()
  NS.InitMainWindow()
  NS.ShowMainWindow(4)
end)

assert_true(ok, "settings should open even when SessionCoach.lua is not loaded")
assert_true(DingTimerSettingsPanel ~= nil and DingTimerSettingsPanel:IsShown(), "settings panel should be shown")
assert_true(err == nil, "settings should not throw")

print("Settings without SessionCoach test passed!")
