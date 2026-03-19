dofile("tests/mocks.lua")

SetProfileIdentity("Viewer", "Azeroth", "SHAMAN", 80, "Shaman")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)

NS.GraphFeedXP = function() end
NS.GraphReset = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Pvp.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_StatsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_InsightsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()

SetTime(100)
SetXP(0, 1000)
SetHonor(4000, 75000)
SetLifetimeHKs(40)
SetZone("Arathi Basin")
NS.resetXPState()
NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)

SetTime(120)
SetHonor(4300, 75000)
SetLifetimeHKs(43)
NS.RefreshPvpSnapshot(120, "UPDATE_BATTLEFIELD_SCORE")

local statsPanel = NS.InitStatsPanel(UIParent)
statsPanel:Show()
NS.RefreshStatsWindow()
assert_eq("Honor / hr", statsPanel.cards.currentXph.label:GetText(), "stats panel should relabel the primary pace card in pvp mode")
assert_eq("Session HKs", statsPanel.cards.sessionMoney.label:GetText(), "stats panel should relabel session HKs in pvp mode")
assert_eq("Recap", statsPanel.secondaryButton:GetText(), "stats panel quick action should switch to recap in pvp mode")

NS.SetPvpHistoryView("pvp")
local insightsPanel = NS.InitInsightsPanel(UIParent)
insightsPanel:Show()
NS.RefreshInsightsWindow()
assert_eq("Median Honor/hr", insightsPanel.labels.median:GetText(), "insights panel should switch to pvp summary labels")
assert_eq("Recent PvP Sessions (newest first)", insightsPanel.labels.rows:GetText(), "insights panel should relabel the rows header in pvp view")

local settingsPanel = NS.InitSettingsPanel(UIParent)
settingsPanel:Show()
assert_true(string.find(settingsPanel.controls.pvpInfo:GetText(), "Mode:", 1, true) ~= nil, "settings panel should show pvp status info")

print("PvP UI mode tests passed!")
