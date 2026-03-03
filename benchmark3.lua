local function run()
  local events = {}
  local anchor = 1000
  for i = 1, 1800 do
    events[i] = { t = anchor + i * 2, xp = 100 }
  end

  local S = 15
  local N = 12
  local currentSegIdx = 100
  local sessionStart = anchor

  local start_time = os.clock()

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

  local end_time = os.clock()
  print("Time:", end_time - start_time)
end

run()
