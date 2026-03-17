dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.EnsureCoachConfig = nil

local ok, err = pcall(function()
  NS.InitMainWindow()
  NS.ShowMainWindow(4)
end)

assert_true(ok, "settings should open even when NS.EnsureCoachConfig is missing")
assert_true(DingTimerSettingsPanel ~= nil and DingTimerSettingsPanel:IsShown(), "settings panel should still be shown")
assert_true(err == nil, "settings should not throw when EnsureCoachConfig is missing")

print("Settings without EnsureCoachConfig test passed!")
