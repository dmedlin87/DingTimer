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

    local xp_up_to_t = 0
    -- Optimize: Instead of O(E) summation, use binary search to find the sum up to `t_end`.
    -- Wait, we can't do that if we don't precompute a prefix sum array.
    -- But since we only need ONE sum (the sum of all events), we can just sum them all up?
    -- No, actually, the loop in `run_old()` only iterated up to `t_end` for `i=N`.
    -- So `run_old()` is O(E).
    -- If we maintain `graphState.totalXP` it's O(1). Let's see how `graphState.events` is modified.

  end
end
