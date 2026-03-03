dofile("tests/mocks.lua")

SetProfileIdentity("Analyst", "Azeroth", "MAGE", 70, "Mage")

local NS = {}
LoadAddonFile("DingTimer/Insights.lua", NS)

DingTimerDB = {
  xp = {
    keepSessions = 30,
    profiles = {},
  },
}

local profile = NS.GetProfileStore(true)
profile.sessions = {
  { avgXph = 1000, durationSec = 100, levelStart = 10, levelEnd = 11, moneyNetCopper = 100, zone = "A", reason = "LEVEL_UP" },
  { avgXph = 2000, durationSec = 200, levelStart = 11, levelEnd = 12, moneyNetCopper = 200, zone = "B", reason = "LEVEL_UP" },
  { avgXph = 3000, durationSec = 300, levelStart = 12, levelEnd = 13, moneyNetCopper = 300, zone = "C", reason = "MANUAL_RESET" },
  { avgXph = 4000, durationSec = 400, levelStart = 13, levelEnd = 14, moneyNetCopper = 400, zone = "D", reason = "LOGOUT" },
}

local summary = NS.GetInsightsSummary(3)

assert_eq(summary.totalSessions, 4, "summary should include total count")
assert_near(summary.medianXph, 2500, 0.0001, "median should be middle average for even count")
assert_near(summary.bestXph, 4000, 0.0001, "bestXph should be max")
assert_near(summary.avgLevelTime, 250, 0.0001, "avgLevelTime should be arithmetic mean")
assert_near(summary.trendPct, ((3500 - 1500) / 1500) * 100, 0.0001, "trend should compare newest half vs previous half")

assert_eq(#summary.rows, 3, "row limit should apply")
assert_eq(summary.rows[1].avgXph, 4000, "rows should be newest-first")
assert_eq(summary.rows[2].avgXph, 3000, "rows should be newest-first")
assert_eq(summary.rows[3].avgXph, 2000, "rows should be newest-first")

assert_eq(#summary.chartValues, 4, "chart should include up to 20 recent sessions")
assert_eq(summary.chartValues[1], 1000, "chart should be oldest-to-newest")
assert_eq(summary.chartValues[4], 4000, "chart should be oldest-to-newest")

profile.sessions = {}
local emptySummary = NS.GetInsightsSummary(10)
assert_eq(emptySummary.totalSessions, 0, "empty summary count should be zero")
assert_eq(#emptySummary.rows, 0, "empty summary rows should be empty")
assert_eq(#emptySummary.chartValues, 0, "empty summary chart should be empty")
assert_eq(emptySummary.trendPct, 0, "empty summary trend should be zero")

print("Insights summary tests passed!")
