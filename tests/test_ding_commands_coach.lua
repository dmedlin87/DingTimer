dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)

NS.RefreshStatsWindow = function() end
NS.RefreshSettingsPanel = function() end
NS.GraphReset = function() end
NS.GraphFeedXP = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

DingTimerDB = nil
NS.InitStore()
SetTime(100)
SetXP(0, 1000)
NS.resetXPState()

SlashCmdList.DINGTIMER("goal 30m")
assert_eq(DingTimerDB.coach.goal, "30m", "goal command should set a timed goal")

SlashCmdList.DINGTIMER("split")
local segments = NS.GetCoachSegments(false, GetTime())
assert_eq(#segments, 1, "split command should create a checkpoint segment")
assert_eq(segments[1].reason, "MANUAL_SPLIT", "split command should label the checkpoint")

SetTime(160)
SetXP(200, 1000)
NS.onXPUpdate()
ClearChatLog()
SlashCmdList.DINGTIMER("recap")
local chat = GetChatLog()
assert_true(#chat >= 1, "recap command should print coach recap lines")
assertStringMatch("[COACH]", chat[1], "recap output should include the coach prefix")

print("Coach slash command tests passed!")
