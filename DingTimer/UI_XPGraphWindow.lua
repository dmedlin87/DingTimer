local ADDON, NS = ...

local MIN_SEGMENT_SECONDS = 15
local MIN_BARS = 10
local MAX_BARS = 60
local MAX_RETENTION_SECONDS = 3600
local GRID_LINE_COUNT = 4
local TIME_LABEL_COUNT = 5

local ZOOM_LEVELS = {
  { label = "3m", seconds = 180 },
  { label = "5m", seconds = 300 },
  { label = "15m", seconds = 900 },
  { label = "30m", seconds = 1800 },
  { label = "60m", seconds = 3600 },
}

-- ⚡ Pre-built lookup table to replace ipairs search in hot path
local ZOOM_SECONDS_TO_LABEL = {}
for _, z in ipairs(ZOOM_LEVELS) do
  ZOOM_SECONDS_TO_LABEL[z.seconds] = z.label
end

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
local segmentRows = {}

local graphState = {
  anchor = 0,
  events = {},
  totalXP = 0,
  lastPrunedSessionXP = 0,
  dirty = false,
  lastSegmentIndex = nil,
  lastAreaWidth = nil,
  lastAreaHeight = nil,
  cachedScaleMax = 1,
  cachedVisiblePeak = 0,
  cachedHistoryPeak = 0,
  lastAxisScaleMax = nil,
  lastAxisWidth = nil,
  lastAxisHeight = nil,
}

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


local function zoomLabelForSeconds(seconds)
  return ZOOM_SECONDS_TO_LABEL[seconds] or NS.fmtTime(seconds)
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

--- Repositions and dynamically scales inner layout components of the graph frame.
--- Responds to resize events or zoom scale changes.
local function layoutGraphFrame()
  if not graphFrame then
    return
  end

  local width = graphFrame:GetWidth()
  local cardGap = 8
  local cardWidth = math.floor((width - 24 - (cardGap * 3)) / 4)
  local left = 12

  -- Separator was removed
  -- graphFrame.separator:SetWidth(width - 24)

  for i = 1, #graphFrame.summaryCards do
    local card = graphFrame.summaryCards[i]
    card:ClearAllPoints()
    card:SetSize(cardWidth, 48)
    card:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", left, -6)
    left = left + cardWidth + cardGap
  end

  graphFrame.graphArea:ClearAllPoints()
  graphFrame.graphArea:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", 64, -76)
  graphFrame.graphArea:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -18, 132)

  graphFrame.legendLabel:ClearAllPoints()
  graphFrame.legendLabel:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, 108)

  graphFrame.segmentSummaryLabel:ClearAllPoints()
  graphFrame.segmentSummaryLabel:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, 92)

  local rowY = 74
  for i = 1, #segmentRows do
    segmentRows[i]:ClearAllPoints()
    segmentRows[i]:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, rowY)
    rowY = rowY - 16
  end

  graphFrame.zoomFooter:ClearAllPoints()
  graphFrame.zoomFooter:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 16, 18)

  local zoomX = 56
  for i = 1, #graphFrame.zoomButtons do
    local btn = graphFrame.zoomButtons[i]
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", zoomX, 12)
    zoomX = zoomX + 42
  end

  graphFrame.fixedMaxLabel:ClearAllPoints()
  graphFrame.fixedMaxLabel:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -164, 42)

  graphFrame.decreaseFixedButton:ClearAllPoints()
  graphFrame.decreaseFixedButton:SetPoint("RIGHT", graphFrame.fixedMaxLabel, "LEFT", -6, 0)

  graphFrame.increaseFixedButton:ClearAllPoints()
  graphFrame.increaseFixedButton:SetPoint("LEFT", graphFrame.fixedMaxLabel, "RIGHT", 6, 0)

  graphFrame.scaleModeButton:ClearAllPoints()
  graphFrame.scaleModeButton:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -140, 12)

  graphFrame.fitButton:ClearAllPoints()
  graphFrame.fitButton:SetPoint("LEFT", graphFrame.scaleModeButton, "RIGHT", 6, 0)

  -- Resize grip is now on the main window, but let's hide the graph's grip
  if graphFrame.resizeGrip then
    graphFrame.resizeGrip:Hide()
  end
