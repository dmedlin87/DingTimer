local events = {}
-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
local anchor = 100000 - 4000
for i = 1, 1800 do
  table.insert(events, { t = 100000 - 3600 + i * 2, xp = 100 })
end

local function run_binary()
  local N = 12
  local S = 15
  local currentSegIdx = 200

  local start = os.clock()
  for loop = 1, 10000 do
    local barData = {}

    -- Binary search for the first event index that is <= first visible t_end
    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    local low, high = 1, #events
    local evIdx = 1
    while low <= high do
      local mid = math.floor((low + high) / 2)
      if events[mid].t <= first_t_end then
        evIdx = mid
        low = mid + 1
      else
        high = mid - 1
      end
    end
    -- Now evIdx points to the last event <= first_t_end. Wait, evIdx from binary search is `high`.
    evIdx = high
    if evIdx < 1 then evIdx = 1 end

    local xp_up_to_t = 0
    -- This still requires summing from 1 to evIdx, which is O(E).
    for i = 1, evIdx do
      xp_up_to_t = xp_up_to_t + events[i].xp
    end

    for i = 1, N do
      local segIdx = currentSegIdx - (N - i)
      local t_end = anchor + (segIdx + 1) * S

      while events[evIdx + 1] and events[evIdx + 1].t <= t_end do
        evIdx = evIdx + 1
        xp_up_to_t = xp_up_to_t + events[evIdx].xp
      end

      barData[i] = xp_up_to_t
    end
  end
  return os.clock() - start
end

print("Binary search time:", run_binary())
