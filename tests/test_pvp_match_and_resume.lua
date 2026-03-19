dofile("tests/mocks.lua")

SetProfileIdentity("Scout", "Azeroth", "HUNTER", 80, "Hunter")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)

NS.GraphFeedXP = function() end
NS.GraphReset = function() end
NS.RefreshStatsWindow = function() end
NS.RefreshInsightsWindow = function() end
NS.RefreshSettingsPanel = function() end
NS.RefreshFloatingHUD = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Pvp.lua", NS)

DingTimerDB = nil
NS.InitStore()

SetTime(100)
SetXP(0, 1000)
SetMoney(0)
SetHonor(2000, 75000)
SetLifetimeHKs(50)
SetZone("Warsong Gulch")
SetInstanceState(true, "pvp")
NS.resetXPState()
NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)
NS.RefreshPvpSnapshot(100, "BASELINE")

SetTime(110)
SetHonor(2250, 75000)
SetLifetimeHKs(53)
NS.RefreshPvpSnapshot(110, "UPDATE_BATTLEFIELD_SCORE")

SetInstanceState(false, nil)
SetZone("Orgrimmar")
NS.HandlePvpWorldStateChange(120)

SetTime(130)
SetHonor(2400, 75000)
SetLifetimeHKs(54)
NS.RefreshPvpSnapshot(130, "LATE_BONUS")
NS.RunPvpHeartbeat(136)

local recentMatches = NS.GetRecentPvpMatches(1)
assert_eq(1, #recentMatches, "leaving a battleground should finalize one recent match after the grace window")
assert_eq(400, recentMatches[1].honorGained, "late honor inside the grace window should be attributed to the closed match")
assert_eq(4, recentMatches[1].hkGained, "late HK deltas inside the grace window should be attributed to the closed match")
assert_true(NS.IsPvpMode(), "manual pvp mode should stay active after battleground recap finalization")

NS.PersistPvpResume(140)
assert_true(DingTimerDB.pvp.resume ~= nil, "logout persistence should capture the active pvp session")

NS.state.pvp = nil
setmetatable(NS.state, nil)
DingTimerDB.activeMode = "xp"

local restored = NS.RestorePvpResumeIfAvailable(145)
assert_true(restored, "fresh resume data should restore the active pvp session")
assert_true(NS.IsPvpMode(), "restoring a pvp resume should switch back into pvp mode")
local snapshot = NS.GetPvpSnapshot(145)
assert_eq(400, snapshot.sessionHonor, "restored pvp sessions should preserve session honor totals")
assert_eq(4, snapshot.sessionHKs, "restored pvp sessions should preserve session HK totals")

NS.PersistPvpResume(145)
DingTimerDB.pvp.resume.savedAt = 145 - 901
NS.state.pvp = nil
DingTimerDB.activeMode = "xp"
restored = NS.RestorePvpResumeIfAvailable(145)
assert_false(restored, "stale resume data should be ignored")
assert_eq("xp", DingTimerDB.activeMode, "stale resume data should leave the addon in leveling mode")

print("PvP match and resume tests passed!")
