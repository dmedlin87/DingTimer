dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_StatsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.resetXPState()

NS.InitGraphWindow()
NS.InitStatsWindow()
NS.InitSettingsWindow()

NS.SetGraphVisible(true)
NS.ToggleStatsWindow()
NS.ToggleSettingsWindow()

assert_true(DingTimerXPGraphWindow ~= nil, "graph window should be created")
assert_true(DingTimerStatsWindow ~= nil, "stats window should be created")
assert_true(DingTimerSettingsWindow ~= nil, "settings window should be created")

print("UI window smoke test passed!")
