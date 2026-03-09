local ADDON, NS = ...

local MIN_SEGMENT_SECONDS = 15
local MIN_BARS = 10
local MAX_BARS = 60
local MAX_RETENTION_SECONDS = 3600
local GRID_LINE_COUNT = 4
local TIME_LABEL_COUNT = 5

local DEFAULTS = NS.GraphWindowDefaults or {
  width = 660,
  height = 340,
  minWidth = 540,
  minHeight = 280,
  maxWidth = 1200,
  maxHeight = 680,
}

local ZOOM_LEVELS = {
  { label = "3m", seconds = 180 },
  { label = "5m", seconds = 300 },
  { label = "15m", seconds = 900 },
  { label = "30m", seconds = 1800 },
  { label = "60m", seconds = 3600 },
}

local COLOR_GREEN = { 0.22, 0.82, 0.46, 0.95 }
local COLOR_RED = { 0.92, 0.32, 0.32, 0.95 }
local COLOR_GRAY = { 0.42, 0.46, 0.54, 0.55 }
local COLOR_LINE = { 1.0, 0.82, 0.18, 0.95 }
local COLOR_GRID = { 0.26, 0.29, 0.34, 0.75 }
local BRIGHT_BOOST = 0.08

local graphFrame = nil
local barTextures = {}
local barHitFrames = {}
local lineSegments = {}
local gridLines = {}
local yAxisLabels = {}
local timeAxisLabels = {}

local graphState = {
  anchor = 0,
  events = {},
  totalXP = 0,
  lastPrunedSessionXP = 0,
  dirty = false,
}

local function computeBarCount(windowSeconds)
  local raw = math.floor(windowSeconds / MIN_SEGMENT_SECONDS)
  return math.max(MIN_BARS, math.min(MAX_BARS, raw))
end

local function computeSegmentSeconds(windowSeconds)
  local n = computeBarCount(windowSeconds)
  return windowSeconds / n
end

local function getSegmentIndex(timestamp, anchor, segSeconds)
  return math.floor((timestamp - anchor) / segSeconds)
end

local function getStoredGraphSize()
  local size = DingTimerDB.graphWindowSize or {}
  local width, height = NS.ClampGraphWindowSize(size.width or DEFAULTS.width, size.height or DEFAULTS.height)
  return width, height
end

local function saveGraphPosition(frame)
  local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
  DingTimerDB.graphPosition = {
    point = point,
    relativePoint = relativePoint,
    xOfs = xOfs,
    yOfs = yOfs,
  }
end

local function saveGraphSize(width, height)
  local clampedWidth, clampedHeight = NS.ClampGraphWindowSize(width, height)
  DingTimerDB.graphWindowSize = {
    width = clampedWidth,
    height = clampedHeight,
  }
end

