dofile("tests/mocks.lua")

SetProfileIdentity("Gladiator", "Azeroth", "WARRIOR", 80, "Warrior")

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
SetHonor(1000, 75000)
SetLifetimeHKs(10)
SetZone("Durotar")
SetInstanceState(false, nil)
NS.resetXPState()

SetTime(120)
SetXP(250, 1000)
NS.onXPUpdate()
NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 130)

assert_true(NS.IsPvpMode(), "entering pvp mode should switch the active mode")
local xpProfile = NS.GetProfileStore(true)
assert_eq(1, #xpProfile.sessions, "switching into pvp mode should finalize the active xp session")
assert_eq("MODE_SWITCH_TO_PVP", xpProfile.sessions[1].reason, "xp session should record the pvp mode switch reason")

local snapshot = NS.GetPvpSnapshot(130)
assert_eq(0, snapshot.sessionHonor, "fresh pvp session should start at zero honor gained")
assert_eq(0, snapshot.sessionHKs, "fresh pvp session should start at zero HKs gained")

SetTime(140)
SetHonor(1200, 75000)
SetLifetimeHKs(12)
NS.RefreshPvpSnapshot(140, "UPDATE_BATTLEFIELD_SCORE")
snapshot = NS.GetPvpSnapshot(140)
assert_eq(200, snapshot.sessionHonor, "positive honor deltas should increase session honor")
assert_eq(2, snapshot.sessionHKs, "positive HK deltas should increase session HKs")

SetTime(141)
NS.RefreshPvpSnapshot(141, "UPDATE_BATTLEFIELD_SCORE")
snapshot = NS.GetPvpSnapshot(141)
assert_eq(200, snapshot.sessionHonor, "duplicate refreshes should not double count honor")
assert_eq(2, snapshot.sessionHKs, "duplicate refreshes should not double count HKs")

SetTime(150)
SetHonor(900, 75000)
NS.RefreshPvpSnapshot(150, "SPEND")
snapshot = NS.GetPvpSnapshot(150)
assert_eq(200, snapshot.sessionHonor, "spending honor should not create a negative honor event")
assert_eq(900, snapshot.currentHonor, "current honor should still reflect the lower post-spend total")

SetTime(160)
SetHonor(950, 75000)
NS.RefreshPvpSnapshot(160, "HONOR_GAINED")
snapshot = NS.GetPvpSnapshot(160)
assert_eq(250, snapshot.sessionHonor, "later gains should continue from the lower post-spend baseline")

local ok = NS.SetPvpGoal(920)
assert_true(ok, "custom pvp goals should be accepted")
snapshot = NS.GetPvpSnapshot(160)
assert_eq("Goal Reached", snapshot.ttgText, "custom goals reached mid-session should clamp the TTG text")

NS.ResetPvpSession("MANUAL_RESET", 170)
snapshot = NS.GetPvpSnapshot(170)
assert_eq(0, snapshot.sessionHonor, "resetting a pvp session should clear the session honor")
assert_eq("custom", snapshot.goalMode, "resetting a pvp session should preserve the persistent goal")

print("PvP tracking tests passed!")
