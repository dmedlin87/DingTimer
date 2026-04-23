local _, NS = ...

local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min

NS.state = {
  sessionStartTime = 0,
  levelStart = 0,
  lastXP = 0,
  lastMax = 0,
  lastXPGain = nil,
  lastXPAt = nil,
  lastTTL = nil,
  sessionXP = 0,
  sessionMoney = 0,
  lastMoney = 0,
  events = {},
  moneyEvents = {},
  windowXP = 0,
  windowMoney = 0,
  skipNextXPDropAfterLevelUp = false,
}

local heartbeatTicker = nil
local tickCache = {
  now = 0,
  snapshot = nil,
}

function NS.GetRollingWindowSeconds()
  return tonumber(DingTimerDB and DingTimerDB.windowSeconds) or 600
end

function NS.GetMinXPDeltaToPrint()
  local value = tonumber(DingTimerDB and DingTimerDB.minXPDeltaToPrint)
  if not value or value < 1 then
    return 1
  end
  return value
end

local function clearInternalState(now)
  NS.state.sessionStartTime = now
  NS.state.levelStart = (UnitLevel and UnitLevel("player")) or 0
  NS.state.lastXP = UnitXP("player") or 0
  NS.state.lastMax = UnitXPMax("player") or 0
  NS.state.lastXPGain = nil
  NS.state.lastXPAt = nil
  NS.state.lastTTL = nil
  NS.state.sessionXP = 0
  NS.state.sessionMoney = 0
  NS.state.lastMoney = GetMoney() or 0
  NS.state.events = {}
  NS.state.moneyEvents = {}
  NS.state.windowXP = 0
  NS.state.windowMoney = 0
  NS.state.skipNextXPDropAfterLevelUp = false
end

function NS.InvalidateTickCache()
  tickCache.now = 0
  tickCache.snapshot = nil
end

function NS.resetXPState()
  local now = GetTime()
  clearInternalState(now)
  NS.InvalidateTickCache()
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD(now)
  end
  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
end

local function pruneEvents(evList, now, windowSeconds, sumOwner, sumKey, valueKey)
  local i = 1
  while evList[i] and (now - evList[i].t) > windowSeconds do
    if sumOwner and sumKey and valueKey and sumOwner[sumKey] then
      sumOwner[sumKey] = sumOwner[sumKey] - evList[i][valueKey]
    end
    i = i + 1
  end

  if i > 1 then
    local len = #evList
    local newLen = len - i + 1
    for j = 1, newLen do
      evList[j] = evList[j + i - 1]
    end
    for j = len, newLen + 1, -1 do
      evList[j] = nil
    end
  end
end

function NS.PruneRollingEvents(evList, now, windowSeconds, sumOwner, sumKey, valueKey)
  pruneEvents(evList, now, windowSeconds, sumOwner, sumKey, valueKey)
end

function NS.ComputeRollingRatePerHour(evList, now, sessionStart, windowSeconds, valueKey, sumOwner, sumKey)
  pruneEvents(evList, now, windowSeconds, sumOwner, sumKey, valueKey)

  local sum = 0
  if sumOwner and sumKey and sumOwner[sumKey] then
    sum = tonumber(sumOwner[sumKey]) or 0
  else
    for i = 1, #evList do
      sum = sum + evList[i][valueKey]
    end
  end

  local sessionElapsed = now - (sessionStart or now)
  local elapsed = math_min(sessionElapsed, windowSeconds)
  if elapsed <= 0 then
    elapsed = 1
  end

  return (sum / elapsed) * 3600
end

function NS.ComputeRollingRateDetails(evList, now, sessionStart, windowSeconds, valueKey, sumOwner, sumKey)
  return {
    rawXph = NS.ComputeRollingRatePerHour(evList, now, sessionStart, windowSeconds, valueKey, sumOwner, sumKey),
  }
end

