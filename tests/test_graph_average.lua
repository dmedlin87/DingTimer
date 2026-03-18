require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/GraphMath.lua", "DingTimer", NS)

local averages = NS.BuildAverageSeries(
  {
    { t = 130, xp = 100, sessionXP = 1000 },
    { t = 190, xp = 50, sessionXP = 1050 },
  },
  {
    baselineSessionXP = 900,
    now = 190,
    sessionStart = 0,
    anchor = 0,
    segSeconds = 60,
    currentSegIdx = 3,
    segmentCount = 3
  }
)

assert_near(averages[1], 27000, 0.001, "first visible segment should include pruned session XP")
assert_near(averages[2], 20000, 0.001, "second visible segment should include retained cumulative XP")
assert_near(averages[3], (1050 / 190) * 3600, 0.001, "current segment should use elapsed time up to now")

print("Graph average test passed!")