end

--- Renders the backing horizontal grid lines and labels.
--- @param scaleMax number The maximum value of the graph layout.
--- @param now number The current active timestamp.
--- @param windowSeconds number The graph's total visible duration window.
local function updateAxis(scaleMax, now, windowSeconds)
  if not graphFrame then return end
  local graphArea = graphFrame.graphArea
  local areaWidth = math.max(graphArea:GetWidth(), 1)
  local areaHeight = math.max(graphArea:GetHeight(), 1)

  -- ⚡ Only reposition grid lines and Y-axis labels when scale or dimensions change
  local gridDirty = (graphState.lastAxisScaleMax ~= scaleMax
    or graphState.lastAxisWidth ~= areaWidth
    or graphState.lastAxisHeight ~= areaHeight)

  if gridDirty then
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

    graphState.lastAxisScaleMax = scaleMax
    graphState.lastAxisWidth = areaWidth
    graphState.lastAxisHeight = areaHeight
  end

  -- Time labels always update (they show "Xm Ys ago" which changes every second)
  for i = 1, TIME_LABEL_COUNT do
    local frac = (i - 1) / (TIME_LABEL_COUNT - 1)
    local secondsAgo = math.floor((1 - frac) * windowSeconds + 0.5)
    local label = timeAxisLabels[i]

    if gridDirty then
      label:ClearAllPoints()
      label:SetPoint("TOP", graphArea, "BOTTOMLEFT", frac * areaWidth, -6)
    end
    if i == TIME_LABEL_COUNT then
      label:SetText("Now")
    else
      label:SetText(formatAxisTime(secondsAgo))
    end
  end
end

