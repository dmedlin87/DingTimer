local ADDON, NS = ...

NS.state = {
  sessionStartTime = 0,
  levelStart = 0,
  lastXP = 0,
  lastMax = 0,
  lastTTL = nil,
  sessionXP = 0,
  sessionMoney = 0,
  lastMoney = 0,
  events = {}, -- {t=GetTime(), xp=delta}
  moneyEvents = {}, -- {t=GetTime(), money=delta}
  windowXP = 0,
  windowMoney = 0,
}

function NS.resetXPState()
  NS.state.sessionStartTime = GetTime()
  NS.state.levelStart = (UnitLevel and UnitLevel("player")) or 0
  NS.state.lastXP = UnitXP("player") or 0
  NS.state.lastMax = UnitXPMax("player") or 0
  NS.state.lastTTL = nil
  NS.state.sessionXP = 0
  NS.state.sessionMoney = 0
  NS.state.lastMoney = GetMoney() or 0
  NS.state.events = {}
  NS.state.moneyEvents = {}
  NS.state.windowXP = 0
  NS.state.windowMoney = 0
  
  if NS.RefreshStatsWindow then NS.RefreshStatsWindow() end
  if NS.GraphReset then NS.GraphReset() end
end

local function pruneEvents(evList, now, windowSeconds, sumKey, valueKey)
  local i = 1
  while evList[i] and (now - evList[i].t) > windowSeconds do
    -- ⚡ Bolt: Maintain a running total to prevent O(N) calculations downstream
    if sumKey and valueKey and NS.state[sumKey] then
      NS.state[sumKey] = NS.state[sumKey] - evList[i][valueKey]
    end
    i = i + 1
  end
  if i > 1 then
    for j = 1, (#evList - i + 1) do
      evList[j] = evList[j + i - 1]
    end
    for j = #evList, (#evList - i + 2), -1 do
      evList[j] = nil
    end
  end
end

local function computeRatePerHour(evList, now, windowSeconds, valueKey, sumKey)
  pruneEvents(evList, now, windowSeconds, sumKey, valueKey)

  local sum = 0
  if sumKey and NS.state[sumKey] then
    sum = NS.state[sumKey]
  else
    for i = 1, #evList do sum = sum + evList[i][valueKey] end
  end

  local sessionStart = NS.state.sessionStartTime or now
  local sessionElapsed = now - sessionStart

  -- Use the full window size, or session elapsed if we haven't played that long yet
  local elapsed = math.min(sessionElapsed, windowSeconds)
  if elapsed <= 0 then elapsed = 1 end

  return (sum / elapsed) * 3600
end

function NS.computeXPPerHour(now, windowSeconds)
  return computeRatePerHour(NS.state.events, now, windowSeconds, "xp", "windowXP")
end

function NS.computeMoneyPerHour(now, windowSeconds)
  return computeRatePerHour(NS.state.moneyEvents, now, windowSeconds, "money", "windowMoney")
end

function NS.SetRollingWindowSeconds(seconds)
  local n = tonumber(seconds)
  if not n then
    return false
  end
  if n < 30 or n > 86400 then
    return false
  end

  DingTimerDB.windowSeconds = math.floor(n)
  if NS.RefreshStatsWindow then
    NS.RefreshStatsWindow()
  end
  return true
end

function NS.GetSessionSnapshot(now)
  now = now or GetTime()

  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0
  local level = (UnitLevel and UnitLevel("player")) or 0
  local sessionStart = NS.state.sessionStartTime or now
  local sessionElapsed = math.max(1, now - sessionStart)
  local sessionXP = NS.state.sessionXP or 0
  local sessionMoney = NS.state.sessionMoney or 0
  local window = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  local currentXph = NS.computeXPPerHour(now, window)
  local sessionXph = (sessionXP / sessionElapsed) * 3600
  local moneyPerHour = NS.computeMoneyPerHour(now, window)
  local remainingXP = math.max(0, maxXP - xp)
  local ttl = (currentXph > 0) and (remainingXP / (currentXph / 3600)) or math.huge
  local zone = "Unknown"
  if GetZoneText then
    zone = GetZoneText() or zone
  end

  return {
    now = now,
    level = level,
    xp = xp,
    maxXP = maxXP,
    remainingXP = remainingXP,
    progress = (maxXP > 0) and (xp / maxXP) or 0,
    sessionElapsed = sessionElapsed,
    sessionXP = sessionXP,
    sessionMoney = sessionMoney,
    currentXph = currentXph,
    sessionXph = sessionXph,
    moneyPerHour = moneyPerHour,
    ttl = ttl,
    rollingWindow = window,
    zone = zone,
  }
end

-- Floating text
local floatFrame
function NS.ensureFloat()
  if floatFrame then return end

  -- No global name to avoid potential clashes or EditMode taint
  floatFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  floatFrame:SetSize(320, 58)
  floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  floatFrame:SetMovable(true)
  floatFrame:EnableMouse(true)
  floatFrame:RegisterForDrag("LeftButton")
  floatFrame:SetClampedToScreen(true)

  -- UI Polish: Add a subtle backdrop for better readability
  NS.ApplyThemeToFrame(floatFrame, true)

  floatFrame:SetScript("OnDragStart", function(self)
    if DingTimerDB.floatLocked then return end
    if InCombatLockdown() then
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " can't move the float in combat.")
      return
    end
    self:StartMoving()
  end)
  
  floatFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.floatPosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
  end)

  floatFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(NS.C.base .. "DingTimer" .. NS.C.r)
    if DingTimerDB.floatLocked then
      GameTooltip:AddLine("HUD is Locked", 0.8, 0.2, 0.2)
      GameTooltip:AddLine("Unlock via Settings or /ding float unlock", 0.7, 0.7, 0.7, true)
    else
      GameTooltip:AddLine("Drag to move", 1, 1, 1)
      GameTooltip:AddLine("Lock via Settings or /ding float lock", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)

  floatFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  if DingTimerDB.floatPosition then
    local pos = DingTimerDB.floatPosition
    floatFrame:ClearAllPoints()
    floatFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  else
    floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  end

  -- UI Polish: Use a better font and layout
  local title = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetJustifyH("CENTER")
  title:SetText("DingTimer")
  floatFrame.titleText = title

  local sub = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
  sub:SetJustifyH("CENTER")
  sub:SetText("")
  floatFrame.subText = sub

  floatFrame:Hide()
