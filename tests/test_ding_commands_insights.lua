dofile("tests/mocks.lua")

SetProfileIdentity("Commander", "Azeroth", "WARRIOR", 50, "Warrior")

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

local toggles = 0
NS.ToggleMainWindow = function()
  toggles = toggles + 1
end

SlashCmdList.DINGTIMER("insights")
assert_eq(toggles, 1, "insights command should toggle insights window")

local profile = NS.GetProfileStore(true)
profile.sessions = {}
for i = 1, 8 do
  profile.sessions[#profile.sessions + 1] = {
    id = tostring(i),
    avgXph = i * 100,
    durationSec = 60,
  }
end

SlashCmdList.DINGTIMER("insights keep 5")
assert_eq(DingTimerDB.xp.keepSessions, 5, "keep value should update")
assert_eq(#profile.sessions, 5, "sessions should be trimmed to keep value")

SlashCmdList.DINGTIMER("insights keep 4")
assert_eq(DingTimerDB.xp.keepSessions, 5, "invalid keep value should be rejected")

SlashCmdList.DINGTIMER("insights clear")
assert_eq(#profile.sessions, 0, "insights clear should wipe current profile sessions")

print("Insights slash command tests passed!")
