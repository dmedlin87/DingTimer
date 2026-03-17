dofile("tests/mocks.lua")

SetProfileIdentity("Coach", "Azeroth", "DRUID", 20, "Druid")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

DingTimerDB = nil
NS.InitStore()

SetTime(100)
SetXP(0, 1000)
SetMoney(0)
SetZone("Elwynn")
NS.resetXPState()

assert_eq(DingTimerDB.coach.goal, "ding", "coach goal should default to ding")

SetTime(130)
SetXP(300, 1000)
NS.onXPUpdate()
SetMoney(250)
NS.onMoneyUpdate()

SetTime(160)
NS.SplitSession("MANUAL_SPLIT")

local segments = NS.GetCoachSegments(false, 160)
assert_eq(#segments, 1, "manual split should finalize one segment")
assert_eq(segments[1].reason, "MANUAL_SPLIT", "manual split should label the segment")
assert_eq(segments[1].xpGained, 300, "segment should include tracked XP")
assert_eq(segments[1].moneyNetCopper, 250, "segment should include tracked money")

SetTime(180)
SetXP(500, 1000)
NS.onXPUpdate()
SetZone("Westfall")
SetTime(200)
NS.HandleZoneChange("Westfall", 200)

segments = NS.GetCoachSegments(false, 200)
assert_eq(#segments, 2, "zone change should finalize the active segment")
assert_eq(segments[2].reason, "ZONE_CHANGED", "zone changes should create a zone segment")
assert_eq(segments[2].zone, "Elwynn", "zone change should close the prior zone segment")

DingTimerDB.coach.goal = "30m"
local goal = NS.GetCoachGoalStatus(NS.GetSessionSnapshot(200))
assert_eq(goal.goalLabel, "Ding in 30m", "30m goal should report the correct label")
assert_near(goal.targetXph, 1000, 0.001, "30m goal should derive pace from remaining XP")

DingTimerDB.coach.goal = "ding"
goal = NS.GetCoachGoalStatus(NS.GetSessionSnapshot(200))
assert_eq(goal.goalLabel, "Session high pace", "ding goal should use a distinct benchmark label")
assert_eq(goal.shortLabel, "High", "ding goal should expose a short HUD label")
-- Peak is 500 XP over 80s (t=130 event excluded by the 60s warmup guard) → 22500 XP/hr
assert_near(goal.targetXph, 22500, 0.001, "ding goal should benchmark against the best post-warmup pace seen this session")

DingTimerDB.coach.goal = "30m"
SetTime(291)
NS.RunCoachHeartbeat(291)
local alerts = NS.GetCoachAlerts(10)
assert_true(#alerts >= 1, "idle heartbeat should create at least one alert")
assert_eq(alerts[1].kind, "idle", "idle heartbeat should create an idle alert")

SetTime(300)
SetXP(0, 1000)
NS.resetXPState()
DingTimerDB.coach.goal = "30m"
SetTime(360)
SetXP(20, 1000)
NS.onXPUpdate()
NS.RunCoachHeartbeat(360)
alerts = NS.GetCoachAlerts(10)
assert_eq(alerts[1].kind, "pace_drop", "slow pace against a timed goal should create a pace drop alert")

local result_nil = NS.DeliverCoachSummary(nil)
assert_eq(result_nil, false, "DeliverCoachSummary should return false when given a nil summary")

local record = NS.RecordSession("MANUAL_RESET")
assert_true(record ~= nil, "recording a coached session should return a session record")
assert_true(record.segments ~= nil and #record.segments >= 1, "recorded sessions should include segments")
assert_true(record.coachSummary ~= nil, "recorded sessions should include a coach summary")
assert_true(DingTimerDB.coach.lastRecap ~= nil, "coach recaps should persist to the store")

print("Session coach tests passed!")
