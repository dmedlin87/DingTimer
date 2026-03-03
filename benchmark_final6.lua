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

local function run_old()
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
  local start = os.clock()
  for loop = 1, 100000 do
    local barData = {}

    -- Optimize by maintaining total_xp in graphState, then using `segments`!
    -- Suppose graphState.totalXP = 1800 * 100 = 180000
    local total_xp = 180000
    local xp_up_to_t = total_xp

    -- But wait, what if `events` contains events *newer* than the visible window?
    -- Events are appended at `now`. So there are NO events in the future.
    -- The rightmost bar is for `currentSegIdx`, which ends at `currentSegIdx + 1`.
    -- Since `now` is within `currentSegIdx`, ALL events are `<= t_end` for `i = N`.
    -- So for `i = N`, `xp_up_to_t` is exactly `total_xp`!
    -- Thus we can iterate BACKWARDS from N down to 1!
    for i = N, 1, -1 do
      local segIdx = currentSegIdx - (N - i)
      barData[i] = xp_up_to_t
      local seg_xp = segments[segIdx] or 0
      xp_up_to_t = xp_up_to_t - seg_xp
    end
  end
  return os.clock() - start
end

print("Old:", run_old())
print("New:", run_new())
