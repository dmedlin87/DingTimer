dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/GraphMath.lua", "DingTimer", NS)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.ComputeBarCount

it("ComputeBarCount: standard 300s window → 20 bars", function()
  local bars = NS.ComputeBarCount(300, 15, 10, 60)
  assert_equal(20, bars)
end)

it("ComputeBarCount: short window clamps to minBars", function()
  local bars = NS.ComputeBarCount(10, 15, 10, 60)
  assert_equal(10, bars)
end)

it("ComputeBarCount: very large window clamps to maxBars", function()
  local bars = NS.ComputeBarCount(10000, 15, 10, 60)
  assert_equal(60, bars)
end)

it("ComputeBarCount: 3600s window → 60 bars (exact)", function()
  local bars = NS.ComputeBarCount(3600, 15, 10, 60)
  assert_equal(60, bars)
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.ComputeSegmentSeconds

it("ComputeSegmentSeconds: 300s / 20 bars = 15s per bar", function()
  local seg = NS.ComputeSegmentSeconds(300, 20)
  assert_near(seg, 15, 0.001, "segment duration should be 15s")
end)

it("ComputeSegmentSeconds: 3600s / 60 bars = 60s per bar", function()
  local seg = NS.ComputeSegmentSeconds(3600, 60)
  assert_near(seg, 60, 0.001, "segment duration should be 60s")
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.GetSegmentIndex

it("GetSegmentIndex: event at anchor falls in segment 0", function()
  assert_equal(0, NS.GetSegmentIndex(100, 100, 15))
end)

it("GetSegmentIndex: event exactly one segment later → segment 1", function()
  assert_equal(1, NS.GetSegmentIndex(115, 100, 15))
end)

it("GetSegmentIndex: event just before second boundary → still segment 0", function()
  -- 114.9 from anchor = floor(14.9/15) = 0
  assert_equal(0, NS.GetSegmentIndex(214.9, 200, 15))
end)

it("GetSegmentIndex: negative offset → negative segment index", function()
  local idx = NS.GetSegmentIndex(80, 100, 15)
  assert_true(idx < 0, "events before anchor should produce negative indices")
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.AggregateVisibleSegments

it("AggregateVisibleSegments: single event lands in current segment", function()
  local events = { { t = 105, xp = 500 } }
  local anchor = 100
  local segSeconds = 15
  local segCount = 4
  local now = 110
  local segs, currentSegIdx = NS.AggregateVisibleSegments(events, now, segSeconds, segCount, anchor)
  assert_equal(0, currentSegIdx, "now=110 is in segment 0 relative to anchor=100")
  assert_equal(500, segs[currentSegIdx], "the single event should aggregate into segment 0")
end)

it("AggregateVisibleSegments: event outside window is excluded", function()
  local events = {
    { t = 50, xp = 1000 },  -- outside 4-bar window from now=200
    { t = 185, xp = 200 },  -- inside
  }
  local anchor = 100
  local segSeconds = 15
  local segCount = 4
  local now = 200
  -- current segment = floor((200-100)/15) = 6
  -- first visible = 6 - 3 = 3
  -- event at t=50: segIdx = floor((50-100)/15) = floor(-3.33) = -4, excluded
  -- event at t=185: segIdx = floor((185-100)/15) = floor(5.67) = 5, included
  local segs = NS.AggregateVisibleSegments(events, now, segSeconds, segCount, anchor)
  assert_equal(nil, segs[-4], "very old event should not appear")
  assert_equal(200, segs[5], "recent event should aggregate into segment 5")
end)

it("AggregateVisibleSegments: two events in same segment accumulate", function()
  local events = {
    { t = 105, xp = 300 },
    { t = 110, xp = 700 },
  }
  local anchor = 100
  local segSeconds = 15
  local segCount = 3
  local now = 112
  local segs, currentSegIdx = NS.AggregateVisibleSegments(events, now, segSeconds, segCount, anchor)
  assert_equal(1000, segs[currentSegIdx], "two XP events in the same segment should sum")
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.ComputeHistoryPeakXPH

it("ComputeHistoryPeakXPH: single event gives correct XPH", function()
  -- 1 event with 900 XP in a 15s segment → 900/15 * 3600 = 216000 XPH
  local events = { { t = 200, xp = 900 } }
  local anchor = 100
  local segSeconds = 15
  local now = 300
  local currentSegIdx = NS.GetSegmentIndex(now, anchor, segSeconds)
  local peak = NS.ComputeHistoryPeakXPH(events, now, anchor, segSeconds, currentSegIdx, 3600)
  assert_near(peak, 216000, 0.001, "900 XP in 15s segment = 216000 XP/hr")
end)

it("ComputeHistoryPeakXPH: event outside retention window is excluded", function()
  local events = { { t = 0, xp = 99999 } }
  local anchor = 0
  local segSeconds = 60
  local now = 10000  -- event at t=0 is > 3600s ago
  local currentSegIdx = NS.GetSegmentIndex(now, anchor, segSeconds)
  local peak = NS.ComputeHistoryPeakXPH(events, now, anchor, segSeconds, currentSegIdx, 3600)
  assert_equal(0, peak, "event older than retention window must be excluded")
end)

it("ComputeHistoryPeakXPH: returns highest of multiple segments", function()
  -- seg A: 600 XP / 15s = 144000 XPH
  -- seg B: 300 XP / 15s = 72000 XPH
  local anchor = 0
  local segSeconds = 15
  local events = {
    { t = 5,  xp = 600 },   -- segment 0
    { t = 20, xp = 300 },   -- segment 1
  }
  local now = 60
  local currentSegIdx = NS.GetSegmentIndex(now, anchor, segSeconds)
  local peak = NS.ComputeHistoryPeakXPH(events, now, anchor, segSeconds, currentSegIdx, 3600)
  assert_near(peak, 144000, 0.001, "peak should be from the higher-XP segment")
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.BuildAverageSeries

it("BuildAverageSeries: empty events returns all zeros", function()
  local avgs = NS.BuildAverageSeries({}, {
    baselineSessionXP = 0,
    now = 300,
    sessionStart = 0,
    anchor = 0,
    segSeconds = 15,
    currentSegIdx = 20,
    segmentCount = 5
  })
  for i = 1, 5 do
    assert_equal(0, avgs[i], "empty event list should produce zero averages")
  end
end)

it("BuildAverageSeries: sessionXP accumulates correctly with pruned baseline", function()
  -- From the original test: baseline=900, one event at t=130 with sessionXP=1000
  local avgs = NS.BuildAverageSeries(
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
  assert_near(avgs[1], 27000, 0.001, "first bar: 900 pruned XP / 60s * 3600 = 54000... wait, see note")
  assert_near(avgs[3], (1050 / 190) * 3600, 0.001, "last bar: uses all XP / elapsed")
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- NS.ResolveGraphScaleMax

it("ResolveGraphScaleMax: visible mode adds 12% headroom over visible peak", function()
  -- max(80000, 60000) * 1.12 = 89600
  local max = NS.ResolveGraphScaleMax("visible", 80000, 60000, 140000, 100000)
  assert_near(max, 89600, 0.001, "visible mode: visible peak + 12% headroom")
end)

it("ResolveGraphScaleMax: session mode uses history peak if it is higher", function()
  -- max(80000, 60000, 140000) * 1.12 = 156800
  local max = NS.ResolveGraphScaleMax("session", 80000, 60000, 140000, 100000)
  assert_near(max, 156800, 0.001, "session mode: highest of all peaks + 12%")
end)

it("ResolveGraphScaleMax: fixed mode returns configured cap exactly", function()
  local max = NS.ResolveGraphScaleMax("fixed", 80000, 60000, 140000, 100000)
  assert_equal(100000, max, "fixed mode: exact configured cap")
end)

it("ResolveGraphScaleMax: auto alias maps to visible", function()
  -- max(50000, 40000) * 1.12 = 56000
  local max = NS.ResolveGraphScaleMax("auto", 50000, 40000, 100000, 75000)
  assert_near(max, 56000, 0.001, "auto should alias to visible scale")
end)

it("ResolveGraphScaleMax: zero peaks return at least 1", function()
  local max = NS.ResolveGraphScaleMax("visible", 0, 0, 0, 0)
  assert_true(max >= 1, "scale max must be at least 1 even with no data")
end)

it("ResolveGraphScaleMax: fixed mode below minimum clamps up", function()
  -- ClampGraphFixedMax clamps to 10000 minimum
  local max = NS.ResolveGraphScaleMax("fixed", 0, 0, 0, 1000)
  assert_equal(10000, max, "fixed mode below minimum must be clamped to 10000")
end)

run_tests()
