dofile("tests/mocks.lua")

SetProfileIdentity("Tracker", "Azeroth", "ROGUE", 30, "Rogue")

local NS = {
  C = { base = "", r = "", val = "", xp = "", bad = "", mid = "" },
  chat = function() end,
  fmtTime = function(v) return tostring(v) end,
  ttlColor = function() return "" end,
  ttlDeltaText = function() return "" end,
  GraphFeedXP = function() end,
  GraphReset = function() end,
  RefreshStatsWindow = function() end,
}

LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

DingTimerDB = {
  windowSeconds = 600,
  enabled = true,
  minXPDeltaToPrint = 1,
  mode = "full",
  float = false,
  xp = {
    keepSessions = 2,
    profiles = {},
  },
}

SetTime(100)
SetXP(200, 1000)
SetMoney(1000)
SetLevel(30)
SetZone("Nagrand")
NS.resetXPState()

NS.state.sessionXP = 2500
NS.state.sessionMoney = 345
NS.state.events = {
  { t = 120, xp = 1200 },
  { t = 160, xp = 1300 },
}

SetTime(200)
SetLevel(31)
local record = NS.RecordSession("LEVEL_UP")
local profile = NS.GetProfileStore(false)

assert_true(record ~= nil, "LEVEL_UP session should be recorded")
assert_eq(#profile.sessions, 1, "profile should have one session")
assert_eq(profile.sessions[1].reason, "LEVEL_UP", "reason should be LEVEL_UP")
assert_eq(profile.sessions[1].levelStart, 30, "levelStart should come from session reset")
assert_eq(profile.sessions[1].levelEnd, 31, "levelEnd should come from current player level")
assert_eq(profile.sessions[1].sampleCount, 2, "sampleCount should reflect event count")
assert_eq(profile.sessions[1].zone, "Nagrand", "zone should be captured")
assert_near(profile.sessions[1].avgXph, (2500 / 100) * 3600, 0.01, "avgXph should match formula")

NS.resetXPState()
SetTime(260)
local skipped = NS.RecordSession("MANUAL_RESET")
assert_true(skipped == nil, "empty sessions should be skipped")
assert_eq(#profile.sessions, 1, "skipped record should not add rows")

for i = 1, 3 do
  SetTime(400 + (i * 20))
  SetLevel(40 + i)
  NS.resetXPState()
  NS.state.sessionXP = i * 100
  NS.state.events = { { t = GetTime(), xp = i * 100 } }
  SetTime(410 + (i * 20))
  NS.RecordSession("MANUAL_RESET")
end

assert_eq(#profile.sessions, 2, "retention should keep only the latest 2 sessions")
assert_eq(profile.sessions[1].xpGained, 200, "oldest retained session should be the middle insert")
assert_eq(profile.sessions[2].xpGained, 300, "newest retained session should be the latest insert")

print("Insights recording tests passed!")
