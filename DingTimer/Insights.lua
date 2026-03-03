local ADDON, NS = ...

local function clampKeepSessions(n)
  n = math.floor(tonumber(n) or 30)
  if n < 5 then
    n = 5
  elseif n > 100 then
    n = 100
  end
  return n
end

local function safeString(value, fallback)
  if type(value) == "string" and value ~= "" then
    return value
  end
  if value ~= nil then
    local s = tostring(value)
    if s ~= "" then
      return s
    end
  end
  return fallback
end

local function average(values)
  if #values == 0 then return 0 end
  local sum = 0
  for i = 1, #values do
    sum = sum + values[i]
  end
  return sum / #values
end

local function median(values)
  local n = #values
  if n == 0 then return 0 end

  local sorted = {}
  for i = 1, n do
    sorted[i] = values[i]
  end
  table.sort(sorted)

  if n % 2 == 1 then
    return sorted[(n + 1) / 2]
  end
  return (sorted[n / 2] + sorted[(n / 2) + 1]) / 2
end

NS.NormalizeKeepSessions = clampKeepSessions

function NS.GetProfileKey()
  local name = "Unknown"
  local realm = "Unknown"
  local classToken = "UNKNOWN"

  if UnitName then
    local unitName, unitRealm = UnitName("player")
    name = safeString(unitName, name)
    realm = safeString(unitRealm, realm)
  end

  if (realm == "Unknown" or realm == "") and GetRealmName then
    realm = safeString(GetRealmName(), realm)
  end

  if UnitClass then
    local _, classFile = UnitClass("player")
    classToken = safeString(classFile, classToken)
  end

  return string.format("%s:%s:%s", realm, name, classToken)
end

function NS.GetProfileStore(createIfMissing)
  if not DingTimerDB then return nil end

  DingTimerDB.xp = DingTimerDB.xp or {}
  DingTimerDB.xp.keepSessions = clampKeepSessions(DingTimerDB.xp.keepSessions)
  DingTimerDB.xp.profiles = DingTimerDB.xp.profiles or {}

  local key = NS.GetProfileKey()
  local profile = DingTimerDB.xp.profiles[key]
  local unknownKey = "Unknown:Unknown:UNKNOWN"

  if not profile and key ~= unknownKey then
    local unknownProfile = DingTimerDB.xp.profiles[unknownKey]
    if unknownProfile and type(unknownProfile.sessions) == "table" and #unknownProfile.sessions > 0 then
      profile = { sessions = unknownProfile.sessions }
      DingTimerDB.xp.profiles[key] = profile
      DingTimerDB.xp.profiles[unknownKey] = { sessions = {} }
    end
  end

  if not profile and createIfMissing then
    profile = { sessions = {} }
    DingTimerDB.xp.profiles[key] = profile
  end

  if profile then
    profile.sessions = profile.sessions or {}
  end

  return profile
end

function NS.TrimSessions(profile, keepN)
  if not profile or type(profile.sessions) ~= "table" then return end

  local keep = clampKeepSessions(keepN or (DingTimerDB and DingTimerDB.xp and DingTimerDB.xp.keepSessions) or 30)
  local sessions = profile.sessions
  local overflow = #sessions - keep

  for _ = 1, overflow do
    table.remove(sessions, 1)
  end
end

function NS.ClearProfileSessions()
  local profile = NS.GetProfileStore(true)
  if not profile then return end

  profile.sessions = {}
  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end
end

function NS.RecordSession(reason)
  if not DingTimerDB or not NS.state then return nil end

  local now = GetTime()
  local startedAt = NS.state.sessionStartTime or now
  local durationSec = math.max(1, now - startedAt)
  local xpGained = NS.state.sessionXP or 0
  local moneyNetCopper = NS.state.sessionMoney or 0

  if xpGained <= 0 and moneyNetCopper == 0 then
    return nil
  end

  local levelStart = NS.state.levelStart or ((UnitLevel and UnitLevel("player")) or 0)
  local levelEnd = (UnitLevel and UnitLevel("player")) or levelStart
  local zone = "Unknown"
  if GetZoneText then
    zone = safeString(GetZoneText(), "Unknown")
  end

  local sampleCount = (type(NS.state.events) == "table") and #NS.state.events or 0
  local avgXph = (xpGained / durationSec) * 3600
  local avgMoneyPh = (moneyNetCopper / durationSec) * 3600
  local endedStamp = math.floor(now + 0.5)

  local record = {
    id = string.format("%d-%d-%d", endedStamp, levelStart, levelEnd),
    startedAt = startedAt,
    endedAt = now,
    durationSec = durationSec,
    levelStart = levelStart,
    levelEnd = levelEnd,
    xpGained = xpGained,
    moneyNetCopper = moneyNetCopper,
    avgXph = avgXph,
    avgMoneyPh = avgMoneyPh,
    sampleCount = sampleCount,
    zone = zone,
    reason = reason or "MANUAL_RESET",
  }

  local profile = NS.GetProfileStore(true)
  table.insert(profile.sessions, record)
  NS.TrimSessions(profile)

  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end

  return record
end

function NS.GetInsightsSummary(limit)
  local rowLimit = math.max(1, math.floor(tonumber(limit) or 10))
  local profile = NS.GetProfileStore(false)
  local sessions = (profile and profile.sessions) or {}
  local count = #sessions

  local rows = {}
  local firstIdx = math.max(1, count - rowLimit + 1)
  for i = count, firstIdx, -1 do
    rows[#rows + 1] = sessions[i]
  end

  local xphValues = {}
  local durations = {}
  local bestXph = 0

  for i = 1, count do
    local s = sessions[i]
    local xph = tonumber(s.avgXph) or 0
    local dur = tonumber(s.durationSec) or 0
    xphValues[#xphValues + 1] = xph
    if dur > 0 then
      durations[#durations + 1] = dur
    end
    if xph > bestXph then
      bestXph = xph
    end
  end

  local chartValues = {}
  local chartWindow = math.min(20, count)
  if chartWindow > 0 then
    local start = count - chartWindow + 1
    for i = start, count do
      chartValues[#chartValues + 1] = tonumber(sessions[i].avgXph) or 0
    end
  end

  local trendPct = 0
  if chartWindow >= 4 then
    local pairCount = math.floor(chartWindow / 2)
    local windowStart = count - (pairCount * 2) + 1
    local prevTotal = 0
    local newTotal = 0

    for i = windowStart, windowStart + pairCount - 1 do
      prevTotal = prevTotal + (tonumber(sessions[i].avgXph) or 0)
    end
    for i = windowStart + pairCount, windowStart + (pairCount * 2) - 1 do
      newTotal = newTotal + (tonumber(sessions[i].avgXph) or 0)
    end

    local prevAvg = prevTotal / pairCount
    local newAvg = newTotal / pairCount
    if prevAvg > 0 then
      trendPct = ((newAvg - prevAvg) / prevAvg) * 100
    end
  end

  return {
    totalSessions = count,
    rows = rows,
    chartValues = chartValues,
    medianXph = median(xphValues),
    bestXph = bestXph,
    avgLevelTime = average(durations),
    trendPct = trendPct,
  }
end
