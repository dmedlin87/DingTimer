dofile("tests/mocks.lua")

local NS = {
  C = { base = "", r = "" },
  ApplyThemeToFrame = function() end,
  FormatNumber = function(n) return tostring(n) end,
  Round = function(n) return math.floor(n + 0.5) end,
  fmtTime = function(seconds)
    if seconds == math.huge then
      return "inf"
    end
    return tostring(math.floor(seconds + 0.5)) .. "s"
  end,
  ttlColor = function() return "" end,
  ttlDeltaText = function() return "" end,
  chat = function() end,
}

DingTimerDB = {
  enabled = false,
  float = true,
  floatLocked = true,
  windowSeconds = 600,
  coach = {
    goal = "ding",
    stabilizeEarlyPace = true,
  },
}

LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

SetTime(0)
SetXP(0, 1000)
NS.resetXPState()

SetTime(10)
SetXP(500, 1000)
NS.onXPUpdate()

local snapshot = NS.GetSessionSnapshot(10)
assert_near(snapshot.rawCurrentXph, 180000, 0.1, "raw pace should reflect the immediate 10s spike")
assert_near(snapshot.currentXph, 30000, 0.1, "current pace should use the 60s normalized denominator during warmup")
assert_eq(60, math.floor(snapshot.ttl + 0.5), "TTL should use the stabilized pace while warmup is active")
assert_true(snapshot.showSettledOverlay, "warmup spike should request a settled overlay")

DingTimerDB.coach.stabilizeEarlyPace = false
NS.InvalidateTickCache()
snapshot = NS.GetSessionSnapshot(10)
assert_near(snapshot.currentXph, 180000, 0.1, "disabling stabilization should surface the raw pace")
assert_eq(10, math.floor(snapshot.ttl + 0.5), "TTL should fall back to the raw pace when stabilization is off")
assert_true(not snapshot.showSettledOverlay, "overlay should be suppressed when stabilization is disabled")

print("Stabilized pace test passed!")
