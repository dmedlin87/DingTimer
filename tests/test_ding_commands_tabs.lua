dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)

NS.RefreshStatsWindow = function() end
NS.GraphReset = function() end
NS.GraphFeedXP = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

DingTimerDB = nil
NS.InitStore()

local openedTabs = {}
local hiddenCount = 0

NS.ShowMainWindow = function(tabId)
  openedTabs[#openedTabs + 1] = tabId
end

NS.HideMainWindow = function()
  hiddenCount = hiddenCount + 1
  return true
end

NS.IsMainWindowShown = function()
  return true
end

SlashCmdList.DINGTIMER("live")
SlashCmdList.DINGTIMER("analysis")
SlashCmdList.DINGTIMER("history")
SlashCmdList.DINGTIMER("settings")
SlashCmdList.DINGTIMER("graph")

assert_eq(openedTabs[1], 1, "live should open the Live tab")
assert_eq(openedTabs[2], 2, "analysis should open the Analysis tab")
assert_eq(openedTabs[3], 3, "history should open the History tab")
assert_eq(openedTabs[4], 4, "settings should open the Settings tab")
assert_eq(openedTabs[5], 2, "graph should open the Analysis tab")

DingTimerDB.lastOpenTab = 2
SlashCmdList.DINGTIMER("graph off")
assert_eq(hiddenCount, 1, "graph off should hide the window when analysis is active")

DingTimerDB.lastOpenTab = 4
SlashCmdList.DINGTIMER("graph off")
assert_eq(hiddenCount, 1, "graph off should not hide other tabs")

print("Ding command tab tests passed!")
