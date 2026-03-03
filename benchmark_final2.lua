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

    -- Optimize by avoiding a full linear scan!
    -- Use binary search to find the last event before or at the last visible t_end
    local last_t_end = anchor + (currentSegIdx + 1) * S

    local low, high = 1, #events
    while low <= high do
      local mid = math.floor((low + high) / 2)
      if events[mid].t <= last_t_end then
        low = mid + 1
      else
        high = mid - 1
      end
    end
    local evIdx = high
    if evIdx < 1 then evIdx = 1 end

    -- Sum events up to evIdx
    for i = 1, evIdx do
      running_xp = running_xp + events[i].xp
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

print("New time:", run_new())
