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
    -- Optimize by avoiding full sum using backwards sum from the precomputed `segments`
    -- The precomputed `segments` gives us the sum of XP for each segment.
    -- If we know the sum of all events in the visible range, and we know we only
    -- need `xp_up_to_t` for EACH bar, how do we get `xp_up_to_t` for `i=1`?
    -- It's exactly the total xp of all events before the visible bars!
    -- Can we compute the sum of all events BEFORE `first_t_end` using binary search and sum?

    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    -- Binary search for the first event index that is <= first visible t_end
    local low, high = 1, #events
    while low <= high do
      local mid = math.floor((low + high) / 2)
      if events[mid].t <= first_t_end then
        low = mid + 1
      else
        high = mid - 1
      end
    end
    -- high is the index of the last event <= first_t_end
    local evIdx = high
    if evIdx < 1 then evIdx = 0 end

    for i = 1, evIdx do
      running_xp = running_xp + events[i].xp
    end

    barData[1] = running_xp

    for i = 2, N do
      local segIdx = currentSegIdx - (N - i + 1)
      local prev_segIdx = currentSegIdx - (N - i + 2)
      local seg_xp = segments[segIdx] or 0
      -- This assumes `segments` ONLY contains XP in the `segIdx`.
      -- If `segments` already gives us the EXACT XP for that segIdx, we just ADD it!
      running_xp = running_xp + seg_xp
      barData[i] = running_xp
    end
  end
  return os.clock() - start
end

print("New:", run_new())
