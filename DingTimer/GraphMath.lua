local _, NS = ...

local floor = math.floor
local min = math.min
local max = math.max

--- Pure graph math functions, extracted from UI_XPGraphWindow.lua.
--- All functions are stateless and take explicit parameters — no module-level state.
--- This makes them easily testable outside the WoW environment.

-- ──────────────────────────────────────────────────────────────────────────────
-- Segment geometry

--- Computes the number of bars to draw based on the window size.
--- @param windowSeconds number The total duration of the graph's time window in seconds.
--- @param minSegmentSeconds number The minimum duration of a single segment.
--- @param minBars number Minimum bar count.
--- @param maxBars number Maximum bar count.
--- @return number The constrained number of bars to display.
function NS.ComputeBarCount(windowSeconds, minSegmentSeconds, minBars, maxBars)
  local raw = floor(windowSeconds / minSegmentSeconds)
  return max(minBars, min(maxBars, raw))
end

--- Calculates the duration of a single standard segment (bar) in seconds.
--- @param windowSeconds number The total duration of the graph's time window.
--- @param barCount number The number of bars to display.
--- @return number The duration of one segment in seconds.
function NS.ComputeSegmentSeconds(windowSeconds, barCount)
  return windowSeconds / barCount
end

--- Determines which segment block a specific timestamp belongs to.
--- @param timestamp number The exact time of the event.
--- @param anchor number The starting reference time grid anchor.
--- @param segSeconds number The duration of one segment.
--- @return number The zero-indexed segment position.
function NS.GetSegmentIndex(timestamp, anchor, segSeconds)
  return floor((timestamp - anchor) / segSeconds)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Segment aggregation (shared single-pass core)

local function aggregateGraphBuckets(events, now, segSeconds, segmentCount, anchor, currentSegIdx, maxRetentionSeconds)
  events = events or {}

  local currentIndex = currentSegIdx or NS.GetSegmentIndex(now, anchor, segSeconds)
  local firstVisibleIdx = currentIndex - segmentCount + 1
  local firstRetainedIdx = maxRetentionSeconds and NS.GetSegmentIndex(now - maxRetentionSeconds, anchor, segSeconds) or firstVisibleIdx
  local visibleSegments = {}
  local historySegmentXP = maxRetentionSeconds and {} or nil

  for i = #events, 1, -1 do
    local ev = events[i]
    local segIdx = NS.GetSegmentIndex(ev.t, anchor, segSeconds)
    if segIdx < firstRetainedIdx then
      break
    end
    if segIdx <= currentIndex then
      if segIdx >= firstVisibleIdx then
        visibleSegments[segIdx] = (visibleSegments[segIdx] or 0) + ev.xp
      end
      if historySegmentXP then
        historySegmentXP[segIdx] = (historySegmentXP[segIdx] or 0) + ev.xp
      end
    end
  end

  local historyPeak = 0
  if historySegmentXP then
    for _, xp in pairs(historySegmentXP) do
      local xph = (xp / segSeconds) * 3600
      if xph > historyPeak then
        historyPeak = xph
      end
    end
  end

  return visibleSegments, currentIndex, historyPeak
end

--- Aggregates historical XP events into buckets for the visible graph segments.
--- @param events table The list of XP events: each has fields {t, xp}.
--- @param now number The current time.
--- @param segSeconds number The size of a single segment bucket.
--- @param segmentCount number The total number of visible segments.
--- @param anchor number The origin timestamp grid.
--- @return table, number A sparse array of XP per segment and the index of the current segment.
function NS.AggregateVisibleSegments(events, now, segSeconds, segmentCount, anchor)
  local segments, currentSegIdx = aggregateGraphBuckets(events, now, segSeconds, segmentCount, anchor)
  return segments, currentSegIdx
end

--- Computes the peak XP/hr across the retained history window.
--- @param events table The list of XP events: each has fields {t, xp}.
--- @param now number The current time.
--- @param anchor number The origin timestamp grid.
--- @param segSeconds number The size of a single segment bucket.
--- @param currentSegIdx number The index of the current active segment.
--- @param maxRetentionSeconds number How far back to look (e.g. 3600 for 60 min).
--- @return number The highest per-segment XP/hr observed in the retention window.
function NS.ComputeHistoryPeakXPH(events, now, anchor, segSeconds, currentSegIdx, maxRetentionSeconds)
  local _, _, peak = aggregateGraphBuckets(events, now, segSeconds, 1, anchor, currentSegIdx, maxRetentionSeconds)
  return peak
