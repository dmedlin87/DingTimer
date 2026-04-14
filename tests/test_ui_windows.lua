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

local graphPanel = NS.InitGraphPanel(nil)
local statsPanel = NS.InitStatsPanel(nil)
local settingsPanel = NS.InitSettingsPanel(nil)

assert_true(graphPanel == NS.InitGraphPanel(nil), "graph window should be created once")
assert_true(statsPanel == NS.InitStatsPanel(nil), "stats window should be created once")
assert_true(settingsPanel == NS.InitSettingsPanel(nil), "settings window should be created once")

assert_true(not graphPanel:IsShown(), "graph window should start hidden")
assert_true(not statsPanel:IsShown(), "stats window should start hidden")
assert_true(not settingsPanel:IsShown(), "settings window should start hidden")

NS.ToggleMainWindow(1)

assert_true(DingTimerMainWindow:IsShown(), "main window should show when the live tab is selected")
assert_eq(DingTimerDB.lastOpenTab, 1, "live tab should become the active tab")
assert_true(DingTimerMainWindow.panels[1] == statsPanel, "live tab should map to the stats panel")
assert_true(statsPanel:IsShown(), "live tab should display the stats panel")
assert_true(not graphPanel:IsShown(), "graph panel should remain hidden while the live tab is active")
assert_true(not settingsPanel:IsShown(), "settings panel should remain hidden while the live tab is active")
assert_eq(DingTimerMainWindow.activeTabPill.label:GetText(), "Live", "live tab should be reflected in the header pill")

NS.ToggleMainWindow(4)

assert_true(DingTimerMainWindow:IsShown(), "main window should stay open when switching tabs")
assert_eq(DingTimerDB.lastOpenTab, 4, "settings tab should become the active tab")
assert_true(DingTimerMainWindow.panels[4] == settingsPanel, "settings tab should map to the settings panel")
assert_true(settingsPanel:IsShown(), "settings tab should display the settings panel")
assert_true(not statsPanel:IsShown(), "stats panel should hide when switching away")
assert_true(not graphPanel:IsShown(), "graph panel should remain hidden when settings is selected")
assert_eq(DingTimerMainWindow.activeTabPill.label:GetText(), "Settings", "settings tab should be reflected in the header pill")

print("UI window lifecycle test passed!")