end

function NS.setFloatVisible(on)
  if on then
    NS.ensureFloat()
    RegisterStateDriver(floatFrame, "visibility", "[combat] hide; show")
  else
    if floatFrame then
      UnregisterStateDriver(floatFrame, "visibility")
      if not InCombatLockdown() then
        floatFrame:Hide()
      end
    end
  end
end

local function updateFloatText(xph, ttl)
  if not DingTimerDB.float then return end
  NS.ensureFloat()

  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(GetTime()) or nil
  local header = NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level"
  local paceLine = "No XP pace detected yet"

  if xph and xph > 0 then
    paceLine = NS.FormatNumber(NS.Round(xph)) .. " XP/hr"
    if snapshot and snapshot.sessionXph > 0 then
      paceLine = paceLine .. "  |  Session " .. NS.FormatNumber(NS.Round(snapshot.sessionXph))
    end
  elseif snapshot and snapshot.sessionXph > 0 then
    paceLine = "Session " .. NS.FormatNumber(NS.Round(snapshot.sessionXph)) .. " XP/hr"
  end

  floatFrame.titleText:SetText(header)
  floatFrame.subText:SetText("|cffc6d2db" .. paceLine .. "|r")
end

function NS.onXPUpdate()
  local now = GetTime()
  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0

  -- Handle level-up rollovers
  local delta = xp - (NS.state.lastXP or 0)
  if delta < 0 then
    delta = (NS.state.lastMax or 0) - (NS.state.lastXP or 0) + xp
  end

  NS.state.lastXP = xp
  NS.state.lastMax = maxXP

  -- 🛡️ Sentinel: Prune unbounded XP events to prevent memory exhaustion DoS when UI is hidden
  local windowSeconds = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  pruneEvents(NS.state.events, now, windowSeconds, "windowXP", "xp")

  if delta > 0 then
    NS.state.sessionXP = (NS.state.sessionXP or 0) + delta
    table.insert(NS.state.events, { t = now, xp = delta })
    NS.state.windowXP = (NS.state.windowXP or 0) + delta
    if NS.GraphFeedXP then NS.GraphFeedXP(delta, now) end
  end

  local xph = NS.computeXPPerHour(now, DingTimerDB.windowSeconds or 600)
  local remaining = maxXP - xp
  local ttl = (xph > 0) and (remaining / (xph / 3600)) or math.huge

  local tcol = NS.ttlColor(ttl, NS.state.lastTTL)
  local trend = NS.ttlDeltaText(ttl, NS.state.lastTTL)

  updateFloatText(xph, ttl)
  
  if DingTimerDB.enabled and delta >= (DingTimerDB.minXPDeltaToPrint or 1) then
    local header = NS.C.base .. "[DING]" .. NS.C.r .. " "

    if (DingTimerDB.mode or "full") == "ttl" then
      local msg = header .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level" .. tcol .. trend .. NS.C.r
      NS.chat(msg)
    else
      local msg = header
        .. "+" .. NS.C.base .. delta .. NS.C.r .. " XP  "
        .. NS.C.base .. string.format("%.0f", xph) .. NS.C.r .. " XP/hr  "
        .. "TTL " .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. tcol .. trend .. NS.C.r

      NS.chat(msg)
    end
  end

  NS.state.lastTTL = ttl
end

function NS.onMoneyUpdate()
  local now = GetTime()
  local currentMoney = GetMoney() or 0
  local delta = currentMoney - (NS.state.lastMoney or 0)
  NS.state.lastMoney = currentMoney
  
  if delta ~= 0 then
    NS.state.sessionMoney = (NS.state.sessionMoney or 0) + delta
  end
  
  -- 🛡️ Sentinel: Prune unbounded money events to prevent memory exhaustion DoS when UI is hidden
  local windowSeconds = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  pruneEvents(NS.state.moneyEvents, now, windowSeconds, "windowMoney", "money")

  if delta > 0 then
    table.insert(NS.state.moneyEvents, { t = now, money = delta })
    NS.state.windowMoney = (NS.state.windowMoney or 0) + delta
  end
end
