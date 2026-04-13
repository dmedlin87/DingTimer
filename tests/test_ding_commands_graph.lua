dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.resetXPState()

SetTime(100)
SetXP(100, 1000)
NS.onXPUpdate()
assert_eq(NS.state.sessionXP, 100, "precondition: session XP should track gains")

SlashCmdList.DINGTIMER("window 300")
assert_eq(DingTimerDB.windowSeconds, 300, "window command should update rolling window")
assert_eq(NS.state.sessionXP, 100, "window command should not reset the current session")

SlashCmdList.DINGTIMER("graph scale session")
assert_eq(DingTimerDB.graphScaleMode, "session", "graph scale should accept session mode")

SlashCmdList.DINGTIMER("graph fit")
assert_eq(DingTimerDB.graphScaleMode, "visible", "graph fit should switch back to visible mode")

NS.RefreshSettingsPanel = function() end

SlashCmdList.DINGTIMER("graph max 250000")
assert_eq("fixed", DingTimerDB.graphScaleMode, "graph max should move the graph into fixed mode")
assert_eq(250000, DingTimerDB.graphFixedMaxXPH, "graph max should update the fixed cap")

print("Graph slash command tests passed!")
