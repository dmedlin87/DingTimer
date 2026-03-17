dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_StatsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_InsightsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.resetXPState()

NS.InitGraphPanel(nil)
NS.InitStatsPanel(nil)
NS.InitSettingsPanel(nil)

NS.ToggleMainWindow(1)
NS.ToggleMainWindow(4)

assert_true(DingTimerXPGraphPanel ~= nil, "graph window should be created")
assert_true(DingTimerStatsPanel ~= nil, "stats window should be created")
assert_true(DingTimerSettingsPanel ~= nil, "settings window should be created")

print("UI window smoke test passed!")
