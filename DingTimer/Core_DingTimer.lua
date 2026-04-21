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

---@class DingTimerTexture
---@field SetWidth fun(self: DingTimerTexture, width: number)
---@field GetWidth fun(self: DingTimerTexture): number
---@field SetAlpha fun(self: DingTimerTexture, alpha: number)
---@field GetAlpha fun(self: DingTimerTexture): number
---@field Show fun(self: DingTimerTexture)
---@field Hide fun(self: DingTimerTexture)
---@field IsShown fun(self: DingTimerTexture): boolean
---@field ClearAllPoints fun(self: DingTimerTexture)
---@field SetPoint fun(self: DingTimerTexture, point: string, relativeTo: any, relativePoint: string, xOfs: number, yOfs: number)

---@class DingTimerFloatFrame
---@field Show fun(self: DingTimerFloatFrame)
---@field Hide fun(self: DingTimerFloatFrame)
---@field titleText DingTimerTextRegion?
---@field subText DingTimerTextRegion?
---@field progressBar Frame?
---@field progressFill DingTimerTexture?
---@field progressSheen DingTimerTexture?
---@field progressPulse DingTimerTexture?
---@field progressSpark DingTimerTexture?
---@field progressCap DingTimerTexture?
---@field _hudGlow DingTimerTexture?
---@field _hudBottomLine DingTimerTexture?
---@field progressBarWidth number?
---@field _displayedProgress number?
---@field _targetProgress number?
---@field _progressAnim table?
---@field _gainPulse table?
---@field _hovered boolean?

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

local HUD_WIDTH = 308
local HUD_HEIGHT = 66
local HUD_BAR_WIDTH = 276
local HUD_BAR_HEIGHT = 9
local HUD_PROGRESS_ANIM_DURATION = 0.28
local HUD_GAIN_PULSE_DURATION = 0.65
local HUD_PROGRESS_EPSILON = 0.0005
local HUD_SUB_TEXT_MAX_CHARS = 64

local function formatHUDNumber(value, compact)
  local n = tonumber(value) or 0
  if not compact or math_abs(n) < 100000 then
    return NS.FormatNumber(n)
  end

  local sign = ""
  if n < 0 then
    sign = "-"
    n = math_abs(n)
  end

  if n >= 1000000000 then
    return sign .. string_format("%.1fB", n / 1000000000)
  end
  if n >= 1000000 then
    return sign .. string_format("%.1fM", n / 1000000)
  end
  return sign .. string_format("%.0fK", n / 1000)
end