function NS.computeXPPerHour(now, windowSeconds)
  return NS.ComputeRollingRatePerHour(
    NS.state.events,
    now,
    NS.state.sessionStartTime,
    windowSeconds,
    "xp",
    NS.state,
    "windowXP"
  )
end

function NS.computeMoneyPerHour(now, windowSeconds)
  return NS.ComputeRollingRatePerHour(
    NS.state.moneyEvents,
    now,
    NS.state.sessionStartTime,
    windowSeconds,
    "money",
    NS.state,
    "windowMoney"
  )
end

function NS.SetRollingWindowSeconds(seconds)
  local n = tonumber(seconds)
  if not n then
    return false
  end
  if n < 30 or n > 86400 then
    return false
  end

  DingTimerDB.windowSeconds = math_floor(n)
  NS.InvalidateTickCache()
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD()
  end
  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
  return true
end

function NS.GetSessionSnapshot(now)
  now = now or GetTime()
  if tickCache.snapshot and tickCache.now == now then
    return tickCache.snapshot
  end

  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0
  local level = (UnitLevel and UnitLevel("player")) or 0
  local sessionStart = NS.state.sessionStartTime or now
  local sessionElapsed = math_max(1, now - sessionStart)
  local sessionXP = NS.state.sessionXP or 0
  local sessionMoney = NS.state.sessionMoney or 0
  local lastXPGain = NS.state.lastXPGain
  local lastXPAt = NS.state.lastXPAt
  local secondsSinceLastXP = nil
  if lastXPAt then
    secondsSinceLastXP = math_max(0, now - lastXPAt)
  end
  local window = NS.GetRollingWindowSeconds()
  local xpRate = NS.ComputeRollingRateDetails(NS.state.events, now, sessionStart, window, "xp", NS.state, "windowXP")
  local moneyRate = NS.ComputeRollingRateDetails(
    NS.state.moneyEvents,
    now,
    sessionStart,
    window,
    "money",
    NS.state,
    "windowMoney"
  )
  local currentXph = xpRate.rawXph
  local sessionXph = (sessionXP / sessionElapsed) * 3600
  local moneyPerHour = moneyRate.rawXph
  local remainingXP = math_max(0, maxXP - xp)
  local ttl = (currentXph > 0) and (remainingXP / (currentXph / 3600)) or math_huge
  local gainsToLevel = nil
  if lastXPGain and lastXPGain > 0 and remainingXP > 0 then
    gainsToLevel = math_ceil(remainingXP / lastXPGain)
  elseif remainingXP == 0 then
    gainsToLevel = 0
  end

  local snapshot = {
    now = now,
    level = level,
    xp = xp,
    maxXP = maxXP,
    remainingXP = remainingXP,
    progress = (maxXP > 0) and (xp / maxXP) or 0,
    sessionElapsed = sessionElapsed,
    sessionXP = sessionXP,
    sessionMoney = sessionMoney,
    lastXPGain = lastXPGain,
    lastXPAt = lastXPAt,
    secondsSinceLastXP = secondsSinceLastXP,
    gainsToLevel = gainsToLevel,
    currentXph = currentXph,
    rawCurrentXph = currentXph,
    sessionXph = sessionXph,
    moneyPerHour = moneyPerHour,
    rawMoneyPerHour = moneyPerHour,
    ttl = ttl,
    rollingWindow = window,
  }

  tickCache.now = now
  tickCache.snapshot = snapshot
  return snapshot
end

function NS.RunHeartbeat(now)
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD(now or GetTime())
  end
end

function NS.StartHeartbeatTicker()
  if heartbeatTicker then
    return
  end
  heartbeatTicker = C_Timer.NewTicker(1, function()
    NS.RunHeartbeat(GetTime())
  end)
end

function NS.StartCoachTicker()
  NS.StartHeartbeatTicker()
end

function NS.RunCoachHeartbeat(now)
  NS.RunHeartbeat(now)
end
