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

    -- Optimize by computing running_xp iteratively but only up to the first visible bar!
    local first_segIdx = currentSegIdx - (N - 1)
    local first_t_end = anchor + (first_segIdx + 1) * S

    local evIdx = 1
    while events[evIdx] and events[evIdx].t <= first_t_end do
      running_xp = running_xp + events[evIdx].xp
      evIdx = evIdx + 1
    end

    barData[1] = running_xp

    for i = 2, N do
      local segIdx = currentSegIdx - (N - i)
      local t_end = anchor + (segIdx + 1) * S
      while events[evIdx] and events[evIdx].t <= t_end do
        running_xp = running_xp + events[evIdx].xp
        evIdx = evIdx + 1
      end
      barData[i] = running_xp
    end
  end
  return os.clock() - start
end

print("New time:", run_new())
