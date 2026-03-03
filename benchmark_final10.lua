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

    local total_xp = 180000 -- Simulated graphState.totalXP
    local xp_up_to_t = total_xp

    for i = N, 1, -1 do
      local segIdx = currentSegIdx - (N - i)
      barData[i] = xp_up_to_t
      local seg_xp = segments[segIdx] or 0
      xp_up_to_t = xp_up_to_t - seg_xp
    end
  end
  return os.clock() - start
end

print("New (maintain totalXP):", run_new())