local function pruneGraphEvents(now)
  local cutoff = now - MAX_RETENTION_SECONDS - 60
  local events = graphState.events
  local i = 1
  while events[i] and events[i].t < cutoff do
    graphState.totalXP = graphState.totalXP - events[i].xp
    graphState.lastPrunedSessionXP = events[i].sessionXP or graphState.lastPrunedSessionXP
    i = i + 1
  end
  if i > 1 then
    for j = 1, (#events - i + 1) do
      events[j] = events[j + i - 1]
    end
    for j = #events, (#events - i + 2), -1 do
      events[j] = nil
    end
  end
end

local function aggregateVisibleSegments(now, segSeconds, segmentCount, anchor)
  local currentSegIdx = getSegmentIndex(now, anchor, segSeconds)
  local firstVisibleIdx = currentSegIdx - segmentCount + 1
  local segments = {}

  for i = #graphState.events, 1, -1 do
    local ev = graphState.events[i]
    local segIdx = getSegmentIndex(ev.t, anchor, segSeconds)
    if segIdx < firstVisibleIdx then
      break
    end
    if segIdx <= currentSegIdx then
      segments[segIdx] = (segments[segIdx] or 0) + ev.xp
    end
  end

  return segments, currentSegIdx
end

local function computeHistoryPeakXPH(now, anchor, segSeconds, currentSegIdx)
  local firstRetainedIdx = getSegmentIndex(now - MAX_RETENTION_SECONDS, anchor, segSeconds)
  local segmentXP = {}
  local peak = 0

  for i = #graphState.events, 1, -1 do
    local ev = graphState.events[i]
    local segIdx = getSegmentIndex(ev.t, anchor, segSeconds)
    if segIdx < firstRetainedIdx then
      break
    end
    if segIdx <= currentSegIdx then
      segmentXP[segIdx] = (segmentXP[segIdx] or 0) + ev.xp
    end
  end

  for _, xp in pairs(segmentXP) do
    local xph = (xp / segSeconds) * 3600
    if xph > peak then
      peak = xph
    end
  end

  return peak
end

local function buildAverageSeries(events, baselineSessionXP, now, sessionStart, anchor, segSeconds, currentSegIdx, segmentCount)
  local averages = {}
  local cumulativeXP = baselineSessionXP or 0
  local eventIndex = 1

  for i = 1, segmentCount do
    local segIdx = currentSegIdx - (segmentCount - i)
    local segEnd = anchor + (segIdx + 1) * segSeconds
    local pointTime = math.min(segEnd, now)

    while events[eventIndex] and events[eventIndex].t <= pointTime do
      local event = events[eventIndex]
      cumulativeXP = event.sessionXP or (cumulativeXP + (event.xp or 0))
      eventIndex = eventIndex + 1
    end

    local elapsed = pointTime - sessionStart
    if elapsed < 1 then
      elapsed = 1
    end
    averages[i] = (cumulativeXP / elapsed) * 3600
  end

  return averages
end

local function resolveScaleMax(mode, visiblePeak, avgPeak, historyPeak, fixedMax)
  local normalized = NS.NormalizeGraphScaleMode(mode)
  if normalized == "fixed" then
    return math.max(NS.ClampGraphFixedMax(fixedMax), 1)
  end

  local peak = math.max(visiblePeak or 0, avgPeak or 0, 1)
  if normalized == "session" then
    peak = math.max(peak, historyPeak or 0)
  end

  return math.max(1, peak * 1.12)
end

NS.BuildGraphAverageSeriesForTest = buildAverageSeries
NS.ResolveGraphScaleForTest = resolveScaleMax

local function zoomLabelForSeconds(seconds)
  for _, z in ipairs(ZOOM_LEVELS) do
    if z.seconds == seconds then
      return z.label
    end
  end
  return NS.fmtTime(seconds)
end

local function formatRate(value)
  return NS.FormatNumber(NS.Round(value or 0)) .. " / hr"
end

local function formatRateShort(value)
  return NS.FormatNumber(NS.Round(value or 0))
end

local function formatAxisTime(seconds)
  if seconds <= 0 then
    return "Now"
  end
  return NS.fmtTime(seconds) .. " ago"
end

local function applySummaryCard(card, label, value, subValue)
  card.label:SetText(label)
  card.value:SetText(value)
  card.sub:SetText(subValue or "")
end

local function layoutGraphFrame()
  if not graphFrame then
    return
  end

  local width = graphFrame:GetWidth()
  local cardGap = 8
  local cardWidth = math.floor((width - 24 - (cardGap * 3)) / 4)
  local left = 12

  graphFrame.separator:SetWidth(width - 24)

  for i = 1, #graphFrame.summaryCards do
    local card = graphFrame.summaryCards[i]
    card:ClearAllPoints()
    card:SetSize(cardWidth, 48)
    card:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", left, -42)
    left = left + cardWidth + cardGap
  end

  graphFrame.graphArea:ClearAllPoints()
  graphFrame.graphArea:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", 64, -104)
  graphFrame.graphArea:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -18, 70)

  graphFrame.legendLabel:ClearAllPoints()
  graphFrame.legendLabel:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, 48)

  graphFrame.zoomFooter:ClearAllPoints()
  graphFrame.zoomFooter:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, 22)

  local zoomX = 56
  for i = 1, #graphFrame.zoomButtons do
    local btn = graphFrame.zoomButtons[i]
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", zoomX, 16)
    zoomX = zoomX + 42
  end

  graphFrame.fixedMaxLabel:ClearAllPoints()
  graphFrame.fixedMaxLabel:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -164, 46)

  graphFrame.decreaseFixedButton:ClearAllPoints()
  graphFrame.decreaseFixedButton:SetPoint("RIGHT", graphFrame.fixedMaxLabel, "LEFT", -6, 0)

  graphFrame.increaseFixedButton:ClearAllPoints()
  graphFrame.increaseFixedButton:SetPoint("LEFT", graphFrame.fixedMaxLabel, "RIGHT", 6, 0)

  graphFrame.scaleModeButton:ClearAllPoints()
  graphFrame.scaleModeButton:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -140, 16)

  graphFrame.fitButton:ClearAllPoints()
  graphFrame.fitButton:SetPoint("LEFT", graphFrame.scaleModeButton, "RIGHT", 6, 0)

  graphFrame.resetViewButton:ClearAllPoints()
  graphFrame.resetViewButton:SetPoint("LEFT", graphFrame.fitButton, "RIGHT", 6, 0)

  graphFrame.resizeGrip:ClearAllPoints()
  graphFrame.resizeGrip:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -8, 8)
