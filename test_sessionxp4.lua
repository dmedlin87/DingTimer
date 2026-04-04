local NS = {}
function NS.BuildAverageSeries_Old(events, ctx)
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
    cumulativeXP = events[high].sessionXP or (cumulativeXP + events[high].xp)
    print("Old Initial cumulativeXP:", cumulativeXP)
    eventIndex = high + 1
  end

  for i = 1, ctx.segmentCount do
    local segIdx = ctx.currentSegIdx - (ctx.segmentCount - i)
    local segEnd = ctx.anchor + (segIdx + 1) * ctx.segSeconds
    local pointTime = math.min(segEnd, ctx.now)

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

function NS.BuildAverageSeries_Fixed(events, ctx)
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
        -- If sessionXP is not present, we must sum up all events from 1 to high.
        for i = 1, high do
            cumulativeXP = cumulativeXP + (events[i].xp or 0)
        end
    end
    print("Fixed Initial cumulativeXP:", cumulativeXP)
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
  currentSegIdx = 3,  -- Make currentSegIdx higher so high > 0
  segmentCount = 3
}

print("Old:")
NS.BuildAverageSeries_Old(events, ctx)
print("Fixed:")
NS.BuildAverageSeries_Fixed(events, ctx)
