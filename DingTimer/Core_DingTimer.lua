local _, NS = ...

local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min

NS.state = {
  sessionStartTime = 0,
  levelStart = 0,
  levelStartTime = 0,
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

local VALID_HUD_TRACKING_MODES = {
  auto = true,
  xp = true,
  gold = true,
}

local function callNumber(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end

  local ok, value = pcall(fn, ...)
  if ok then
    return tonumber(value)
  end
  return nil
end

local function readGlobalNumber(name)
  if not _G then
    return nil
  end
  return tonumber(_G[name])
end

local function readInterfaceVersion()
  if type(GetBuildInfo) ~= "function" then
    return nil
  end

  local ok, _, _, _, interfaceVersion = pcall(GetBuildInfo)
  if ok then
    return tonumber(interfaceVersion)
  end
  return nil
end

local function readKnownInterfaceMaxLevel()
  local interfaceVersion = readInterfaceVersion()
  if not interfaceVersion then
    return nil
  end

  if interfaceVersion >= 50000 and interfaceVersion < 60000 then
    return 90
  end
  return nil
end

function NS.NormalizeHUDTrackingMode(mode)
  if VALID_HUD_TRACKING_MODES[mode] then
    return mode
  end
  return "auto"
end

function NS.GetHUDTrackingMode()
  return NS.NormalizeHUDTrackingMode(DingTimerDB and DingTimerDB.hudTrackingMode)
end

function NS.ResolveHUDTrackingMode(mode, isMaxLevel)
  mode = NS.NormalizeHUDTrackingMode(mode)
  if mode == "auto" then
    return isMaxLevel and "gold" or "xp"
  end
  return mode
end

function NS.GetEffectiveHUDTrackingMode(isMaxLevel)
  return NS.ResolveHUDTrackingMode(NS.GetHUDTrackingMode(), isMaxLevel == true)
end

function NS.GetPlayerMaxLevel()
  return callNumber(GetMaxPlayerLevel)
    or readGlobalNumber("MAX_PLAYER_LEVEL")
    or readGlobalNumber("MAX_LEVEL")
    or readGlobalNumber("PLAYER_MAX_LEVEL")
    or readKnownInterfaceMaxLevel()
end

function NS.IsPlayerMaxLevel(level, maxXP)
  level = tonumber(level)
  if not level and UnitLevel then
    level = tonumber(UnitLevel("player"))
  end
  maxXP = tonumber(maxXP)
  if maxXP == nil and UnitXPMax then
    maxXP = tonumber(UnitXPMax("player"))
  end

  if level and level > 0 and maxXP and maxXP <= 0 then
    return true
  end

  local maxLevel = NS.GetPlayerMaxLevel and NS.GetPlayerMaxLevel() or nil
  return maxLevel ~= nil and level ~= nil and level >= maxLevel
end

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
  NS.state.levelStartTime = now
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

function NS.MarkLevelBoundary(level, now)
  now = now or GetTime()
  NS.state.levelStart = level or ((UnitLevel and UnitLevel("player")) or 0)
  NS.state.levelStartTime = now
  NS.state.lastTTL = nil
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
  if sessionElapsed >= windowSeconds then
    local newestEvent = evList[#evList]
    local newestAt = newestEvent and tonumber(newestEvent.t) or nil
    if newestAt then
      local decayStart = (sessionStart or now) + windowSeconds
      if newestAt > decayStart then
        decayStart = newestAt
      end
      if now > decayStart then
        elapsed = elapsed + (now - decayStart)
      end
    end
  end
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
  local isMaxLevel = NS.IsPlayerMaxLevel(level, maxXP)
  local hudTrackingMode = NS.GetHUDTrackingMode()
  local effectiveTrackingMode = NS.ResolveHUDTrackingMode(hudTrackingMode, isMaxLevel)
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
  local ttl = (not isMaxLevel and currentXph > 0) and (remainingXP / (currentXph / 3600)) or math_huge
  local gainsToLevel = nil
  if isMaxLevel then
    gainsToLevel = nil
  elseif lastXPGain and lastXPGain > 0 and remainingXP > 0 then
    gainsToLevel = math_ceil(remainingXP / lastXPGain)
  elseif remainingXP == 0 then
    gainsToLevel = 0
  end

  local snapshot = {
    now = now,
    level = level,
    isMaxLevel = isMaxLevel,
    hudTrackingMode = hudTrackingMode,
    effectiveTrackingMode = effectiveTrackingMode,
    xp = xp,
    maxXP = maxXP,
    remainingXP = remainingXP,
    progress = (not isMaxLevel and maxXP > 0) and (xp / maxXP) or 0,
    sessionElapsed = sessionElapsed,
    sessionXP = sessionXP,
    sessionMoney = sessionMoney,
    windowMoney = NS.state.windowMoney or 0,
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
  now = now or GetTime()
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD(now)
  end
  if NS.UpdateHeartbeatTicker then
    NS.UpdateHeartbeatTicker(now)
  end
end

function NS.HasRecentXPActivity(now)
  local lastXPAt = NS.state.lastXPAt
  if not lastXPAt then
    return false
  end

  now = now or GetTime()
  return (now - lastXPAt) <= NS.GetRollingWindowSeconds()
end

function NS.HasRecentMoneyActivity(now)
  local events = NS.state.moneyEvents
  local latest = events and events[#events]
  local latestAt = latest and tonumber(latest.t)
  if not latestAt then
    return false
  end

  now = now or GetTime()
  return (now - latestAt) <= NS.GetRollingWindowSeconds()
end

function NS.ShouldHeartbeatRun(now)
  if NS.IsFloatAnimating and NS.IsFloatAnimating() then
    return true
  end

  if not (NS.IsFloatVisible and NS.IsFloatVisible()) then
    return false
  end

  if NS.HasRecentXPActivity(now) then
    return true
  end

  local effectiveTrackingMode = NS.GetEffectiveHUDTrackingMode(NS.IsPlayerMaxLevel())
  return effectiveTrackingMode == "gold" and NS.HasRecentMoneyActivity(now)
end

function NS.StartHeartbeatTicker()
  if heartbeatTicker then
    return
  end
  heartbeatTicker = C_Timer.NewTicker(1, function()
    NS.RunHeartbeat(GetTime())
  end)
end

function NS.StopHeartbeatTicker()
  if not heartbeatTicker then
    return false
  end
  heartbeatTicker:Cancel()
  heartbeatTicker = nil
  return true
end

function NS.UpdateHeartbeatTicker(now)
  if NS.ShouldHeartbeatRun(now) then
    NS.StartHeartbeatTicker()
    return true
  end
  NS.StopHeartbeatTicker()
  return false
end
