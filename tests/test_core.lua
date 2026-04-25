require("tests.mocks")

local NS = {}
-- Global DB mock
DingTimerDB = {
    windowSeconds = 600,
    enabled = true,
    coach = {},
}

-- Mock some dependencies in NS
NS.fmtTime = function(s) return tostring(s) end
NS.ttlColor = function() return "" end
NS.ttlDeltaText = function() return "" end
NS.chat = function() end
NS.C = { base = "", r = "" }

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)

print("Running Core_DingTimer tests...")

-- Test 1: Initial state
NS.resetXPState()
assert_eq(NS.state.sessionXP, 0, "Initial sessionXP should be 0")
assert_eq(#NS.state.events, 0, "Initial events should be empty")
assert_eq(nil, NS.state.lastXPGain, "Initial lastXPGain should be nil")

-- Test 2: XP Update
SetTime(100)
SetXP(100, 1000)
NS.onXPUpdate()
assert_eq(NS.state.sessionXP, 100, "sessionXP should be 100")
assert_eq(#NS.state.events, 1, "Should have 1 event")
assert_eq(NS.state.events[1].xp, 100, "Event XP should be 100")
assert_eq(100, NS.state.lastXPGain, "lastXPGain should record the latest positive gain")

-- Test 3: XP/hr Calculation
-- 100 XP in 100 seconds (if session started at 0)
-- But wait, resetXPState sets sessionStartTime to current GetTime()
NS.resetXPState() -- sets sessionStartTime = 100
SetTime(200)
SetXP(200, 1000)
NS.onXPUpdate() -- +100 XP at t=200
-- Rate should be 100 XP / (200-100) sec = 1 XP/s = 3600 XP/hr
local xph = NS.computeXPPerHour(200, 600)
assert_near(xph, 3600, 0.1, "XP/hr should be 3600")

-- Test 4: Event Pruning
SetTime(800) -- 600 seconds later
SetXP(300, 1000)
NS.onXPUpdate() -- +100 XP at t=800
-- At t=800, window of 600s goes back to t=200.
-- The event at t=200 is right on the edge. pruneEvents uses `(now - evList[i].t) > windowSeconds`
-- 800 - 200 = 600. 600 > 600 is false. So it stays.
xph = NS.computeXPPerHour(800, 600)
assert_near(xph, 200 * 3600 / 600, 0.1, "XP/hr should be 1200")

SetTime(801)
xph = NS.computeXPPerHour(801, 600) -- event at 200 is now pruned (801-200 > 600)
assert_near(xph, 100 * 3600 / 601, 0.1, "XP/hr should decay every second after pruning")

-- Test 4b: Snapshot pace should reflect the raw rolling rate immediately
NS.resetXPState()
SetTime(811)
SetXP(400, 1000)
NS.onXPUpdate() -- +100 XP after 10s
local snapshot = NS.GetSessionSnapshot(811)
assert_near(snapshot.currentXph, 36000, 0.1, "current pace should keep the immediate spike")
assert_near(snapshot.ttl, 60, 0.1, "TTL should be derived from the same raw pace")
assert_eq(100, snapshot.lastXPGain, "snapshot should expose the most recent gain")
assert_eq(811, snapshot.lastXPAt, "snapshot should expose when the most recent gain happened")
assert_eq(0, snapshot.secondsSinceLastXP, "snapshot should expose freshness for the most recent gain")
assert_eq(600, snapshot.remainingXP, "snapshot should expose the current XP needed to level")
assert_eq(6, snapshot.gainsToLevel, "snapshot should estimate gains remaining based on the most recent gain")

-- Test 5: Level Up (XP Rollover)
SetXP(300, 1000)
NS.resetXPState() -- start at t=801, XP=300, max=1000
assert_eq(nil, NS.state.lastXPGain, "resetXPState should clear lastXPGain")
SetTime(900)
SetXP(50, 1000) -- Leveled up! 700 XP from old level + 50 XP from new level = 750 delta
NS.onXPUpdate()
assert_eq(NS.state.sessionXP, 750, "sessionXP should handle rollover")
assert_eq(750, NS.state.lastXPGain, "lastXPGain should keep the full rollover delta")

-- Test 6: Money/hr
NS.resetXPState() -- t=900, money=0
SetMoney(1000) -- +1000 copper
NS.onMoneyUpdate()
SetTime(1000)
local mph = NS.computeMoneyPerHour(1000, 600)
assert_near(mph, 1000 * 3600 / 100, 0.1, "Money/hr should be 36000")

-- Test 7: Money lifecycle across income, spending, and rolling-window expiry
SetTime(2000)
SetMoney(0)
NS.resetXPState()
SetMoney(1500)
NS.onMoneyUpdate()
assert_eq(NS.state.sessionMoney, 1500, "sessionMoney should track earned money")
assert_eq(NS.state.windowMoney, 1500, "windowMoney should track earned money inside the rolling window")
assert_eq(#NS.state.moneyEvents, 1, "earned money should create one rolling event")

SetTime(2060)
SetMoney(900)
NS.onMoneyUpdate()
assert_eq(NS.state.sessionMoney, 900, "sessionMoney should reflect net gold after spending")
assert_eq(NS.state.windowMoney, 1500, "spending should not change the rolling income total")
assert_eq(#NS.state.moneyEvents, 1, "spending should not create a rolling income event")

local moneySnapshot = NS.GetSessionSnapshot(2060)
assert_eq(900, moneySnapshot.sessionMoney, "snapshot should expose net session money")
assert_near(moneySnapshot.moneyPerHour, 1500 * 3600 / 60, 0.1, "snapshot should keep the rolling income rate based on earned money")

local expiredMoneyRate = NS.computeMoneyPerHour(2601, 600)
assert_near(expiredMoneyRate, 0, 0.1, "expired money gains should fall out of the rolling window")
assert_eq(NS.state.windowMoney, 0, "windowMoney should decay to zero after the gain expires")
assert_eq(#NS.state.moneyEvents, 0, "expired money events should be pruned")

print("Core_DingTimer tests passed!")
