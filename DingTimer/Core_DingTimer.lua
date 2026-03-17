local ADDON, NS = ...

-- ⚡ Localize frequently-used globals to avoid repeated table lookups in hot paths
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_abs = math.abs
local math_huge = math.huge
local string_format = string.format

NS.state = {
  sessionStartTime = 0,
  levelStart = 0,
  lastXP = 0,
  lastMax = 0,
  lastTTL = nil,
  sessionXP = 0,
  sessionPeakXph = 0,
  sessionMoney = 0,
  lastMoney = 0,
  events = {}, -- {t=GetTime(), xp=delta}
  moneyEvents = {}, -- {t=GetTime(), money=delta}
  windowXP = 0,
  windowMoney = 0,
}

local coachTicker = nil

-- ⚡ Per-tick cache: snapshot and coach status are computed once per heartbeat tick
-- and shared across all callers (HUD, stats panel, graph, coach) for the same `now`.
local tickCache = { now = 0, snapshot = nil, coachStatus = nil }

function NS.resetXPState()
  local now = GetTime()
  NS.state.sessionStartTime = now
  NS.state.levelStart = (UnitLevel and UnitLevel("player")) or 0
  NS.state.lastXP = UnitXP("player") or 0
  NS.state.lastMax = UnitXPMax("player") or 0
  NS.state.lastTTL = nil
  NS.state.sessionXP = 0
  NS.state.sessionPeakXph = 0
  NS.state.sessionMoney = 0
  NS.state.lastMoney = GetMoney() or 0
  NS.state.events = {}
  NS.state.moneyEvents = {}
  NS.state.windowXP = 0
  NS.state.windowMoney = 0
  if NS.InitCoachState then
    NS.InitCoachState(now)
  end
  if NS.RefreshStatsWindow then NS.RefreshStatsWindow() end
  if NS.RefreshInsightsWindow then NS.RefreshInsightsWindow() end
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

local function computeRatePerHour(evList, now, windowSeconds, valueKey, sumKey)
  pruneEvents(evList, now, windowSeconds, sumKey, valueKey)

  local sum = 0
  if sumKey and NS.state[sumKey] then
    sum = tonumber(NS.state[sumKey]) or 0
  else
    for i = 1, #evList do sum = sum + evList[i][valueKey] end
  end

  local sessionStart = NS.state.sessionStartTime or now
  local sessionElapsed = now - sessionStart

  -- Use the full window size, or session elapsed if we haven't played that long yet
  local elapsed = math_min(sessionElapsed, windowSeconds)
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

  DingTimerDB.windowSeconds = math_floor(n)
  if NS.RefreshStatsWindow then
    NS.RefreshStatsWindow()
  end
  return true
end

function NS.GetSessionSnapshot(now)
  now = now or GetTime()

  -- ⚡ Return cached snapshot if already computed for this tick
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
  local window = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  local currentXph = NS.computeXPPerHour(now, window)
  local sessionXph = (sessionXP / sessionElapsed) * 3600
  local moneyPerHour = NS.computeMoneyPerHour(now, window)
  local remainingXP = math_max(0, maxXP - xp)
  local ttl = (currentXph > 0) and (remainingXP / (currentXph / 3600)) or math_huge
  local zone = "Unknown"
  if GetZoneText then
    zone = GetZoneText() or zone
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
    currentXph = currentXph,
    sessionPeakXph = NS.state.sessionPeakXph or 0,
    sessionXph = sessionXph,
    moneyPerHour = moneyPerHour,
    ttl = ttl,
    rollingWindow = window,
    zone = zone,
    coachGoal = (DingTimerDB and DingTimerDB.coach and DingTimerDB.coach.goal) or "ding",
  }

  tickCache.now = now
  tickCache.snapshot = snapshot
  NS._tickCoachNow = 0  -- invalidate coach cache when snapshot changes
  NS._tickCoachStatus = nil
  return snapshot
end

function NS.InvalidateTickCache()
  tickCache.now = 0
  tickCache.snapshot = nil
  NS._tickCoachNow = 0
  NS._tickCoachStatus = nil
end

function NS.RunCoachHeartbeat(now)
  now = now or GetTime()
  if NS.MaybeRunCoach then
    NS.MaybeRunCoach(now)
  end
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD(now)
  end
end

function NS.StartCoachTicker()
  if coachTicker then
    return
  end
  coachTicker = C_Timer.NewTicker(1, function()
    NS.RunCoachHeartbeat(GetTime())
  end)
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
    ---@diagnostic disable-next-line: redundant-parameter
    RegisterStateDriver(floatFrame, "visibility", "[combat] hide; show")
    if NS.RefreshFloatingHUD then
      NS.RefreshFloatingHUD()
    end
  else
    if floatFrame then
      ---@diagnostic disable-next-line: redundant-parameter
      UnregisterStateDriver(floatFrame, "visibility")
      if not InCombatLockdown() then
        floatFrame:Hide()
      end
    end
  end
