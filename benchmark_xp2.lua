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

    local total_xp = 0
    for i = 1, #events do
      total_xp = total_xp + events[i].xp
    end

    local evIdx = #events
    local xp_up_to_t = total_xp

    for i = N, 1, -1 do
      local segIdx = currentSegIdx - (N - i)
      local t_end = anchor + (segIdx + 1) * S

      -- Subtract events that are newer than t_end
      while events[evIdx] and events[evIdx].t > t_end do
        xp_up_to_t = xp_up_to_t - events[evIdx].xp
        evIdx = evIdx - 1
      end

      barData[i] = xp_up_to_t
    end
  end
  return os.clock() - start
end

print("New time:", run_new())
