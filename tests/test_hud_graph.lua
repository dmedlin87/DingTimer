dofile("tests/mocks.lua")

local NS = {
  C = { base = "", r = "" },
}

LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/HUDGraph.lua", NS)

it("builds stable XP buckets anchored to the newest gain", function()
  local buckets, peak = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 100, 60, 6)
  assert_eq(6, #buckets, "graph helper should create the requested number of buckets")
  assert_eq(25, buckets[6], "new XP should land in the newest bucket")
  assert_eq(25, peak, "single-bucket graph should report that bucket as the peak")

  local idleBuckets = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 110, 60, 6)
  assert_eq(25, idleBuckets[6], "XP should stay in place while only wall-clock time advances")
  assert_eq(0, idleBuckets[5], "older buckets should not fill from idle heartbeat drift")

  local retainedBuckets = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 160, 60, 6)
  assert_eq(25, retainedBuckets[6], "XP exactly at the rolling-window edge should stay visible without idle drift")

  local expiredBuckets, expiredPeak = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 161, 60, 6)
  assert_eq(0, expiredBuckets[1], "XP older than the rolling window should drop out")
  assert_eq(0, expiredPeak, "expired-only graph should clear the peak")
end)

it("sums same-slice gains and ignores invalid events", function()
  local buckets, peak = NS.HUDGraph.BuildBuckets({
    { t = 103, xp = 15 },
    { t = 105, xp = 10 },
    { t = 89, xp = 70 },
    { t = 111, xp = 99 },
    { t = 100, xp = "bad" },
    { t = "bad", xp = 20 },
    { t = 90, xp = -5 },
    false,
    { xp = 5 },
    { t = 108 },
  }, 110, 60, 6)

  assert_eq(25, buckets[6], "graph helper should sum multiple valid gains in the same bucket")
  assert_eq(70, buckets[5], "graph helper should keep older valid gains in their newest-gain-relative bucket")
  assert_eq(70, peak, "graph helper should ignore corrupt events when computing the peak")
end)

it("normalizes invalid window and bucket inputs", function()
  local buckets, peak = NS.HUDGraph.BuildBuckets({ { t = 10, xp = 12 } }, 10, 0, 0)
  assert_eq(18, #buckets, "invalid bucket counts should fall back to the HUD graph default")
  assert_eq(12, buckets[18], "invalid windows should normalize to a one-second live window")
  assert_eq(12, peak, "normalized graph should still count valid current XP")

  local expiredBuckets, expiredPeak = NS.HUDGraph.BuildBuckets({ { t = 10, xp = 12 } }, 12, -30, -2)
  assert_eq(18, #expiredBuckets, "negative bucket counts should fall back to the HUD graph default")
  assert_eq(0, expiredPeak, "negative windows should normalize instead of retaining stale XP")
end)

it("formats bucket ranges and keeps the compatibility wrapper", function()
  assert_eq("Latest 10s", NS.HUDGraph.FormatBucketRange({ index = 6, count = 6, windowSeconds = 60 }), "newest bucket should use latest wording")
  assert_eq("10s-20s ago", NS.HUDGraph.FormatBucketRange({ index = 5, count = 6, windowSeconds = 60 }), "older buckets should use wall-clock ago wording")
  assert_eq("Rolling window bucket", NS.HUDGraph.FormatBucketRange({ index = 1, count = 6, windowSeconds = 0 }), "invalid window labels should stay generic")

  local buckets, peak = NS.BuildXPGraphBuckets({ { t = 20, xp = 5 } }, 20, 60, 6)
  assert_eq(5, buckets[6], "legacy graph helper wrapper should delegate to HUDGraph")
  assert_eq(5, peak, "legacy graph helper wrapper should return the delegated peak")
end)

it("builds and labels rolling gold buckets", function()
  local buckets, peak = NS.BuildMoneyGraphBuckets({
    { t = 20, money = 10000 },
    { t = 10, money = 2500 },
    { t = 9, xp = 999 },
  }, 20, 60, 6)

  assert_eq(10000, buckets[6], "money graph helper should read money amounts")
  assert_eq(2500, buckets[5], "money graph helper should keep older money gains in relative buckets")
  assert_eq(10000, peak, "money graph helper should ignore XP-only events")

  ClearTooltip()
  NS.HUDGraph.ShowTooltip({
    _dingGraphBucket = {
      index = 6,
      count = 6,
      amount = 10000,
      peak = 10000,
      windowSeconds = 60,
      valueKey = "money",
    },
  })

  local tooltipLines = GetTooltipLines()
  assert_true(GameTooltip:IsShown(), "money graph hover should show a tooltip")
  assertStringMatch("DingTimer Gold", tooltipLines[1], "money graph tooltip should identify gold tracking")
  assertStringMatch("+1|cffffd700g|r", tooltipLines[2], "money graph tooltip should format gold bucket income")
  assertStringMatch("Peak bucket +1|cffffd700g|r", tooltipLines[4], "money graph tooltip should format the gold peak")
end)

run_tests()