end

function NS.RefreshFloatingHUD(now)
  if not DingTimerDB or not DingTimerDB.float then return end
  NS.ensureFloat()

  now = now or GetTime()
  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(now) or nil
  local coach = NS.GetCoachStatus and NS.GetCoachStatus(now) or nil
  if not snapshot then
    return
  end

  local header = NS.C.base .. NS.fmtTime(snapshot.ttl) .. NS.C.r .. " to level"
  local paceParts = {}

  if snapshot.currentXph and snapshot.currentXph > 0 then
    paceParts[#paceParts + 1] = NS.FormatNumber(NS.Round(snapshot.currentXph)) .. " XP/hr"
  else
    paceParts[#paceParts + 1] = "No XP in " .. NS.fmtTime(snapshot.rollingWindow or 0)
  end

  if snapshot.sessionXph and snapshot.sessionXph > 0 then
    paceParts[#paceParts + 1] = "Session " .. NS.FormatNumber(NS.Round(snapshot.sessionXph))
  end

  if coach and coach.goal and coach.goal.targetXph and coach.goal.targetXph > 0 then
    local goalLabel = coach.goal.shortLabel or "Goal"
    if not snapshot.sessionXph
      or math_abs((coach.goal.targetXph or 0) - (snapshot.sessionXph or 0)) > 0.5 then
      paceParts[#paceParts + 1] = goalLabel .. " " .. NS.FormatNumber(NS.Round(coach.goal.targetXph))
    end
  end

  floatFrame.titleText:SetText(header)
  floatFrame.subText:SetText("|cffc6d2db" .. table.concat(paceParts, "  |  ") .. "|r")
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
    -- ⚡ Bolt: Direct indexing is ~1.25x faster than table.insert
    local events = NS.state.events
    events[#events + 1] = { t = now, xp = delta }
    NS.state.windowXP = (NS.state.windowXP or 0) + delta
    if NS.NoteCoachXP then NS.NoteCoachXP(delta, now) end
    if NS.GraphFeedXP then NS.GraphFeedXP(delta, now) end
  end

  local xph = NS.computeXPPerHour(now, DingTimerDB.windowSeconds or 600)
  -- Only record peak once the rate has a full confidence window; avoids the first-kill
  -- spike (elapsed=1s → inflated XP/hr) from becoming the permanent pace-drop benchmark.
  local MIN_RATE_CONFIDENCE_SECONDS = 60
  if (now - (NS.state.sessionStartTime or now)) >= MIN_RATE_CONFIDENCE_SECONDS then
    NS.state.sessionPeakXph = math_max(NS.state.sessionPeakXph or 0, xph or 0)
  end
  local remaining = maxXP - xp
  local ttl = (xph > 0) and (remaining / (xph / 3600)) or math_huge

  local tcol = NS.ttlColor(ttl, NS.state.lastTTL)
  local trend = NS.ttlDeltaText(ttl, NS.state.lastTTL)
  
  if DingTimerDB.enabled and delta >= (DingTimerDB.minXPDeltaToPrint or 1) then
    local header = NS.C.base .. "[DING]" .. NS.C.r .. " "

    if (DingTimerDB.mode or "full") == "ttl" then
      local msg = header .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level" .. tcol .. trend .. NS.C.r
      NS.chat(msg)
    else
      local msg = header
        .. "+" .. NS.C.base .. delta .. NS.C.r .. " XP  "
        .. NS.C.base .. string_format("%.0f", xph) .. NS.C.r .. " XP/hr  "
        .. "TTL " .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. tcol .. trend .. NS.C.r

      NS.chat(msg)
    end
  end

  NS.state.lastTTL = ttl
  NS.RunCoachHeartbeat(now)
end

function NS.onMoneyUpdate()
  local now = GetTime()
  local currentMoney = GetMoney() or 0
  local delta = currentMoney - (NS.state.lastMoney or 0)
  NS.state.lastMoney = currentMoney
  
  if delta ~= 0 then
    NS.state.sessionMoney = (NS.state.sessionMoney or 0) + delta
    if NS.NoteCoachMoney then
      NS.NoteCoachMoney(delta, now)
    end
  end
  
  -- 🛡️ Sentinel: Prune unbounded money events to prevent memory exhaustion DoS when UI is hidden
  local windowSeconds = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  pruneEvents(NS.state.moneyEvents, now, windowSeconds, "windowMoney", "money")

  if delta > 0 then
    -- ⚡ Bolt: Direct indexing is ~1.25x faster than table.insert
    local moneyEvents = NS.state.moneyEvents
    moneyEvents[#moneyEvents + 1] = { t = now, money = delta }
    NS.state.windowMoney = (NS.state.windowMoney or 0) + delta
  end
end
