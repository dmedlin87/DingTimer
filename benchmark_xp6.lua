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

    local xp_up_to_t = 0
    local evIdx = 1

    -- Count up to the first visible bar t_end
    -- O(K) where K is the number of events before the visible bars
    -- In worst case K is all events, same as backwards iterating in worst case K is 0
    while events[evIdx] and events[evIdx].t <= first_t_end do
      xp_up_to_t = xp_up_to_t + events[evIdx].xp
      evIdx = evIdx + 1
    end

    barData[1] = xp_up_to_t

    for i = 2, N do
      local segIdx = currentSegIdx - (N - i)
      local t_end = anchor + (segIdx + 1) * S

      while events[evIdx] and events[evIdx].t <= t_end do
        xp_up_to_t = xp_up_to_t + events[evIdx].xp
        evIdx = evIdx + 1
      end

      barData[i] = xp_up_to_t
    end
  end
  return os.clock() - start
end

print("Incremental forwards:", run_new())
