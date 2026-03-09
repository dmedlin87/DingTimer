-- Tests for the graph average-line math.
--
-- The bug (pre-fix): RedrawGraph used graphState.totalXP as the starting
-- numerator for the session-average calculation.  totalXP is decremented
-- whenever old events are pruned, so after a long session the numerator
-- was "last ~60 min of XP" while the denominator was "full session elapsed
-- time", making the average line drift artificially low.
--
-- The fix: a separate sessionTotalXP counter accumulates XP without ever
-- being decremented by pruning.  RedrawGraph now starts from sessionTotalXP
-- so the numerator always matches the full-session denominator.
--
-- These tests verify the math in isolation without needing WoW UI APIs.

dofile("tests/mocks.lua")

print("Running graph average math tests...")

-- ---------------------------------------------------------------------------
-- Helper: simulate the state the graph module maintains
-- ---------------------------------------------------------------------------

local function newGraphState()
  return {
    events       = {},
    totalXP      = 0,
    sessionTotalXP = 0,
  }
end

-- Simulate NS.GraphFeedXP
local function feedXP(gs, delta, timestamp)
  if delta <= 0 then return end
  table.insert(gs.events, { t = timestamp, xp = delta })
  gs.totalXP         = gs.totalXP + delta
  gs.sessionTotalXP  = gs.sessionTotalXP + delta
end

-- Simulate pruneGraphEvents (prune events older than cutoff)
local MAX_RETENTION_SECONDS = 3600
local function pruneEvents(gs, now)
  local cutoff = now - MAX_RETENTION_SECONDS - 60
  local events = gs.events
  local i = 1
  while events[i] and events[i].t < cutoff do
    gs.totalXP = gs.totalXP - events[i].xp
    i = i + 1
  end
  if i > 1 then
    for j = 1, (#events - i + 1) do
      events[j] = events[j + i - 1]
    end
    for j = #events, (#events - i + 2), -1 do
      events[j] = nil
    end
  end
end

-- Simulate NS.GraphReset
local function resetGraph(gs)
  gs.events          = {}
  gs.totalXP         = 0
  gs.sessionTotalXP  = 0
end

-- ---------------------------------------------------------------------------
-- Test 1: sessionTotalXP accumulates correctly, totalXP matches it before pruning
-- ---------------------------------------------------------------------------

local gs = newGraphState()
local sessionStart = 0

feedXP(gs, 10000, 10)
feedXP(gs, 20000, 20)
feedXP(gs, 15000, 30)

assert_eq(gs.sessionTotalXP, 45000, "sessionTotalXP should be sum of all fed XP")
assert_eq(gs.totalXP, 45000, "totalXP should equal sessionTotalXP before any pruning")
print("  [PASS] sessionTotalXP accumulates correctly before pruning")

-- ---------------------------------------------------------------------------
-- Test 2: pruning reduces totalXP but sessionTotalXP is unaffected
-- ---------------------------------------------------------------------------

gs = newGraphState()
sessionStart = 0

-- Events at time 0 and 10 – will be pruned when now > 3720 (cutoff = now - 3660)
feedXP(gs, 5000,  0)
feedXP(gs, 7000,  10)
-- Event at time 4000 – retained
feedXP(gs, 8000,  4000)

local totalBefore = gs.sessionTotalXP
assert_eq(totalBefore, 20000, "sessionTotalXP before pruning")

pruneEvents(gs, 4100)   -- cutoff = 4100 - 3660 = 440 → prunes events at t=0 and t=10

assert_eq(gs.totalXP, 8000, "totalXP after pruning should only include retained event")
assert_eq(gs.sessionTotalXP, 20000, "sessionTotalXP must not change after pruning")
print("  [PASS] pruning reduces totalXP but leaves sessionTotalXP intact")

-- ---------------------------------------------------------------------------
-- Test 3: average computed with sessionTotalXP is accurate after pruning
--         (regression: using totalXP would produce a ~60 % underestimate here)
-- ---------------------------------------------------------------------------

gs = newGraphState()
sessionStart = 0

-- Simulate a 2-hour session.  First hour: 50 k XP spread over retained window.
-- The events in the first hour will be pruned away when we advance to t=7200.
local xpHour1 = 50000
local xpHour2 = 60000

for i = 1, 10 do
  feedXP(gs, xpHour1 / 10, i * 360)    -- spread over first 3600 s
end
for i = 1, 10 do
  feedXP(gs, xpHour2 / 10, 3600 + i * 360)  -- second hour
end

local now = 7200  -- 2 hours in
pruneEvents(gs, now)

-- After pruning, only second-hour events (t > 7200-3660 = 3540) survive.
-- All of hour-1 events (t = 360..3600) are below cutoff 3540, so they prune out.
-- (Some hour-2 events near t=3600 may also prune, but the key point holds.)

local elapsed = now - sessionStart   -- 7200 seconds

-- Bug scenario: using totalXP for the numerator
local avg_buggy  = (gs.totalXP / elapsed) * 3600

-- Fixed scenario: using sessionTotalXP for the numerator
local avg_fixed  = (gs.sessionTotalXP / elapsed) * 3600

local true_avg = ((xpHour1 + xpHour2) / elapsed) * 3600  -- 55000 XP/hr

-- The fixed average should be within a few % of the true average.
-- The buggy average should be substantially lower (misses hour-1 XP).
assert_true(avg_fixed > avg_buggy,
  "fixed average should be higher than buggy (pruned) average")
assert_true(math.abs(avg_fixed - true_avg) < true_avg * 0.05,
  "fixed average should be within 5 % of true session average")
assert_true(avg_buggy < true_avg * 0.80,
  "buggy average should be noticeably below true average (demonstrates the bug)")

print("  [PASS] sessionTotalXP-based average is accurate; totalXP-based average drifts low")

-- ---------------------------------------------------------------------------
-- Test 4: GraphReset zeroes both counters
-- ---------------------------------------------------------------------------

gs = newGraphState()
feedXP(gs, 12345, 100)
feedXP(gs, 67890, 200)
resetGraph(gs)

assert_eq(gs.totalXP,        0, "totalXP should be 0 after reset")
assert_eq(gs.sessionTotalXP, 0, "sessionTotalXP should be 0 after reset")
assert_eq(#gs.events,        0, "events should be empty after reset")
print("  [PASS] GraphReset zeroes both XP counters")

-- ---------------------------------------------------------------------------
-- Test 5: zero-XP feed is a no-op
-- ---------------------------------------------------------------------------

gs = newGraphState()
feedXP(gs, 0,  100)
feedXP(gs, -5, 200)

assert_eq(gs.totalXP,        0, "zero/negative XP should not accumulate in totalXP")
assert_eq(gs.sessionTotalXP, 0, "zero/negative XP should not accumulate in sessionTotalXP")
assert_eq(#gs.events,        0, "zero/negative XP should produce no events")
print("  [PASS] zero/negative XP feed is a no-op")

print("\nGraph average math tests passed!")
