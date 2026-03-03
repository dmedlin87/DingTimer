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

    local xp_up_to_t = 0

    -- Optimize by avoiding scanning all events from 1 to the end.
    -- We can sum up the total XP of all retained events once,
    -- and then step backwards using `segments`!
    local totalRetainedXP = 0
    for j = 1, #events do
        totalRetainedXP = totalRetainedXP + events[j].xp
    end

    local running_xp = totalRetainedXP
    -- The events newer than the last visible bar
    local evIdx = #events
    local last_t_end = anchor + (currentSegIdx + 1) * S
    while events[evIdx] and events[evIdx].t > last_t_end do
        running_xp = running_xp - events[evIdx].xp
        evIdx = evIdx - 1
    end

    for i = N, 1, -1 do
      local segIdx = currentSegIdx - (N - i)
      barData[i] = running_xp
      local seg_xp = segments[segIdx] or 0
      running_xp = running_xp - seg_xp
    end
  end
  return os.clock() - start
end

print("Old time:", run_old())
print("New time:", run_new())
