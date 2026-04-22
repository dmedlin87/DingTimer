local NS = {}
function NS.BuildAverageSeries(events, ctx)
  local averages = {}
  local cumulativeXP = ctx.baselineSessionXP or 0
  local eventIndex = 1

  local firstSegIdx = ctx.currentSegIdx - (ctx.segmentCount - 1)
  local firstSegStart = ctx.anchor + firstSegIdx * ctx.segSeconds

  local low, high = 1, #events
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if events[mid].t <= firstSegStart then
      low = mid + 1
    else
      high = mid - 1
    end
  end

  if high > 0 and events[high] then
    if events[high].sessionXP then
        cumulativeXP = events[high].sessionXP
    else
        -- If sessionXP is not present, we can't just do cumulativeXP + events[high].xp
        -- because it skips all events from 1 to high - 1!
        -- Actually, wait. Let's see the old code's result.
        cumulativeXP = cumulativeXP + events[high].xp
    end
    print("Initial cumulativeXP:", cumulativeXP)
    eventIndex = high + 1
  end

  for i = 1, ctx.segmentCount do
    local segIdx = ctx.currentSegIdx - (ctx.segmentCount - i)
    local segEnd = ctx.anchor + (segIdx + 1) * ctx.segSeconds
    local pointTime = math.min(segEnd, ctx.now)

    while events[eventIndex] and events[eventIndex].t <= pointTime do
      local event = events[eventIndex]
      if event.sessionXP then
          cumulativeXP = event.sessionXP
      else
          cumulativeXP = cumulativeXP + (event.xp or 0)
      end
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

local events = {
  { t = 5, xp = 50 },
  { t = 10, xp = 100 },
  { t = 15, xp = 150 },
  { t = 20, xp = 200 },
  { t = 30, xp = 300 },
}
local ctx = {
  baselineSessionXP = 0,
  now = 30,
  sessionStart = 0,
  anchor = 0,
  segSeconds = 10,
  currentSegIdx = 2,
  segmentCount = 3
}
local avgs = NS.BuildAverageSeries(events, ctx)
print("Without sessionXP:")
for _, a in ipairs(avgs) do print(a) end

local events2 = {
  { t = 5, xp = 50, sessionXP = 50 },
  { t = 10, xp = 100, sessionXP = 150 },
  { t = 15, xp = 150, sessionXP = 300 },
  { t = 20, xp = 200, sessionXP = 500 },
  { t = 30, xp = 300, sessionXP = 800 },
}
local avgs2 = NS.BuildAverageSeries(events2, ctx)
print("With sessionXP:")
for _, a in ipairs(avgs2) do print(a) end
