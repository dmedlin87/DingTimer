local ADDON = "DingTimer"
local NS = { state = {} }
DingTimerDB = { windowSeconds = 3600 }
UnitXP = function() return 0 end
UnitXPMax = function() return 100 end

-- MOCK state
NS.state.sessionStartTime = 0
NS.state.events = {}

-- Insert 10,000 events
for i = 1, 10000 do
  table.insert(NS.state.events, { t = i, xp = 10 })
end

local function pruneEventsOld(evList, now, windowSeconds)
  local i = 1
  while evList[i] and (now - evList[i].t) > windowSeconds do
    i = i + 1
  end
  if i > 1 then
    for j = 1, (#evList - i + 1) do evList[j] = evList[j + i - 1] end
    for j = #evList, (#evList - i + 2), -1 do evList[j] = nil end
  end
end

local function computeRatePerHourOld(evList, now, windowSeconds, valueKey)
  pruneEventsOld(evList, now, windowSeconds)
  local sum = 0
  for i = 1, #evList do sum = sum + evList[i][valueKey] end
  local sessionElapsed = now - NS.state.sessionStartTime
  local elapsed = math.min(sessionElapsed, windowSeconds)
  if elapsed <= 0 then elapsed = 1 end
  return (sum / elapsed) * 3600
end

local startOld = os.clock()
for i = 1, 1000 do
  computeRatePerHourOld(NS.state.events, 10000, 3600, "xp")
end
local timeOld = os.clock() - startOld


-- NEW logic
NS.state.events = {}
NS.state.windowXP = 0
for i = 1, 10000 do
  table.insert(NS.state.events, { t = i, xp = 10 })
  NS.state.windowXP = NS.state.windowXP + 10
end

local function pruneEventsNew(evList, now, windowSeconds, sumKey, valueKey)
  local i = 1
  while evList[i] and (now - evList[i].t) > windowSeconds do
    if sumKey and valueKey and NS.state[sumKey] then
      NS.state[sumKey] = NS.state[sumKey] - evList[i][valueKey]
    end
    i = i + 1
  end
  if i > 1 then
    for j = 1, (#evList - i + 1) do evList[j] = evList[j + i - 1] end
    for j = #evList, (#evList - i + 2), -1 do evList[j] = nil end
  end
end

local function computeRatePerHourNew(evList, now, windowSeconds, valueKey, sumKey)
  pruneEventsNew(evList, now, windowSeconds, sumKey, valueKey)
  local sum = 0
  if sumKey and NS.state[sumKey] then
    sum = NS.state[sumKey]
  else
    for i = 1, #evList do sum = sum + evList[i][valueKey] end
  end
  local sessionElapsed = now - NS.state.sessionStartTime
  local elapsed = math.min(sessionElapsed, windowSeconds)
  if elapsed <= 0 then elapsed = 1 end
  return (sum / elapsed) * 3600
end

local startNew = os.clock()
for i = 1, 1000 do
  computeRatePerHourNew(NS.state.events, 10000, 3600, "xp", "windowXP")
end
local timeNew = os.clock() - startNew

print("Old (O(N) sum): " .. timeOld .. "s")
print("New (O(1) sum): " .. timeNew .. "s")