local function buildHUDPaceText(snapshot, compact)
  local paceParts = {}

  if snapshot.currentXph and snapshot.currentXph > 0 then
    paceParts[#paceParts + 1] = formatHUDNumber(NS.Round(snapshot.currentXph), compact) .. " XP/hr"
  else
    paceParts[#paceParts + 1] = "No XP in " .. NS.fmtTime(snapshot.rollingWindow or 0)
  end

  if snapshot.lastXPGain and snapshot.lastXPGain > 0 then
    local lastGainText = "Last +" .. formatHUDNumber(snapshot.lastXPGain, compact)
    if snapshot.gainsToLevel ~= nil then
      lastGainText = lastGainText .. " (" .. formatHUDNumber(snapshot.gainsToLevel, compact) .. ")"
    end
    paceParts[#paceParts + 1] = lastGainText
  end

  paceParts[#paceParts + 1] = "Need " .. formatHUDNumber(snapshot.remainingXP or 0, compact)
  return table.concat(paceParts, "  |  ")
end

local function anchorFloatToDefault(frame)
  if not frame then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
end

local function clampProgress(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function easeOutCubic(value)
  local t = math_min(1, math_max(0, value or 0))
  local inv = 1 - t
  return 1 - (inv * inv * inv)
end

local function updateFloatBarVisual(frame, progress, pulseAlpha)
  if not frame or not frame.progressBar or not frame.progressFill then
    return
  end

  local fill = frame.progressFill
  local sheen = frame.progressSheen
  local pulse = frame.progressPulse
  local spark = frame.progressSpark
  local cap = frame.progressCap
  local barWidth = frame.progressBarWidth or HUD_BAR_WIDTH

  progress = clampProgress(progress)
  pulseAlpha = tonumber(pulseAlpha) or 0
  local hoverAlpha = frame._hovered and 1 or 0

  local fillWidth = math_floor((barWidth * progress) + 0.5)
  if progress > 0 and fillWidth < 2 then
    fillWidth = 2
  end

  if frame._hudGlow then
    frame._hudGlow:SetAlpha(0.12 + (pulseAlpha * 0.24) + (hoverAlpha * 0.12))
  end
  if frame._hudBottomLine then
    frame._hudBottomLine:SetColorTexture(0.05, 0.12, 0.16, 0.58 + (hoverAlpha * 0.14))
  end

  if fillWidth > 0 then
    fill:SetWidth(fillWidth)
    fill:Show()
    fill:SetColorTexture(0.16, 0.78, 0.92, 0.76 + (pulseAlpha * 0.09))

    if sheen then
      sheen:SetWidth(fillWidth)
      sheen:SetColorTexture(0.94, 0.99, 1.0, 0.10 + (pulseAlpha * 0.12))
      sheen:Show()
    end
  else
    fill:SetWidth(0)
    fill:Hide()
    if sheen then
      sheen:SetWidth(0)
      sheen:Hide()
    end
  end

  if pulse and fillWidth > 0 and pulseAlpha > 0 then
    pulse:SetWidth(math_min(barWidth, fillWidth + 18))
    pulse:SetAlpha(0.05 + (pulseAlpha * 0.26))
    pulse:Show()
  elseif pulse then
    pulse:SetWidth(fillWidth)
    pulse:SetAlpha(0)
    pulse:Hide()
  end

  if spark and fillWidth > 0 then
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", frame.progressBar, "LEFT", fillWidth, 0)
    spark:SetAlpha(0.12 + (pulseAlpha * 0.58) + (hoverAlpha * 0.08))
    spark:Show()
  elseif spark then
    spark:SetAlpha(0)
    spark:Hide()
  end

  if cap and fillWidth > 0 then
    cap:ClearAllPoints()
    cap:SetPoint("CENTER", frame.progressBar, "LEFT", fillWidth, 0)
    cap:SetAlpha(0.46 + (pulseAlpha * 0.2) + (hoverAlpha * 0.12))
    cap:Show()
  elseif cap then
    cap:SetAlpha(0)
    cap:Hide()
  end
end

local function animateFloatOnUpdate(self, elapsed)
  local displayed = self._displayedProgress or 0
  local pulseAlpha = 0

  if self._progressAnim then
    local animation = self._progressAnim
    animation.elapsed = (animation.elapsed or 0) + elapsed

    local t = 1
    if (animation.duration or 0) > 0 then
      t = math_min(animation.elapsed / animation.duration, 1)
    end

    displayed = animation.start + ((animation.target - animation.start) * easeOutCubic(t))
    self._displayedProgress = displayed

    if t >= 1 then
      displayed = animation.target
      self._displayedProgress = displayed
      self._progressAnim = nil
    end
  else
    displayed = self._targetProgress or displayed
    self._displayedProgress = displayed
  end

  if self._gainPulse then
    local pulse = self._gainPulse
    pulse.elapsed = (pulse.elapsed or 0) + elapsed

    local t = 1
    if (pulse.duration or 0) > 0 then
      t = math_min(pulse.elapsed / pulse.duration, 1)
    end

    local fade = 1 - t
    pulseAlpha = fade * fade

    if t >= 1 then
      self._gainPulse = nil
      pulseAlpha = 0
    end
  end

  updateFloatBarVisual(self, displayed, pulseAlpha)

  if not self._progressAnim and not self._gainPulse then
    self:SetScript("OnUpdate", nil)
  end
end

local function ensureFloatAnimation(frame)
  if not frame then
    return
  end

  local current = frame.GetScript and frame:GetScript("OnUpdate") or nil
  if current ~= animateFloatOnUpdate then
    frame:SetScript("OnUpdate", animateFloatOnUpdate)
  end
end

local function setFloatProgress(frame, progress, animate)
  if not frame or not frame.progressBar then
    return
  end

  progress = clampProgress(progress)

  if frame._displayedProgress == nil or frame._targetProgress == nil then
    frame._displayedProgress = progress
    frame._targetProgress = progress
    frame._progressAnim = nil
    updateFloatBarVisual(frame, progress, 0)
    return
  end

  if math_abs(progress - (frame._targetProgress or 0)) < HUD_PROGRESS_EPSILON then
    if not frame._progressAnim then
      frame._displayedProgress = progress
      frame._targetProgress = progress
      updateFloatBarVisual(frame, progress, frame._gainPulse and 1 or 0)
    end
    return
  end

  frame._targetProgress = progress

  if not animate or progress < (frame._displayedProgress or 0) then
    frame._displayedProgress = progress
    frame._progressAnim = nil
    updateFloatBarVisual(frame, progress, frame._gainPulse and 1 or 0)
    return
  end

  frame._progressAnim = {
    start = frame._displayedProgress or progress,
    target = progress,
    elapsed = 0,
    duration = HUD_PROGRESS_ANIM_DURATION,
  }
  updateFloatBarVisual(frame, frame._displayedProgress or progress, frame._gainPulse and 1 or 0)
  ensureFloatAnimation(frame)
end

local function triggerFloatGainPulse(progress)
  local frame = floatFrame
  if not frame or not frame.progressBar or not (frame.IsShown and frame:IsShown()) then
    return
  end

  progress = clampProgress(progress)

  if frame._displayedProgress == nil then
    frame._displayedProgress = progress
    frame._targetProgress = progress
  elseif progress < frame._displayedProgress then
    frame._displayedProgress = progress
    frame._targetProgress = progress
    frame._progressAnim = nil
  end

  frame._gainPulse = {
    elapsed = 0,
    duration = HUD_GAIN_PULSE_DURATION,
  }

  updateFloatBarVisual(frame, frame._displayedProgress or progress, 1)
  ensureFloatAnimation(frame)
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
  floatFrame:SetSize(HUD_WIDTH, HUD_HEIGHT)
  floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  floatFrame:SetMovable(true)
  floatFrame:EnableMouse(true)
  floatFrame:RegisterForDrag("LeftButton")
  floatFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  floatFrame:SetClampedToScreen(true)
  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(floatFrame, true)
  end
  if floatFrame._dingAccent then
    floatFrame._dingAccent:Hide()
  end
  if floatFrame._dingGlow then
    floatFrame._dingGlow:Hide()
  end
  if floatFrame.SetBackdropBorderColor then
    floatFrame:SetBackdropBorderColor(0.18, 0.58, 0.72, 0.88)
  end

  local hudGlow = floatFrame:CreateTexture(nil, "BACKGROUND")
  hudGlow:SetPoint("TOPLEFT", floatFrame, "TOPLEFT", -4, 4)
  hudGlow:SetPoint("BOTTOMRIGHT", floatFrame, "BOTTOMRIGHT", 4, -4)
  hudGlow:SetColorTexture(0.08, 0.28, 0.36, 1)
  hudGlow:SetAlpha(0.12)
  floatFrame._hudGlow = hudGlow

  local bottomLine = floatFrame:CreateTexture(nil, "BORDER")
  bottomLine:SetHeight(1)
  bottomLine:SetPoint("BOTTOMLEFT", floatFrame, "BOTTOMLEFT", 12, 6)
  bottomLine:SetPoint("BOTTOMRIGHT", floatFrame, "BOTTOMRIGHT", -12, 6)
  bottomLine:SetColorTexture(0.05, 0.12, 0.16, 0.58)
  floatFrame._hudBottomLine = bottomLine

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
    self._hovered = true
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, self._gainPulse and 1 or 0)
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

  floatFrame:SetScript("OnLeave", function(self)
    self._hovered = false
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, 0)
    GameTooltip:Hide()
  end)

  floatFrame:SetScript("OnHide", function(self)
    self._gainPulse = nil
    self._progressAnim = nil
    self:SetScript("OnUpdate", nil)
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, 0)
  end)

  if DingTimerDB.floatPosition then
    local pos = DingTimerDB.floatPosition
    floatFrame:ClearAllPoints()
    floatFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or 0, pos.yOfs or 0)
  else
    anchorFloatToDefault(floatFrame)
  end

  local bar = CreateFrame("Frame", nil, floatFrame)
  bar:SetSize(HUD_BAR_WIDTH, HUD_BAR_HEIGHT)
  bar:SetPoint("BOTTOM", floatFrame, "BOTTOM", 0, 11)
  floatFrame.progressBar = bar
  floatFrame.progressBarWidth = HUD_BAR_WIDTH

  local barShadow = bar:CreateTexture(nil, "BACKGROUND")
  barShadow:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  barShadow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
  barShadow:SetColorTexture(0, 0, 0, 0.35)

  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(bar)
  track:SetColorTexture(0.03, 0.05, 0.08, 0.92)

  local trackEdge = bar:CreateTexture(nil, "BORDER")
  trackEdge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  trackEdge:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
  trackEdge:SetHeight(1)
  trackEdge:SetColorTexture(0.34, 0.44, 0.52, 0.55)

  local trackGlow = bar:CreateTexture(nil, "BORDER")
  trackGlow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  trackGlow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  trackGlow:SetColorTexture(0.12, 0.24, 0.32, 0.22)

  for i = 1, 3 do
    local tick = bar:CreateTexture(nil, "BORDER")
    tick:SetWidth(1)
    tick:SetHeight(HUD_BAR_HEIGHT - 4)
    tick:SetPoint("CENTER", bar, "LEFT", math_floor((HUD_BAR_WIDTH * i / 4) + 0.5), 0)
    tick:SetColorTexture(0.52, 0.74, 0.82, 0.16)
  end

  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fill:SetWidth(0)
  fill:SetColorTexture(0.16, 0.78, 0.92, 0.76)
  fill:Hide()
  floatFrame.progressFill = fill

  local sheen = bar:CreateTexture(nil, "OVERLAY")
  sheen:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
  sheen:SetWidth(0)
  sheen:SetHeight(math_max(4, math_floor(HUD_BAR_HEIGHT * 0.42)))
  sheen:SetColorTexture(0.94, 0.99, 1.0, 0.10)
  sheen:Hide()
  floatFrame.progressSheen = sheen

  local fillShade = bar:CreateTexture(nil, "OVERLAY")
  fillShade:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fillShade:SetWidth(HUD_BAR_WIDTH)
  fillShade:SetHeight(math_max(4, math_floor(HUD_BAR_HEIGHT * 0.4)))
  fillShade:SetColorTexture(0.03, 0.08, 0.12, 0.18)

  local pulse = bar:CreateTexture(nil, "OVERLAY")
  pulse:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  pulse:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  pulse:SetWidth(0)
  pulse:SetTexture("Interface\\Buttons\\WHITE8X8")
  pulse:SetBlendMode("ADD")
  pulse:SetVertexColor(0.78, 0.96, 1, 1)
  pulse:SetAlpha(0)
  pulse:Hide()
  floatFrame.progressPulse = pulse

  local spark = bar:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  spark:SetSize(14, HUD_BAR_HEIGHT + 6)
  spark:SetAlpha(0)
  spark:Hide()
  floatFrame.progressSpark = spark

  local cap = bar:CreateTexture(nil, "OVERLAY")
  cap:SetSize(2, HUD_BAR_HEIGHT + 2)
  cap:SetTexture("Interface\\Buttons\\WHITE8X8")
  cap:SetBlendMode("ADD")
  cap:SetVertexColor(0.86, 0.98, 1.0, 1)
  cap:SetAlpha(0)
  cap:Hide()
  floatFrame.progressCap = cap

  local title = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", floatFrame, "TOP", 0, -8)
  if title.SetWidth then
    title:SetWidth(HUD_BAR_WIDTH + 10)
  end
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(title, "value")
  end
  if title.SetTextColor then
    title:SetTextColor(0.95, 0.98, 1.0)
  end
  title:SetJustifyH("CENTER")
  floatFrame.titleText = title

  local sub = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("BOTTOM", bar, "TOP", 0, 4)
  if sub.SetWidth then
    sub:SetWidth(HUD_BAR_WIDTH + 16)
  end
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(sub, "subtle")
  end
  if sub.SetTextColor then
    sub:SetTextColor(0.82, 0.88, 0.92)
  end
  sub:SetJustifyH("CENTER")
  floatFrame.subText = sub

  updateFloatBarVisual(floatFrame, 0, 0)

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
    if on and DingTimerDB and DingTimerDB.float and InCombatLockdown() and not DingTimerDB.floatShowInCombat then
      if NS.HideHUDPopup then
        NS.HideHUDPopup()
      end
    end
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

  setFloatProgress(frame, snapshot.progress, frame._displayedProgress ~= nil)

  local header = NS.fmtTime(snapshot.ttl) .. " to level"
  local paceText = buildHUDPaceText(snapshot, false)
  if string.len(paceText) > HUD_SUB_TEXT_MAX_CHARS then
    paceText = buildHUDPaceText(snapshot, true)
  end

  local titleText = frame.titleText
  local subText = frame.subText
  if not titleText or not subText then
    return
  end

  titleText:SetText(header)
  subText:SetText("|cffc6d2db" .. paceText .. "|r")
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
    triggerFloatGainPulse((maxXP > 0) and (xp / maxXP) or 0)
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
