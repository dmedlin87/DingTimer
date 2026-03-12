require("tests.mocks")

local NS = {}
-- Global DB mock
DingTimerDB = {
    windowSeconds = 600,
    enabled = true,
}

-- Mock some dependencies in NS
NS.fmtTime = function(s) return tostring(s) end
NS.ttlColor = function() return "" end
NS.ttlDeltaText = function() return "" end
NS.chat = function() end
NS.C = { base = "", r = "" }

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

print("Running Core_DingTimer tests...")

-- Test 1: Initial state
NS.resetXPState()
assert_eq(NS.state.sessionXP, 0, "Initial sessionXP should be 0")
assert_eq(#NS.state.events, 0, "Initial events should be empty")

-- Test 2: XP Update
SetTime(100)
SetXP(100, 1000)
NS.onXPUpdate()
assert_eq(NS.state.sessionXP, 100, "sessionXP should be 100")
assert_eq(#NS.state.events, 1, "Should have 1 event")
assert_eq(NS.state.events[1].xp, 100, "Event XP should be 100")

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
assert_near(xph, 100 * 3600 / 600, 0.1, "XP/hr should be 600 after pruning")

-- Test 5: Level Up (XP Rollover)
NS.resetXPState() -- start at t=801, XP=300, max=1000
SetTime(900)
SetXP(50, 1000) -- Leveled up! 700 XP from old level + 50 XP from new level = 750 delta
NS.onXPUpdate()
assert_eq(NS.state.sessionXP, 750, "sessionXP should handle rollover")

-- Test 6: Money/hr
NS.resetXPState() -- t=900, money=0
SetMoney(1000) -- +1000 copper
NS.onMoneyUpdate()
SetTime(1000)
local mph = NS.computeMoneyPerHour(1000, 600)
assert_near(mph, 1000 * 3600 / 100, 0.1, "Money/hr should be 36000")

print("Core_DingTimer tests passed!")
