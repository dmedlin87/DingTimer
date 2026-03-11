require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)

local averages = NS.BuildGraphAverageSeriesForTest(
  {
    { t = 130, xp = 100, sessionXP = 1000 },
    { t = 190, xp = 50, sessionXP = 1050 },
  },
  900,
  190,
  0,
  0,
  60,
  3,
  3
)

assert_near(averages[1], 27000, 0.001, "first visible segment should include pruned session XP")
assert_near(averages[2], 20000, 0.001, "second visible segment should include retained cumulative XP")
assert_near(averages[3], (1050 / 190) * 3600, 0.001, "current segment should use elapsed time up to now")

print("Graph average test passed!")
