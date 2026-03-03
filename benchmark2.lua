local NS = {}
local GetTimeVal = 100000
function GetTime() return GetTimeVal end

local graphState = { events = {} }

local function getSegmentIndex(timestamp, anchor, segSeconds)
  return math.floor((timestamp - anchor) / segSeconds)
end

-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
for i = 1, 1800 do
  table.insert(graphState.events, { t = GetTimeVal - 3600 + i * 2, xp = 100 })
end

local function computeBarCount(windowSeconds)
  return 12
end

local function computeSegmentSeconds(windowSeconds)
  return 15
end

local function aggregateSegments(now, W, S, N, anchor)
  local currentSegIdx = getSegmentIndex(now, anchor, S)
  local segments = {}
  -- Mocked out, just return empty for benchmark
  return segments, currentSegIdx
end

local function testOld(now, W, S, N, anchor)
  local segments, currentSegIdx = aggregateSegments(now, W, S, N, anchor)
  local barData = {}
  local sessionStart = anchor

  local evIdx = 1
  local xp_up_to_t = 0

  -- The actual old code logic had a while loop inside the for loop
  for i = 1, N do
    local segIdx = currentSegIdx - (N - i)
    local xp = segments[segIdx] or 0
    local xph = (xp / S) * 3600

    local t_end = anchor + (segIdx + 1) * S

    while graphState.events[evIdx] and graphState.events[evIdx].t <= t_end do
      xp_up_to_t = xp_up_to_t + graphState.events[evIdx].xp
      evIdx = evIdx + 1
    end

    local elapsed = t_end - sessionStart
    if elapsed < 1 then elapsed = 1 end
    local avgXph = (xp_up_to_t / elapsed) * 3600

    barData[i] = { xp = xp, xph = xph, avgXph = avgXph, segIdx = segIdx }
  end
end

local anchor = GetTimeVal - 4000
local S = 15
local N = 12
local W = 180 -- 3 minutes

local start = os.clock()
for i = 1, 10000 do
  testOld(GetTimeVal, W, S, N, anchor)
end
local t1 = os.clock() - start

print("Old:", t1)
