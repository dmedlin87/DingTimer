local events = {}
-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
local anchor = 100000 - 4000
for i = 1, 1800 do
  table.insert(events, { t = 100000 - 3600 + i * 2, xp = 100 })
end

local function run_old()
  local N = 12
  local S = 15
  local currentSegIdx = 200

  local start = os.clock()
  for loop = 1, 100000 do
    local barData = {}
    local evIdx = 1
    local xp_up_to_t = 0

    for i = 1, N do
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

local function run_new()
  local N = 12
  local S = 15
  local currentSegIdx = 200

  local start = os.clock()
  for loop = 1, 100000 do
    local barData = {}

    -- Optimize by pre-calculating index for first visible bar using binary search
    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    -- Fast path: find event index
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
    if evIdx < 0 then evIdx = 0 end

    -- How do we compute xp_up_to_t? It requires iterating all 1..evIdx to sum them!
    -- O(E) again!
    -- Is it possible that `xp_up_to_t` can be calculated incrementally over multiple RedrawGraph calls?
    -- No, `RedrawGraph` is stateless because events can be added or pruned.
    -- Wait, wait! `segments` already contains the sum of xp for the VISIBLE bars!
    -- `aggregateSegments` returns a table `segments` where keys are `segIdx` and values are `xp` in that segment.
    -- We can just compute `total_session_xp_before_first_visible_bar` ONCE, and then ADD `segments[segIdx]` for each bar!

  end
  return os.clock() - start
end
