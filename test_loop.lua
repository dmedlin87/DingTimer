local events = {}
-- Generate 1 hour of events (1 event every 2 seconds = 1800 events)
local anchor = 100000 - 4000
for i = 1, 1800 do
  table.insert(events, { t = 100000 - 3600 + i * 2, xp = 100 })
end

local function test()
  local N = 12
  local S = 15
  local currentSegIdx = 200

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
  print("evIdx after loop:", evIdx)
end

test()
