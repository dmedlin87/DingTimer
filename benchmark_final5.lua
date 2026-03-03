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

  -- If we can pre-calculate the total xp up to t_end without iterating, it would be O(1) inside RedrawGraph
  -- Wait, graphState.events is modified ONLY when new XP is added (GraphFeedXP) or pruned (pruneGraphEvents)
  -- Or when GraphReset is called.
  -- Can we maintain `graphState.totalXP` ?
  -- If graphState.totalXP is maintained, then we don't have to start from evIdx=1.
  -- But totalXP is the sum of ALL events. We need xp_up_to_t_end, which might be less than totalXP if there are events in the future?
  -- Wait, the events are appended chronologically. `t_end` for the RIGHTMOST bar (i=N) is `currentSegIdx + 1`, which is effectively `>= now`.
  -- So for the rightmost bar, `xp_up_to_t` is EXACTLY the sum of ALL events up to now!
  -- For earlier bars, it's just `total_xp - xp_in_later_segments`!
  -- We already HAVE `segments` from `aggregateSegments`!
  -- `segments` array has the XP for each segment.

  -- Let's test using `segments`!
end
