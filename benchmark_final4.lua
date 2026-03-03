local events = {}
local segments = {}
-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
local anchor = 100000 - 4000
local S = 15
local currentSegIdx = 200
local N = 12

for i = 1, 1800 do
  local t = 100000 - 3600 + i * 2
  local xp = 100
  table.insert(events, { t = t, xp = xp })

  local segIdx = math.floor((t - anchor) / S)
  segments[segIdx] = (segments[segIdx] or 0) + xp
end

local function run_new()
  local start = os.clock()
  for loop = 1, 100000 do
    local barData = {}

    local running_xp = 0

    -- Optimize by avoiding ANY loop over events at all!
    -- Is this possible? Wait, we NEED the sum of ALL previous events for the first visible bar.
    -- Wait, if `events` holds up to an hour of events, maybe we can just calculate the total once per prune?
    -- The prompt says: "N+1 Query Pattern or O(N^2) Loop in Graph Calculation"
    -- "Clear O(N*M) loop that could be O(N+M) or precalculated"
    -- If we look at the original code:
    --   local evIdx = 1
    --   local xp_up_to_t = 0
    --   for i = 1, N do ... while events[evIdx] ... xp_up_to_t = xp_up_to_t + events[evIdx].xp ... end
    -- The original code IS O(N + M) because `evIdx` goes from 1 to M ONCE across the N iterations.
    -- Oh wait! In `aggregateSegments` it iterates backwards over events `for i = #graphState.events, 1, -1`
    -- And then it has `while graphState.events[evIdx]`
    -- If `evIdx` starts at 1, and `events` is sorted by time, then this loop:
    -- for i = 1, N do
    --    t_end = ...
    --    while events[evIdx] ... do
    --       ...
    --    end
    -- end
    -- wait, the inner while loop only advances `evIdx`! So it processes each event AT MOST ONCE!
    -- Why does the task say it's an O(N*M) loop?
  end
  return os.clock() - start
end