local function refreshControlState(scaleMax, visiblePeak, historyPeak, snapshot)
  if not graphFrame then return end
  local mode = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
  local coach = NS.GetCoachStatus and NS.GetCoachStatus(snapshot.now) or nil
  local goal = coach and coach.goal or nil
  local bestSegment = coach and coach.bestSegment or nil
  local currentSegment = coach and coach.currentSegment or nil
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
    "Goal Pace",
    (goal and goal.targetXph and goal.targetXph > 0) and formatRateShort(goal.targetXph) or "--",
    goal and goal.goalLabel or "No goal"
  )

  applySummaryCard(
    graphFrame.summaryCards[4],
    "Best Segment",
    bestSegment and formatRateShort(bestSegment.avgXph) or "--",
    bestSegment and tostring(bestSegment.zone or "Unknown") or "No completed segment"
  )

  if currentSegment and goal and goal.targetXph and goal.targetXph > 0 then
    local delta = (currentSegment.avgXph or 0) - goal.targetXph
    local sign = (delta >= 0) and "+" or "-"
    graphFrame.segmentSummaryLabel:SetText(string.format(
      "Current segment: %s  |  %s XP/hr  |  %s%s vs goal",
      tostring(currentSegment.zone or "Unknown"),
      NS.FormatNumber(NS.Round(currentSegment.avgXph or 0)),
      sign,
      NS.FormatNumber(NS.Round(math.abs(delta)))
    ))
  elseif currentSegment then
    graphFrame.segmentSummaryLabel:SetText(string.format(
      "Current segment: %s  |  %s XP/hr over %s",
      tostring(currentSegment.zone or "Unknown"),
      NS.FormatNumber(NS.Round(currentSegment.avgXph or 0)),
      NS.fmtTime(currentSegment.durationSec or 0)
    ))
  else
    graphFrame.segmentSummaryLabel:SetText("Current segment starts once the session begins tracking.")
  end

  local segmentValues = {}
  local recentSegments = coach and coach.recentSegments or {}
  for i = 1, math.min(#recentSegments, #segmentRows) do
    local segment = recentSegments[i]
    local compareText = ""
    if goal and goal.targetXph and goal.targetXph > 0 then
      local delta = (segment.avgXph or 0) - goal.targetXph
      local sign = (delta >= 0) and "+" or "-"
      compareText = string.format("  |  %s%s vs goal", sign, NS.FormatNumber(NS.Round(math.abs(delta))))
    end
    local prefix = segment.isCurrent and "*" or tostring(i)
    segmentValues[i] = string.format(
      "%s  %s  |  %s XP/hr  |  %s%s",
      prefix,
      tostring(segment.zone or "Unknown"),
      NS.FormatNumber(NS.Round(segment.avgXph or 0)),
      NS.fmtTime(segment.durationSec or 0),
      compareText
    )
  end
  NS.UI.SetRows(
    segmentRows,
    segmentValues,
    NS.C.mid .. "No session segments yet. Manual splits and zone changes will appear here." .. NS.C.r
  )
end

--- Pulls new tracking states and repaints the entire graph area.
--- Called periodically to advance the graph or when settings dictate a full manual redraw.
local function redrawGraph()
  if not graphFrame or not graphFrame:IsShown() then
    return
  end

  local now = GetTime()
  local wasDirty = graphState.dirty
  pruneGraphEvents(now)

  local windowSeconds = DingTimerDB.graphWindowSeconds or 300
  local segmentCount = NS.ComputeBarCount(windowSeconds, MIN_SEGMENT_SECONDS, MIN_BARS, MAX_BARS)
  local segSeconds = NS.ComputeSegmentSeconds(windowSeconds, segmentCount)
  local anchor = graphState.anchor
  if anchor == 0 then
    anchor = NS.state.sessionStartTime or now
  end

  local graphArea = graphFrame.graphArea
  local areaWidth = math.max(graphArea:GetWidth(), 1)
  local areaHeight = math.max(graphArea:GetHeight(), 1)
  local snapshot = NS.GetSessionSnapshot(now)
  local currentSegIdx = NS.GetSegmentIndex(now, anchor, segSeconds)
  if (not wasDirty)
    and graphState.lastSegmentIndex == currentSegIdx
    and graphState.lastAreaWidth == areaWidth
    and graphState.lastAreaHeight == areaHeight then
    updateAxis(graphState.cachedScaleMax or 1, now, windowSeconds)
    refreshControlState(graphState.cachedScaleMax or 1, graphState.cachedVisiblePeak or 0, graphState.cachedHistoryPeak or 0, snapshot)
    graphFrame.legendLabel:SetText("|cff6fd090Green|r up  |  |cffe86a6aRed|r down  |  |cffffd130Gold|r session average  |  Segment rows show goal delta")
    if (graphState.cachedVisiblePeak or 0) <= 0 and snapshot.sessionXP <= 0 then
      graphFrame.emptyState:Show()
    else
      graphFrame.emptyState:Hide()
    end
    return
  end

  graphState.dirty = false
  -- ⚡ Single-pass aggregation: computes both visible segments and history peak together
  local segments, segIdx_out, historyPeak = NS.AggregateAndComputePeak(
    graphState.events, now, segSeconds, segmentCount, anchor, MAX_RETENTION_SECONDS
  )
  local gap = 2
  local barWidth = math.max(3, (areaWidth - ((segmentCount - 1) * gap)) / segmentCount)

  local sessionStart = NS.state.sessionStartTime or now
  local avgSeries = NS.BuildAverageSeries(
    graphState.events,
    {
      baselineSessionXP = graphState.lastPrunedSessionXP,
      now = now,
      sessionStart = sessionStart,
      anchor = anchor,
      segSeconds = segSeconds,
      currentSegIdx = currentSegIdx,
      segmentCount = segmentCount,
    }
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

  local scaleMax = NS.ResolveGraphScaleMax(DingTimerDB.graphScaleMode, visiblePeak, avgPeak, historyPeak, DingTimerDB.graphFixedMaxXPH)
  graphState.lastSegmentIndex = currentSegIdx
  graphState.lastAreaWidth = areaWidth
  graphState.lastAreaHeight = areaHeight
  graphState.cachedScaleMax = scaleMax
  graphState.cachedVisiblePeak = visiblePeak
  graphState.cachedHistoryPeak = historyPeak

  updateAxis(scaleMax, now, windowSeconds)
  refreshControlState(scaleMax, visiblePeak, historyPeak, snapshot)

  -- Removed subtitle
  graphFrame.legendLabel:SetText("|cff6fd090Green|r up  |  |cffe86a6aRed|r down  |  |cffffd130Gold|r session average  |  Segment rows show goal delta")
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

--- Initializes the primary graph panel UI.
--- Contains the coordinate system, layout definition, and zoom controls.
--- @param parent Frame The host tab or container frame.
--- @return Frame The initialized and structured graph panel.
function NS.InitGraphPanel(parent)
  if graphFrame then
    return graphFrame
  end

  graphFrame = CreateFrame("Frame", "DingTimerXPGraphPanel", parent)
  graphFrame:SetAllPoints(parent)

  -- Removed standalone window controls (movable, resizable, drag, closeBtn, title, separator)

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

  local segmentSummaryLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  segmentSummaryLabel:SetWidth(640)
  segmentSummaryLabel:SetJustifyH("LEFT")
  segmentSummaryLabel:SetText("")
  graphFrame.segmentSummaryLabel = segmentSummaryLabel

  segmentRows = NS.UI.CreateListRows(graphFrame, 16, -1, 640, 4, 16, "GameFontDisableSmall")

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

  -- Removed resize grip
  for i = 1, MAX_BARS - 1 do
    local line = NS.CreateLineCompat(graphArea, "OVERLAY")
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
    layoutGraphFrame()
    graphState.lastAreaWidth = nil
    graphState.lastAreaHeight = nil
    if self:IsShown() then
      redrawGraph()
    end
  end)

  layoutGraphFrame()
  NS.ManageFrameTicker(graphFrame, 1, redrawGraph)
  graphFrame:Hide()
  return graphFrame --[[@as Frame]]
end

--- Inserts a new XP earning event to be drawn as a spike in the graph.
--- Extends tracking buffers intelligently and purges old entries automatically.
--- @param delta number The amount of experience points earned.
--- @param timestamp number The core game time stamp of the event.
function NS.GraphFeedXP(delta, timestamp)
  if delta <= 0 then
    return
  end

  -- Keep retention bounded even when the graph is hidden for a long session.
  pruneGraphEvents(timestamp)

  -- Optimization: direct array indexing is ~1.25x faster than table.insert
  local events = graphState.events
  local len = #events
  local lastEvent = events[len]
  local sessionXP = graphState.lastPrunedSessionXP + delta
  if lastEvent and lastEvent.sessionXP then
    sessionXP = lastEvent.sessionXP + delta
  end

  events[len + 1] = {
    t = timestamp,
    xp = delta,
    sessionXP = sessionXP,
  }
  graphState.totalXP = graphState.totalXP + delta
  graphState.dirty = true
end

--- Clears all visual memory and events from the local display cache.
function NS.GraphReset()
  graphState.anchor = GetTime()
  graphState.events = {}
  graphState.totalXP = 0
  graphState.lastPrunedSessionXP = 0
  graphState.dirty = true
  graphState.lastSegmentIndex = nil
  graphState.lastAreaWidth = nil
  graphState.lastAreaHeight = nil
  graphState.cachedScaleMax = 1
  graphState.cachedVisiblePeak = 0
  graphState.cachedHistoryPeak = 0
  graphState.lastAxisScaleMax = nil
  graphState.lastAxisWidth = nil
  graphState.lastAxisHeight = nil

  if graphFrame and graphFrame:IsShown() then
    redrawGraph()
  end
end

-- Removed ToggleGraphWindow and SetGraphVisible as we use Tabs now

--- Adjusts the visible horizontal window timespan by applying a mapped zoom preset.
--- @param label string The identifier for the zoom level (e.g., "15m").
--- @return boolean True if the zoom was applied successfully.
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

--- Modifies how the upper Y-axis boundary responds to incoming data.
--- @param mode string The desired scaling behavior ("visible", "session", "fixed", "auto").
--- @return boolean True if mode changed successfully.
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
  local n = tonumber(value)
  if not n then return end
  DingTimerDB.graph.fixedMax = NS.ClampGraphFixedMax(n)
  DingTimerDB.graph.scaleMode = "fixed"
  if NS.RefreshSettingsPanel then NS.RefreshSettingsPanel() end
  NS.GraphSetNeedsUpdate()
end

function NS.AdjustGraphFixedMax(delta)
  local current = DingTimerDB.graphFixedMaxXPH or 100000
  return NS.SetGraphFixedMax(current + (delta or 0))
end
