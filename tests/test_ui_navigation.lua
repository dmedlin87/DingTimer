dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_Shared.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_StatsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_InsightsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)
LoadAddonFile("DingTimer/UI_MinimapButton.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.resetXPState()

DingTimerDB.mainWindowPosition = {
  point = "TOPLEFT",
  relativePoint = "TOPLEFT",
  xOfs = 10,
  yOfs = -20,
}

NS.InitMainWindow()

local point, _, relativePoint, xOfs, yOfs = DingTimerMainWindow:GetPoint()
assert_eq(point, "TOPLEFT", "main window should restore saved point")
assert_eq(relativePoint, "TOPLEFT", "main window should restore relative point")
assert_eq(xOfs, 10, "main window should restore x offset")
assert_eq(yOfs, -20, "main window should restore y offset")

DingTimerMainWindow:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -33, 44)
local onDragStop = DingTimerMainWindow:GetScript("OnDragStop")
onDragStop(DingTimerMainWindow)
assert_eq(DingTimerDB.mainWindowPosition.point, "BOTTOMRIGHT", "drag stop should persist main window point")
assert_eq(DingTimerDB.mainWindowPosition.relativePoint, "BOTTOMRIGHT", "drag stop should persist relative point")
assert_eq(DingTimerDB.mainWindowPosition.xOfs, -33, "drag stop should persist x offset")
assert_eq(DingTimerDB.mainWindowPosition.yOfs, 44, "drag stop should persist y offset")

local minimapClick = DingTimerMinimapButton:GetScript("OnClick")

minimapClick(DingTimerMinimapButton, "LeftButton")
assert_true(DingTimerMainWindow:IsShown(), "left-click should show the live tab")
assert_eq(DingTimerDB.lastOpenTab, 1, "left-click should target the live tab")

minimapClick(DingTimerMinimapButton, "LeftButton")
assert_true(not DingTimerMainWindow:IsShown(), "left-click on the active live tab should hide the main window")

minimapClick(DingTimerMinimapButton, "RightButton")
assert_true(DingTimerMainWindow:IsShown(), "right-click should show the analysis tab")
assert_eq(DingTimerDB.lastOpenTab, 2, "right-click should target the analysis tab")

minimapClick(DingTimerMinimapButton, "MiddleButton")
assert_true(DingTimerMainWindow:IsShown(), "middle-click should keep the main window open")
assert_eq(DingTimerDB.lastOpenTab, 4, "middle-click should switch to the settings tab")

SlashCmdList.DINGTIMER("graph on")
assert_true(DingTimerMainWindow:IsShown(), "graph on should show the main window")
assert_eq(DingTimerDB.lastOpenTab, 2, "graph on should select the graph tab")

SlashCmdList.DINGTIMER("graph off")
assert_true(not DingTimerMainWindow:IsShown(), "graph off should hide the main window when the graph tab is active")

SlashCmdList.DINGTIMER("settings")
assert_true(DingTimerMainWindow:IsShown(), "settings should show the main window")
assert_eq(DingTimerDB.lastOpenTab, 4, "settings should select the settings tab")

SlashCmdList.DINGTIMER("graph off")
assert_true(DingTimerMainWindow:IsShown(), "graph off should not hide other tabs")
assert_eq(DingTimerDB.lastOpenTab, 4, "graph off should not change the active tab when another tab is shown")
assert_eq(DingTimerMainWindow.tabs[1]:GetText(), "Live", "first tab should be Live")
assert_eq(DingTimerMainWindow.tabs[2]:GetText(), "Analysis", "second tab should be Analysis")
assert_eq(DingTimerMainWindow.tabs[3]:GetText(), "History", "third tab should be History")

print("UI navigation tests passed!")
