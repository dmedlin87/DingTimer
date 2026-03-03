local events = {}
-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
local anchor = 100000 - 4000
for i = 1, 1800 do
  table.insert(events, { t = 100000 - 3600 + i * 2, xp = 100 })
end

local function run_new()
  local N = 12
  local S = 15
  local currentSegIdx = 200

  local start = os.clock()
  for loop = 1, 10000 do
    local barData = {}

    local xp_up_to_t = 0
    local evIdx = 1

    -- Optimize by pre-accumulating all XP up to the first visible bar
    -- BUT we don't start from 1 every time! Wait, RedrawGraph is a single function call.
    -- Inside RedrawGraph, the loop over N bars starts at `i=1`
    -- The OLD code DID THIS:
    --   local evIdx = 1
    --   local xp_up_to_t = 0
    --   for i = 1, N do
    --     local t_end = ...
    --     while events[evIdx] and events[evIdx].t <= t_end do
    --       xp_up_to_t = xp_up_to_t + events[evIdx].xp
    --       evIdx = evIdx + 1
    --     end
    --     barData[i] = xp_up_to_t
    --   end
    -- Wait... does the OLD code start from `evIdx = 1` inside the `for i=1, N` loop?
    -- NO! It starts `evIdx = 1` BEFORE the `for i=1, N` loop!
    -- Which means it's ALREADY O(E + N)!
    -- It only scans the events ONCE across all N bars!
  end
  return os.clock() - start
end
