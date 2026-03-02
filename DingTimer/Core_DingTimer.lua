local ADDON, NS = ...

NS.state = {
  sessionStartTime = 0,
  lastXP = 0,
  lastMax = 0,
  lastTTL = nil,
  sessionXP = 0,
  sessionMoney = 0,
  lastMoney = 0,
  events = {}, -- {t=GetTime(), xp=delta}
  moneyEvents = {}, -- {t=GetTime(), money=delta}
}

function NS.resetXPState()
  NS.state.sessionStartTime = GetTime()
  NS.state.lastXP = UnitXP("player") or 0
  NS.state.lastMax = UnitXPMax("player") or 0
  NS.state.lastTTL = nil
  NS.state.sessionXP = 0
  NS.state.sessionMoney = 0
  NS.state.lastMoney = GetMoney() or 0
  NS.state.events = {}
  NS.state.moneyEvents = {}
  
  if NS.RefreshStatsWindow then NS.RefreshStatsWindow() end
  if NS.GraphReset then NS.GraphReset() end
end

local function pruneEvents(evList, now, windowSeconds)
  local i = 1
  while evList[i] and (now - evList[i].t) > windowSeconds do
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

local function computeRatePerHour(evList, now, windowSeconds, valueKey)
  pruneEvents(evList, now, windowSeconds)

  local sum = 0
  for i = 1, #evList do sum = sum + evList[i][valueKey] end

  local sessionStart = NS.state.sessionStartTime or now
  local sessionElapsed = now - sessionStart

  -- Use the full window size, or session elapsed if we haven't played that long yet
  local elapsed = math.min(sessionElapsed, windowSeconds)
  if elapsed <= 0 then elapsed = 1 end

  return (sum / elapsed) * 3600
end

function NS.computeXPPerHour(now, windowSeconds)
  return computeRatePerHour(NS.state.events, now, windowSeconds, "xp")
end

function NS.computeMoneyPerHour(now, windowSeconds)
  return computeRatePerHour(NS.state.moneyEvents, now, windowSeconds, "money")
end

-- Floating text
local floatFrame
function NS.ensureFloat()
  if floatFrame then return end

  -- No global name to avoid potential clashes or EditMode taint
  floatFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  floatFrame:SetSize(260, 40)
  floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  floatFrame:SetMovable(true)
  floatFrame:EnableMouse(true)
  floatFrame:RegisterForDrag("LeftButton")
  floatFrame:SetClampedToScreen(true)

  -- UI Polish: Add a subtle backdrop for better readability
  floatFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  floatFrame:SetBackdropColor(0, 0, 0, 0.6)
  floatFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

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

  if DingTimerDB.floatPosition then
    local pos = DingTimerDB.floatPosition
    floatFrame:ClearAllPoints()
    floatFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  else
    floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  end

  -- UI Polish: Use a better font and layout
  local fs = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetJustifyH("CENTER")
  fs:SetText("DingTimer")
  floatFrame.text = fs

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

  local msg = NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level"
  if xph and xph > 0 then
    msg = msg .. " |cffcccccc(|r" .. NS.C.base .. string.format("%.0f", xph) .. NS.C.r .. " |cffccccccXP/hr)|r"
  end

  floatFrame.text:SetText(msg)
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

  if delta > 0 then
    NS.state.sessionXP = (NS.state.sessionXP or 0) + delta
    table.insert(NS.state.events, { t = now, xp = delta })
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
  
  if delta > 0 then
    table.insert(NS.state.moneyEvents, { t = now, money = delta })
  end
end