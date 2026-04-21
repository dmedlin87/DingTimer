local _, NS = ...

local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local string_format = string.format

---@class DingTimerTextRegion
---@field SetText fun(self: DingTimerTextRegion, text: string)

---@class DingTimerFloatFrame
---@field Show fun(self: DingTimerFloatFrame)
---@field Hide fun(self: DingTimerFloatFrame)
---@field titleText DingTimerTextRegion?
---@field subText DingTimerTextRegion?

NS.state = {
  sessionStartTime = 0,
  levelStart = 0,
  lastXP = 0,
  lastMax = 0,
  lastXPGain = nil,
  lastTTL = nil,
  sessionXP = 0,
  sessionMoney = 0,
  lastMoney = 0,
  events = {},
  moneyEvents = {},
  windowXP = 0,
  windowMoney = 0,
}

---@type DingTimerFloatFrame?
local floatFrame = nil
local heartbeatTicker = nil
local tickCache = {
  now = 0,
  snapshot = nil,
}

local function anchorFloatToDefault(frame)
  if not frame then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
end

local function getRollingWindowSeconds()
  return tonumber(DingTimerDB and DingTimerDB.windowSeconds) or 600
end

local function getMinXPDeltaToPrint()
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
  NS.state.lastTTL = nil
  NS.state.sessionXP = 0
  NS.state.sessionMoney = 0
  NS.state.lastMoney = GetMoney() or 0
  NS.state.events = {}
  NS.state.moneyEvents = {}
  NS.state.windowXP = 0
  NS.state.windowMoney = 0
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
  local window = getRollingWindowSeconds()
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

function NS.GetFloatFrame()
  return floatFrame
end

function NS.ensureFloat()
  if floatFrame then
    return
  end

  floatFrame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  floatFrame:SetSize(292, 52)
  floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  floatFrame:SetMovable(true)
  floatFrame:EnableMouse(true)
  floatFrame:RegisterForDrag("LeftButton")
  floatFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  floatFrame:SetClampedToScreen(true)
  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(floatFrame, true)
  end

  floatFrame:SetScript("OnDragStart", function(self)
    if DingTimerDB.floatLocked then
      return
    end
    self:StartMoving()
  end)

  floatFrame:SetScript("OnDragStop", function(self)
    if DingTimerDB.floatLocked then
      return
    end
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.floatPosition = {
      point = point,
      relativePoint = relativePoint,
      xOfs = xOfs,
      yOfs = yOfs,
    }
  end)

  floatFrame:SetScript("OnClick", function(self, button)
    if button == "RightButton" and NS.ToggleHUDPopup then
      NS.ToggleHUDPopup(self)
      return
    end
    if button == "LeftButton" and DingTimerDB.floatLocked and NS.ToggleHUDPopup then
      NS.ToggleHUDPopup(self)
    end
  end)

  floatFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(NS.C.base .. "DingTimer" .. NS.C.r)
    if DingTimerDB.floatLocked then
      GameTooltip:AddLine("Left-click to toggle settings", 1, 1, 1)
    else
      GameTooltip:AddLine("Left-drag to move the HUD", 1, 1, 1)
    end
    GameTooltip:AddLine("Right-click to toggle settings", 1, 1, 1)
    GameTooltip:Show()
  end)

  floatFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  if DingTimerDB.floatPosition then
    local pos = DingTimerDB.floatPosition
    floatFrame:ClearAllPoints()
    floatFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or 0, pos.yOfs or 0)
  else
    anchorFloatToDefault(floatFrame)
  end

  local title = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", floatFrame, "TOP", 0, -10)
  title:SetJustifyH("CENTER")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(title, "value")
  end
  floatFrame.titleText = title

  local sub = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -3)
  sub:SetJustifyH("CENTER")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(sub, "subtle")
  end
  floatFrame.subText = sub

  floatFrame:Hide()
end

function NS.ResetFloatPosition()
  NS.ensureFloat()
  if not floatFrame then
    return false
  end

  DingTimerDB.floatPosition = nil
  anchorFloatToDefault(floatFrame)
  return true
end

local function shouldShowFloat()
  if not DingTimerDB or not DingTimerDB.float then
    return false
  end

  if InCombatLockdown() and not DingTimerDB.floatShowInCombat then
    return false
  end

  return true
end

function NS.setFloatVisible(on)
  if on and shouldShowFloat() then
    NS.ensureFloat()
    local frame = floatFrame
    if not frame then
      return
    end
    frame:Show()
    if NS.RefreshFloatingHUD then
      NS.RefreshFloatingHUD()
    end
  elseif floatFrame then
    floatFrame:Hide()
  end

  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
