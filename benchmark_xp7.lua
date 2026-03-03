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

    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    local evIdx = 1

    -- Binary search for the first event index that is <= first visible t_end
    local low, high = 1, #events
    while low <= high do
      local mid = math.floor((low + high) / 2)
      if events[mid].t <= first_t_end then
        evIdx = mid
        low = mid + 1
      else
        high = mid - 1
      end
    end
    -- evIdx is `high`, which is the index of the last event with t <= first_t_end
    if high < 1 then
      evIdx = 1
    else
      evIdx = high
    end

    -- Now sum up to this evIdx.
    -- Wait, if we binary search, we STILL have to sum up from 1 to evIdx.
    -- The summation takes O(E).
    -- Can we just maintain `totalXP` incrementally in graphState?
  end
  return os.clock() - start
end
