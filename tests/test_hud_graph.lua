dofile("tests/mocks.lua")

local NS = {
  C = { base = "", r = "" },
}

LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/HUDGraph.lua", NS)

it("builds wall-clock rolling XP buckets", function()
  local buckets, peak = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 100, 60, 6)
  assert_eq(6, #buckets, "graph helper should create the requested number of buckets")
  assert_eq(25, buckets[6], "new XP should land in the newest bucket")
  assert_eq(25, peak, "single-bucket graph should report that bucket as the peak")

  local movedBuckets = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 110, 60, 6)
  assert_eq(25, movedBuckets[5], "XP should move left as wall-clock time advances")
  assert_eq(0, movedBuckets[6], "newest bucket should clear when no current XP happened")

  local retainedBuckets = NS.HUDGraph.BuildBuckets({ { t = 100, xp = 25 } }, 160, 60, 6)
  assert_eq(25, retainedBuckets[1], "XP exactly at the rolling-window edge should stay visible")

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
  assert_eq(70, buckets[4], "graph helper should keep older valid gains in their wall-clock bucket")
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

run_tests()