end

local function updateAxis(scaleMax, now, windowSeconds)
  local graphArea = graphFrame.graphArea
  local areaWidth = math.max(graphArea:GetWidth(), 1)
  local areaHeight = math.max(graphArea:GetHeight(), 1)

  for i = 1, GRID_LINE_COUNT do
    local frac = i / GRID_LINE_COUNT
    local y = frac * areaHeight
    local value = scaleMax * frac
    local line = gridLines[i]

    line:ClearAllPoints()
    line:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 0, y)
    line:SetPoint("BOTTOMRIGHT", graphArea, "BOTTOMRIGHT", 0, y)
    line:Show()

    local label = yAxisLabels[i]
    label:ClearAllPoints()
    label:SetPoint("RIGHT", graphArea, "BOTTOMLEFT", -8, y)
    label:SetText(NS.FormatNumber(NS.Round(value)))
  end

  for i = 1, TIME_LABEL_COUNT do
    local frac = (i - 1) / (TIME_LABEL_COUNT - 1)
    local secondsAgo = math.floor((1 - frac) * windowSeconds + 0.5)
    local label = timeAxisLabels[i]

    label:ClearAllPoints()
    label:SetPoint("TOP", graphArea, "BOTTOMLEFT", frac * areaWidth, -6)
    if i == TIME_LABEL_COUNT then
      label:SetText("Now")
    else
      label:SetText(formatAxisTime(secondsAgo))
    end
  end
end

local function refreshControlState(scaleMax, visiblePeak, historyPeak, snapshot)
  local mode = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
  graphFrame.scaleModeButton:SetText(NS.GetGraphScaleModeLabel(mode, true))
  graphFrame.fitButton:SetText(mode == "visible" and "Fitted" or "Fit")
  graphFrame.fixedMaxLabel:SetText("Fixed " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))

  if mode == "fixed" then
    graphFrame.fixedMaxLabel:Show()
    graphFrame.decreaseFixedButton:Show()
    graphFrame.increaseFixedButton:Show()
  else
    graphFrame.fixedMaxLabel:Hide()
    graphFrame.decreaseFixedButton:Hide()
    graphFrame.increaseFixedButton:Hide()
  end

  applySummaryCard(
    graphFrame.summaryCards[1],
    "Current Pace",
    formatRateShort(snapshot.currentXph),
    "Window " .. zoomLabelForSeconds(snapshot.rollingWindow)
  )

  applySummaryCard(
    graphFrame.summaryCards[2],
    "Session Avg",
    formatRateShort(snapshot.sessionXph),
    NS.fmtTime(snapshot.sessionElapsed) .. " elapsed"
  )

  applySummaryCard(
    graphFrame.summaryCards[3],
    mode == "session" and "60m Peak" or "Visible Peak",
    formatRateShort(mode == "session" and historyPeak or visiblePeak),
    mode == "session" and "Retained graph history" or "Bars on screen"
  )

  applySummaryCard(
    graphFrame.summaryCards[4],
    "Scale",
    NS.GetGraphScaleModeLabel(mode, true),
    NS.FormatNumber(NS.Round(scaleMax)) .. " max"
  )
end

