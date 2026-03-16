local graphState = {
  events = {},
  lastPrunedSessionXP = 0,
  totalXP = 0,
  dirty = false
}

local function pruneGraphEvents(timestamp)
    -- Stub
end

local function GraphFeedXP_original(delta, timestamp)
  if delta <= 0 then
    return
  end

  pruneGraphEvents(timestamp)

  local lastEvent = graphState.events[#graphState.events]
  local sessionXP = graphState.lastPrunedSessionXP + delta
  if lastEvent and lastEvent.sessionXP then
    sessionXP = lastEvent.sessionXP + delta
  end

  table.insert(graphState.events, {
    t = timestamp,
    xp = delta,
    sessionXP = sessionXP,
  })
  graphState.totalXP = graphState.totalXP + delta
  graphState.dirty = true
end

local function GraphFeedXP_optimized(delta, timestamp)
  if delta <= 0 then
    return
  end

  pruneGraphEvents(timestamp)

  local events = graphState.events
  local len = #events
  local lastEvent = events[len]
  local sessionXP = graphState.lastPrunedSessionXP + delta
  if lastEvent and lastEvent.sessionXP then
    sessionXP = lastEvent.sessionXP + delta
  end

  events[len + 1] = {
    t = timestamp,
    xp = delta,
    sessionXP = sessionXP,
  }
  graphState.totalXP = graphState.totalXP + delta
  graphState.dirty = true
end

local MAX_ITER = 5000000

graphState.events = {}
local start1 = os.clock()
for i = 1, MAX_ITER do
    GraphFeedXP_original(10, i)
end
local end1 = os.clock()
local time1 = end1 - start1
print(string.format("Original time: %.4f seconds", time1))

graphState.events = {}
local start2 = os.clock()
for i = 1, MAX_ITER do
    GraphFeedXP_optimized(10, i)
end
local end2 = os.clock()
local time2 = end2 - start2
print(string.format("Optimized time: %.4f seconds", time2))

print(string.format("Improvement: %.2fx faster", time1 / time2))
