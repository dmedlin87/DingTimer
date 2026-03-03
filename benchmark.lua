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

local function aggregateSegmentsOld(now, W, S, N, anchor)
  local currentSegIdx = getSegmentIndex(now, anchor, S)
  local firstVisibleIdx = currentSegIdx - N + 1
  local segments = {}

  for _, ev in ipairs(graphState.events) do
    local segIdx = getSegmentIndex(ev.t, anchor, S)
    if segIdx >= firstVisibleIdx and segIdx <= currentSegIdx then
      segments[segIdx] = (segments[segIdx] or 0) + ev.xp
    end
  end

  return segments, currentSegIdx
end

local function aggregateSegmentsNew(now, W, S, N, anchor)
  local currentSegIdx = getSegmentIndex(now, anchor, S)
  local firstVisibleIdx = currentSegIdx - N + 1
  local segments = {}

  for i = #graphState.events, 1, -1 do
    local ev = graphState.events[i]
    local segIdx = getSegmentIndex(ev.t, anchor, S)
    if segIdx < firstVisibleIdx then
      break
    end
    if segIdx <= currentSegIdx then
      segments[segIdx] = (segments[segIdx] or 0) + ev.xp
    end
  end

  return segments, currentSegIdx
end

local anchor = GetTimeVal - 4000
local S = 15
local N = 12
local W = 180 -- 3 minutes

local start = os.clock()
for i = 1, 10000 do
  aggregateSegmentsOld(GetTimeVal, W, S, N, anchor)
end
local t1 = os.clock() - start

local start2 = os.clock()
for i = 1, 10000 do
  aggregateSegmentsNew(GetTimeVal, W, S, N, anchor)
end
local t2 = os.clock() - start2

print("Old:", t1)
print("New:", t2)