local function redrawGraph()
  if not graphFrame or not graphFrame:IsShown() then
    return
  end

  local now = GetTime()
  graphState.dirty = false
  pruneGraphEvents(now)

  local windowSeconds = DingTimerDB.graphWindowSeconds or 300
  local segmentCount = computeBarCount(windowSeconds)
  local segSeconds = computeSegmentSeconds(windowSeconds)
  local anchor = graphState.anchor
  if anchor == 0 then
    anchor = NS.state.sessionStartTime or now
  end

  local segments, currentSegIdx = aggregateVisibleSegments(now, segSeconds, segmentCount, anchor)
  local graphArea = graphFrame.graphArea
  local areaWidth = math.max(graphArea:GetWidth(), 1)
  local areaHeight = math.max(graphArea:GetHeight(), 1)
  local gap = 2
  local barWidth = math.max(3, (areaWidth - ((segmentCount - 1) * gap)) / segmentCount)

  local sessionStart = NS.state.sessionStartTime or now
  local avgSeries = buildAverageSeries(
    graphState.events,
    graphState.lastPrunedSessionXP,
    now,
    sessionStart,
    anchor,
    segSeconds,
    currentSegIdx,
    segmentCount
  )

  local barData = {}
  local visiblePeak = 0
  local avgPeak = 0

  for i = 1, segmentCount do
    local segIdx = currentSegIdx - (segmentCount - i)
    local xp = segments[segIdx] or 0
    local xph = (xp / segSeconds) * 3600
    local avgXph = avgSeries[i] or 0

    barData[i] = {
      xp = xp,
      xph = xph,
      avgXph = avgXph,
      segIdx = segIdx,
    }

    if xph > visiblePeak then
      visiblePeak = xph
    end
    if avgXph > avgPeak then
      avgPeak = avgXph
    end
  end

  local historyPeak = computeHistoryPeakXPH(now, anchor, segSeconds, currentSegIdx)
  local scaleMax = resolveScaleMax(DingTimerDB.graphScaleMode, visiblePeak, avgPeak, historyPeak, DingTimerDB.graphFixedMaxXPH)
  local snapshot = NS.GetSessionSnapshot(now)

  updateAxis(scaleMax, now, windowSeconds)
  refreshControlState(scaleMax, visiblePeak, historyPeak, snapshot)

  graphFrame.subtitle:SetText("Resizable graph. Drag the lower-right corner.")
  graphFrame.legendLabel:SetText("|cff6fd090Green|r up  |  |cffe86a6aRed|r down  |  |cffffd130Gold|r session average")
  if visiblePeak <= 0 and snapshot.sessionXP <= 0 then
    graphFrame.emptyState:Show()
  else
    graphFrame.emptyState:Hide()
  end

  local prevXCenter = nil
  local prevYAvg = nil

  for i = 1, MAX_BARS do
    local bar = barTextures[i]
    local hit = barHitFrames[i]

    if i <= segmentCount then
      local d = barData[i]
      local xPos = (i - 1) * (barWidth + gap)
      local heightFrac = math.min((d.xph / scaleMax), 1)
      local barHeight = math.max(1, heightFrac * areaHeight)

      local r, g, b, a
      if d.xp == 0 then
        r, g, b, a = COLOR_GRAY[1], COLOR_GRAY[2], COLOR_GRAY[3], COLOR_GRAY[4]
      else
        local prevXph = (i > 1) and barData[i - 1].xph or 0
        if d.xph >= prevXph then
          r, g, b, a = COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]
        else
          r, g, b, a = COLOR_RED[1], COLOR_RED[2], COLOR_RED[3], COLOR_RED[4]
        end
      end

      if i == segmentCount then
        r = math.min(r + BRIGHT_BOOST, 1)
        g = math.min(g + BRIGHT_BOOST, 1)
        b = math.min(b + BRIGHT_BOOST, 1)
      end

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", xPos, 0)
      bar:SetSize(barWidth, barHeight)
      bar:SetColorTexture(r, g, b, a)
      bar:Show()

      hit:ClearAllPoints()
      hit:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", xPos, 0)
      hit:SetSize(barWidth, areaHeight)
      hit.tipData = {
        timeRange = formatAxisTime(math.max(0, now - (anchor + d.segIdx * segSeconds))) .. " to "
          .. formatAxisTime(math.max(0, now - (anchor + ((d.segIdx + 1) * segSeconds)))),
        xpText = NS.FormatNumber(d.xp),
        xphText = NS.FormatNumber(NS.Round(d.xph)),
        avgXphText = NS.FormatNumber(NS.Round(d.avgXph)),
        isCurrent = (i == segmentCount),
      }
      hit:Show()

      local xCenter = xPos + (barWidth / 2)
      local avgHeightFrac = math.min((d.avgXph / scaleMax), 1)
      local yAvg = avgHeightFrac * areaHeight

      if i > 1 then
        local line = lineSegments[i - 1]
        line:SetStartPoint("BOTTOMLEFT", prevXCenter, prevYAvg)
        line:SetEndPoint("BOTTOMLEFT", xCenter, yAvg)
        line:Show()
      end

      prevXCenter = xCenter
      prevYAvg = yAvg
    else
      bar:Hide()
      hit:Hide()
      if i > 1 and lineSegments[i - 1] then
        lineSegments[i - 1]:Hide()
      end
    end
  end