end

function NS.RefreshFloatingHUD(now)
  if not DingTimerDB or not DingTimerDB.float then
    return
  end

  NS.ensureFloat()
  local frame = floatFrame
  if not frame then
    return
  end
  now = now or GetTime()

  local snapshot = NS.GetSessionSnapshot(now)
  if not snapshot then
    return
  end

  local header = NS.fmtTime(snapshot.ttl) .. " to level"
  local paceParts = {}

  if snapshot.currentXph and snapshot.currentXph > 0 then
    paceParts[#paceParts + 1] = NS.FormatNumber(NS.Round(snapshot.currentXph)) .. " XP/hr"
  else
    paceParts[#paceParts + 1] = "No XP in " .. NS.fmtTime(snapshot.rollingWindow or 0)
  end

  if snapshot.lastXPGain and snapshot.lastXPGain > 0 then
    local lastGainText = "Last +" .. NS.FormatNumber(snapshot.lastXPGain)
    if snapshot.gainsToLevel ~= nil then
      lastGainText = lastGainText .. " (" .. NS.FormatNumber(snapshot.gainsToLevel) .. ")"
    end
    paceParts[#paceParts + 1] = lastGainText
  end

  paceParts[#paceParts + 1] = "Need " .. NS.FormatNumber(snapshot.remainingXP or 0)

  local titleText = frame.titleText
  local subText = frame.subText
  if not titleText or not subText then
    return
  end

  titleText:SetText(header)
  subText:SetText("|cffc6d2db" .. table.concat(paceParts, "  |  ") .. "|r")
end

function NS.onXPUpdate()
  local now = GetTime()
  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0

  local delta = xp - (NS.state.lastXP or 0)
  if delta < 0 then
    delta = (NS.state.lastMax or 0) - (NS.state.lastXP or 0) + xp
  end

  NS.state.lastXP = xp
  NS.state.lastMax = maxXP

  local windowSeconds = getRollingWindowSeconds()
  pruneEvents(NS.state.events, now, windowSeconds, NS.state, "windowXP", "xp")

  if delta > 0 then
    local events = NS.state.events
    NS.state.sessionXP = (NS.state.sessionXP or 0) + delta
    NS.state.lastXPGain = delta
    events[#events + 1] = { t = now, xp = delta }
    NS.state.windowXP = (NS.state.windowXP or 0) + delta
  end

  NS.InvalidateTickCache()

  local snapshot = NS.GetSessionSnapshot(now)
  if not snapshot then
    NS.RunHeartbeat(now)
    return
  end
  if DingTimerDB.enabled and delta >= getMinXPDeltaToPrint() then
    local header = NS.C.base .. "[DING]" .. NS.C.r .. " "
    local ttl = snapshot.ttl or math_huge
    local trendColor = NS.ttlColor and NS.ttlColor(ttl, NS.state.lastTTL) or ""
    local trendText = NS.ttlDeltaText and NS.ttlDeltaText(ttl, NS.state.lastTTL) or ""

    if (DingTimerDB.mode or "full") == "ttl" then
      NS.chat(header .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level" .. trendColor .. trendText .. NS.C.r)
    else
      NS.chat(
        header
          .. "+"
          .. NS.C.base
          .. delta
          .. NS.C.r
          .. " XP  "
          .. NS.C.base
          .. string_format("%.0f", snapshot.currentXph or 0)
          .. NS.C.r
          .. " XP/hr  TTL "
          .. NS.C.base
          .. NS.fmtTime(ttl)
          .. NS.C.r
          .. trendColor
          .. trendText
          .. NS.C.r
      )
    end
  end

  NS.state.lastTTL = snapshot.ttl or NS.state.lastTTL
  NS.RunHeartbeat(now)
end

function NS.onMoneyUpdate()
  local now = GetTime()
  local currentMoney = GetMoney() or 0
  local delta = currentMoney - (NS.state.lastMoney or 0)
  NS.state.lastMoney = currentMoney

  if delta ~= 0 then
    NS.state.sessionMoney = (NS.state.sessionMoney or 0) + delta
  end

  local windowSeconds = getRollingWindowSeconds()
  pruneEvents(NS.state.moneyEvents, now, windowSeconds, NS.state, "windowMoney", "money")

  if delta > 0 then
    local moneyEvents = NS.state.moneyEvents
    moneyEvents[#moneyEvents + 1] = { t = now, money = delta }
    NS.state.windowMoney = (NS.state.windowMoney or 0) + delta
  end

  NS.InvalidateTickCache()
end
