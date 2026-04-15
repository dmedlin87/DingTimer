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
assert_near(snapshot.currentXph, 180000, 0.1, "current pace should reflect the immediate 10s spike")
assert_eq(10, math.floor(snapshot.ttl + 0.5), "TTL should use the same raw pace immediately")

print("Live pace test passed!")
