local events = {}
local segments = {}
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
  for loop = 1, 100000 do
    local barData = {}

    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    local xp_up_to_t = 0
    local evIdx = 1

    -- Optimize by stopping at the first visible bar t_end
    -- This is still O(K) where K is number of older events
    while events[evIdx] and events[evIdx].t <= first_t_end do
      xp_up_to_t = xp_up_to_t + events[evIdx].xp
      evIdx = evIdx + 1
    end

    -- Now, for the visible bars, we can just use the pre-aggregated `segments` OR continue the while loop.
    -- Wait, `aggregateSegments` iterates backwards to compute the segments!
    -- So `segments` ALREADY has the `xp` for each visible segment!
    -- We can just do:
    for i = 1, N do
      local segIdx = currentSegIdx - (N - i)
      -- Oh wait, we need total XP up to `t_end`, which includes XP in the segment!
      -- If we use `segments[segIdx]`, it is EXACTLY the sum of `events[evIdx].xp` for events in this segment!
      local seg_xp = segments[segIdx] or 0

      -- Wait, if we just do:
      -- xp_up_to_t = xp_up_to_t + seg_xp
      -- Is that correct?
      -- The while loop exactly does this!
      -- But doing it with the while loop is ALREADY fast since `evIdx` just goes up to the end!
    end
  end
  return os.clock() - start
end