end

local function createSummaryCard(parent)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  NS.ApplyThemeToFrame(card, true)

  local accent = card:CreateTexture(nil, "ARTWORK")
  accent:SetHeight(2)
  accent:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
  accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
  accent:SetColorTexture(0.24, 0.78, 0.92, 0.7)

  card.label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -12)

  card.value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  card.value:SetPoint("TOPLEFT", card.label, "BOTTOMLEFT", 0, -4)

  card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  card.sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)

  return card
end

function NS.InitGraphWindow()
  if graphFrame then
    return
  end

  local width, height = getStoredGraphSize()

  graphFrame = CreateFrame("Frame", "DingTimerXPGraphWindow", UIParent, "BackdropTemplate")
  graphFrame:SetSize(width, height)
  graphFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
  NS.ApplyThemeToFrame(graphFrame)

  graphFrame:SetMovable(true)
  graphFrame:SetResizable(true)
  graphFrame:EnableMouse(true)
  graphFrame:RegisterForDrag("LeftButton")
  graphFrame:SetClampedToScreen(true)

  if graphFrame.SetResizeBounds then
    graphFrame:SetResizeBounds(DEFAULTS.minWidth, DEFAULTS.minHeight, DEFAULTS.maxWidth, DEFAULTS.maxHeight)
  else
    if graphFrame.SetMinResize then
      graphFrame:SetMinResize(DEFAULTS.minWidth, DEFAULTS.minHeight)
    end
    if graphFrame.SetMaxResize then
      graphFrame:SetMaxResize(DEFAULTS.maxWidth, DEFAULTS.maxHeight)
    end
  end

  graphFrame:SetScript("OnDragStart", function(self)
    if DingTimerDB.graphLocked or InCombatLockdown() then
      return
    end
    self:StartMoving()
  end)

  graphFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveGraphPosition(self)
  end)

  if DingTimerDB.graphPosition then
    local pos = DingTimerDB.graphPosition
    graphFrame:ClearAllPoints()
    graphFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  end

  local closeBtn = CreateFrame("Button", nil, graphFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)

  local title = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText(NS.C.base .. "XP Pace Graph" .. NS.C.r)
  graphFrame.title = title

  local subtitle = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetText("")
  graphFrame.subtitle = subtitle

  local separator = graphFrame:CreateTexture(nil, "ARTWORK")
  separator:SetHeight(1)
  separator:SetPoint("TOP", 0, -35)
  separator:SetColorTexture(0.2, 0.6, 0.8, 0.45)
  graphFrame.separator = separator

  graphFrame.summaryCards = {}
  for i = 1, 4 do
    graphFrame.summaryCards[i] = createSummaryCard(graphFrame)
  end

  local graphArea = CreateFrame("Frame", nil, graphFrame, "BackdropTemplate")
  graphArea:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  graphArea:SetBackdropColor(0.01, 0.01, 0.01, 0.75)
  graphArea:SetBackdropBorderColor(0.22, 0.24, 0.28, 0.9)
  graphFrame.graphArea = graphArea

  local baseline = graphArea:CreateTexture(nil, "ARTWORK")
  baseline:SetHeight(1)
  baseline:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 0, 0)
  baseline:SetPoint("BOTTOMRIGHT", graphArea, "BOTTOMRIGHT", 0, 0)
  baseline:SetColorTexture(COLOR_GRID[1], COLOR_GRID[2], COLOR_GRID[3], 1)

  for i = 1, GRID_LINE_COUNT do
    local line = graphArea:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(COLOR_GRID[1], COLOR_GRID[2], COLOR_GRID[3], COLOR_GRID[4])
    gridLines[i] = line

    local label = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetText("0")
    yAxisLabels[i] = label
  end

  for i = 1, TIME_LABEL_COUNT do
    local label = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    label:SetText("")
    timeAxisLabels[i] = label
  end

  local emptyState = graphArea:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyState:SetPoint("CENTER", graphArea, "CENTER", 0, 0)
  emptyState:SetText("Kill something. The graph fills after your first XP event.")
  graphFrame.emptyState = emptyState

  local legendLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  legendLabel:SetText("")
  graphFrame.legendLabel = legendLabel

  local zoomFooter = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zoomFooter:SetText("Zoom")
  graphFrame.zoomFooter = zoomFooter

  graphFrame.zoomButtons = {}
  for _, z in ipairs(ZOOM_LEVELS) do
    local btn = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
    btn:SetSize(38, 22)
    btn:SetText(z.label)
    btn:SetScript("OnClick", function()
      NS.SetGraphZoom(z.label)
    end)
    graphFrame.zoomButtons[#graphFrame.zoomButtons + 1] = btn
  end

  local fixedMaxLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  fixedMaxLabel:SetText("")
  graphFrame.fixedMaxLabel = fixedMaxLabel

  local decreaseFixedButton = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
  decreaseFixedButton:SetSize(24, 20)
  decreaseFixedButton:SetText("-")
  decreaseFixedButton:SetScript("OnClick", function()
    NS.AdjustGraphFixedMax(-25000)
  end)
  graphFrame.decreaseFixedButton = decreaseFixedButton

  local increaseFixedButton = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
  increaseFixedButton:SetSize(24, 20)
  increaseFixedButton:SetText("+")
  increaseFixedButton:SetScript("OnClick", function()
    NS.AdjustGraphFixedMax(25000)
  end)
  graphFrame.increaseFixedButton = increaseFixedButton

  local scaleModeButton = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
  scaleModeButton:SetSize(96, 24)
  scaleModeButton:SetText("Scale")
  scaleModeButton:SetScript("OnClick", function()
    NS.CycleGraphScaleMode()
  end)
  graphFrame.scaleModeButton = scaleModeButton

  local fitButton = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
  fitButton:SetSize(58, 24)
  fitButton:SetText("Fit")
  fitButton:SetScript("OnClick", function()
    NS.SetGraphScale("visible")
  end)
  graphFrame.fitButton = fitButton

  local resetViewButton = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
  resetViewButton:SetSize(74, 24)
  resetViewButton:SetText("Reset")
  resetViewButton:SetScript("OnClick", function()
    NS.ResetGraphLayout()
  end)
  graphFrame.resetViewButton = resetViewButton

  local resizeGrip = CreateFrame("Button", nil, graphFrame)
  resizeGrip:SetSize(18, 18)
  resizeGrip:EnableMouse(true)
  resizeGrip:SetScript("OnMouseDown", function()
    if DingTimerDB.graphLocked or InCombatLockdown() then
      return
    end
    graphFrame:StartSizing("BOTTOMRIGHT")
  end)
  resizeGrip:SetScript("OnMouseUp", function()
    graphFrame:StopMovingOrSizing()
    saveGraphSize(graphFrame:GetWidth(), graphFrame:GetHeight())
    redrawGraph()
  end)
  local gripText = resizeGrip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  gripText:SetPoint("CENTER")
  gripText:SetText("//")
  graphFrame.resizeGrip = resizeGrip

  for i = 1, MAX_BARS - 1 do
    local line = graphArea:CreateLine(nil, "OVERLAY")
    line:SetColorTexture(COLOR_LINE[1], COLOR_LINE[2], COLOR_LINE[3], COLOR_LINE[4])
    line:SetThickness(2)
    line:Hide()
    lineSegments[i] = line
  end

  for i = 1, MAX_BARS do
    local bar = graphArea:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(1, 1, 1, 1)
    bar:Hide()
    barTextures[i] = bar

    local hit = CreateFrame("Frame", nil, graphArea)
    hit:EnableMouse(true)
    hit.tipData = nil

    hit:SetScript("OnEnter", function(self)
      if not self.tipData then
        return
      end
      local d = self.tipData
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:ClearLines()
      GameTooltip:AddLine((d.isCurrent and "|cff3fc7eb" or "|cffffffff") .. d.timeRange .. (d.isCurrent and " (current)" or "") .. "|r")
      GameTooltip:AddDoubleLine("XP Gained:", d.xpText, 0.7, 0.7, 0.7, 1, 1, 1)
      GameTooltip:AddDoubleLine("XP / Hour:", d.xphText, 0.7, 0.7, 0.7, 1, 1, 0)
      GameTooltip:AddDoubleLine("Session Avg:", d.avgXphText, 0.7, 0.7, 0.7, 1, 0.82, 0)
      GameTooltip:Show()
    end)

    hit:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    hit:Hide()
    barHitFrames[i] = hit
  end

  graphFrame:SetScript("OnSizeChanged", function(self, newWidth, newHeight)
    saveGraphSize(newWidth, newHeight)
    layoutGraphFrame()
    if self:IsShown() then
      redrawGraph()
    end
  end)

  layoutGraphFrame()
  NS.ManageFrameTicker(graphFrame, 1, redrawGraph, "graphVisible")
  tinsert(UISpecialFrames, graphFrame:GetName())
  graphFrame:Hide()
end

function NS.GraphFeedXP(delta, timestamp)
  if delta <= 0 then
    return
  end

  local lastEvent = graphState.events[#graphState.events]
  local sessionXP = graphState.lastPrunedSessionXP + delta
  if lastEvent and lastEvent.sessionXP then
    sessionXP = lastEvent.sessionXP + delta
  end

  table.insert(graphState.events, {
    t = timestamp,
    xp = delta,
    sessionXP = sessionXP,
  })
  graphState.totalXP = graphState.totalXP + delta
  graphState.dirty = true
end

function NS.GraphReset()
  graphState.anchor = GetTime()
  graphState.events = {}
  graphState.totalXP = 0
  graphState.lastPrunedSessionXP = 0
  graphState.dirty = true

  if graphFrame and graphFrame:IsShown() then
    redrawGraph()
  end
end

function NS.ToggleGraphWindow()
  if not graphFrame then
    NS.InitGraphWindow()
  end
  if graphFrame:IsShown() then
    graphFrame:Hide()
  else
    graphFrame:Show()
  end
end

function NS.SetGraphVisible(on)
  if on then
    if not graphFrame then
      NS.InitGraphWindow()
    end
    graphFrame:Show()
  else
    if graphFrame then
      graphFrame:Hide()
    end
  end
end

function NS.SetGraphZoom(label)
  for _, z in ipairs(ZOOM_LEVELS) do
    if z.label == label then
      DingTimerDB.graphWindowSeconds = z.seconds
      graphState.dirty = true
      if graphFrame and graphFrame:IsShown() then
        redrawGraph()
      end
      return true
    end
  end
  return false
end

function NS.SetGraphScale(mode)
  if mode ~= "visible" and mode ~= "session" and mode ~= "fixed" and mode ~= "auto" then
    return false
  end
  local normalized = NS.NormalizeGraphScaleMode(mode)

  DingTimerDB.graphScaleMode = normalized
  graphState.dirty = true
  if graphFrame and graphFrame:IsShown() then
    redrawGraph()
  end
  return true
end

function NS.CycleGraphScaleMode()
  local current = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
  local nextMode = "visible"
  if current == "visible" then
    nextMode = "session"
  elseif current == "session" then
    nextMode = "fixed"
  end
  NS.SetGraphScale(nextMode)
  return nextMode
end

function NS.SetGraphFixedMax(value)
  DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax(value)
  graphState.dirty = true
  if graphFrame and graphFrame:IsShown() then
    redrawGraph()
  end
  return DingTimerDB.graphFixedMaxXPH
end

function NS.AdjustGraphFixedMax(delta)
  local current = DingTimerDB.graphFixedMaxXPH or 100000
  return NS.SetGraphFixedMax(current + (delta or 0))
end

function NS.GetGraphWindowSize()
  return getStoredGraphSize()
end

function NS.ResetGraphLayout()
  local width, height = NS.ClampGraphWindowSize(DEFAULTS.width, DEFAULTS.height)
  saveGraphSize(width, height)
  DingTimerDB.graphPosition = nil

  if graphFrame then
    graphFrame:ClearAllPoints()
    graphFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)
    graphFrame:SetSize(width, height)
    layoutGraphFrame()
    if graphFrame:IsShown() then
      redrawGraph()
    end
  end
end
