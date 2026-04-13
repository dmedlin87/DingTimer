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

it("exposes graph, history, and settings shortcuts from the live tab", function()
  local statsPanel = NS.InitStatsPanel(UIParent)

  assert_eq(statsPanel.graphButton:GetText(), "Graph", "graph shortcut should be labeled Graph")
  assert_eq(statsPanel.historyButton:GetText(), "History", "history shortcut should be labeled History")
  assert_eq(statsPanel.settingsButton:GetText(), "Settings", "settings shortcut should be labeled Settings")

  statsPanel.graphButton:GetScript("OnClick")(statsPanel.graphButton)
  assert_true(DingTimerMainWindow:IsShown(), "graph shortcut should show the main window")
  assert_eq(DingTimerDB.lastOpenTab, 2, "graph shortcut should target the analysis tab")

  statsPanel.historyButton:GetScript("OnClick")(statsPanel.historyButton)
  assert_eq(DingTimerDB.lastOpenTab, 3, "history shortcut should target the history tab")

  statsPanel.settingsButton:GetScript("OnClick")(statsPanel.settingsButton)
  assert_eq(DingTimerDB.lastOpenTab, 4, "settings shortcut should target the settings tab")
end)

run_tests()
