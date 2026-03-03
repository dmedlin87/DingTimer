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
  for loop = 1, 10000 do
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
  for loop = 1, 10000 do
    local barData = {}

    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    -- Optimize by pre-accumulating all XP up to the first visible bar using binary search
    -- Or we can just calculate total XP, and then iterate backwards? No, we need xp_up_to_t for EACH bar.
    -- Wait, aggregateSegments iterates backwards to get segments! We have `segments` array.
    -- If we have total session XP, we can just work backwards, or we can binary search to find `evIdx` and compute xp.
    -- But since we need running total, an O(log N) binary search for each bar? No, we need total XP.
    -- If we can't maintain total XP because of pruning, we still HAVE to sum up all events from 1.
    -- But wait, `pruneGraphEvents` drops events older than `now - 3600`.
    -- `avgXph` is defined as: `(xp_up_to_t / elapsed) * 3600`.
    -- If events are pruned, then `xp_up_to_t` is the sum of *retained* events!
    -- So `xp_up_to_t` is inherently just the sum of events currently in the `events` table!
    -- Since we iterate `for i = 1, N`, we can just compute the TOTAL sum of all events ONCE,
    -- and then iterate BACKWARDS from `#events` down to the events for the visible bars!

  end
  return os.clock() - start
end

local function run_new_backwards()
  local N = 12
  local S = 15
  local currentSegIdx = 200

  local start = os.clock()
  for loop = 1, 10000 do
    local barData = {}

    -- 1. Calculate total XP of all retained events
    local total_xp = 0
    for i = 1, #events do
      total_xp = total_xp + events[i].xp
    end

    -- 2. Iterate backwards for the bars?
    -- Actually, calculating total_xp is O(M). M is up to 1800.
    -- Can we do better?
  end
  return os.clock() - start
end

print("Old time:", run_old())