end

--- Computes both visible segments and history peak in one traversal of the event list.
--- @param events table The list of XP events: each has fields {t, xp}.
--- @param now number The current time.
--- @param segSeconds number The size of a single segment bucket.
--- @param segmentCount number The total number of visible segments.
--- @param anchor number The origin timestamp grid.
--- @param maxRetentionSeconds number How far back to look for history peak.
--- @return table Visible segments (sparse array of XP per segment index).
--- @return number currentSegIdx The index of the current active segment.
--- @return number historyPeak The highest per-segment XP/hr in the retention window.
function NS.AggregateAndComputePeak(events, now, segSeconds, segmentCount, anchor, maxRetentionSeconds)
  return aggregateGraphBuckets(events, now, segSeconds, segmentCount, anchor, nil, maxRetentionSeconds)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Session average overlay

--- Builds the rolling session-average XP/hr series aligned to the visible bars.
--- Uses a binary search to start from the correct event, then walks forward
--- accumulating cumulative XP to compute the per-point average.
--- @param events table Events sorted by time: each has {t, xp, sessionXP?}.
--- @param ctx table Grouped parameters for session aggregation. Must contain:
---   baselineSessionXP: number Cumulative session XP from pruned-away events.
---   now: number The current time.
---   sessionStart: number The time the current session began.
---   anchor: number The origin timestamp grid.
---   segSeconds: number Duration of one segment.
---   currentSegIdx: number Index of the current active segment.
---   segmentCount: number Total number of visible bars.
--- @return table Array of per-bar average XP/hr values (1..segmentCount).
function NS.BuildAverageSeries(events, ctx)
  local averages = {}
  local cumulativeXP = ctx.baselineSessionXP or 0
  local eventIndex = 1

  local firstSegIdx = ctx.currentSegIdx - (ctx.segmentCount - 1)
  local firstSegStart = ctx.anchor + firstSegIdx * ctx.segSeconds

  -- Binary search: find last event before the visible window.
  -- Note: events[i].sessionXP is an optional pre-computed cumulative XP field.
  -- Core_DingTimer currently stores events as {t, xp} without sessionXP, so the
  -- fallback path (cumulativeXP + event.xp) is always taken. The sessionXP field
  -- is reserved for a future optimisation where callers pre-stamp cumulative totals.
  local low, high = 1, #events
  while low <= high do
    local mid = floor((low + high) / 2)
    if events[mid].t <= firstSegStart then
      low = mid + 1
    else
      high = mid - 1
    end
  end

  if high > 0 and events[high] then
    cumulativeXP = events[high].sessionXP or (cumulativeXP + events[high].xp)
    eventIndex = high + 1
  end

  for i = 1, ctx.segmentCount do
    local segIdx = ctx.currentSegIdx - (ctx.segmentCount - i)
    local segEnd = ctx.anchor + (segIdx + 1) * ctx.segSeconds
    local pointTime = min(segEnd, ctx.now)

    while events[eventIndex] and events[eventIndex].t <= pointTime do
      local event = events[eventIndex]
      cumulativeXP = event.sessionXP or (cumulativeXP + (event.xp or 0))
      eventIndex = eventIndex + 1
    end

    local elapsed = pointTime - ctx.sessionStart
    if elapsed < 1 then
      elapsed = 1
    end
    averages[i] = (cumulativeXP / elapsed) * 3600
  end

  return averages
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Scale resolution

--- Determines the maximum Y-axis value for the graph depending on the current scale mode.
--- @param mode string The user's active scale mode ("visible", "session", "fixed").
--- @param visiblePeak number The highest bar value currently on screen.
--- @param avgPeak number The highest rolling average value currently on screen.
--- @param historyPeak number The overall highest retained peak in recent history.
--- @param fixedMax number The user's custom manual maximum, if any.
--- @return number The resulting maximum ceiling to draw the graph up to.
function NS.ResolveGraphScaleMax(mode, visiblePeak, avgPeak, historyPeak, fixedMax)
  local normalized = NS.NormalizeGraphScaleMode(mode)
  if normalized == "fixed" then
    return max(NS.ClampGraphFixedMax(fixedMax), 1)
  end

  local peak = max(visiblePeak or 0, avgPeak or 0, 1)
  if normalized == "session" then
    peak = max(peak, historyPeak or 0)
  end

  return max(1, peak * 1.12)
end
