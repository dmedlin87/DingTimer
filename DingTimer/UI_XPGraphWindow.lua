local ADDON, NS = ...

-- Configuration constants
local MIN_SEGMENT_SECONDS = 15
local MIN_BARS = 10
local MAX_BARS = 60
local MAX_RETENTION_SECONDS = 3600

local ZOOM_LEVELS = {
  { label = "3m",  seconds = 180  },
  { label = "5m",  seconds = 300  },
  { label = "15m", seconds = 900  },
  { label = "30m", seconds = 1800 },
  { label = "60m", seconds = 3600 },
}

-- Bar colors {r, g, b, a}
local COLOR_GREEN  = { 0.2, 0.8, 0.2, 0.9 }
local COLOR_RED    = { 0.8, 0.2, 0.2, 0.9 }
local COLOR_GRAY   = { 0.4, 0.4, 0.4, 0.5 }
local BRIGHT_BOOST = 0.15

-- Frame dimensions
local FRAME_WIDTH  = 420
local FRAME_HEIGHT = 220

-- Local state
local graphFrame   = nil
local graphTicker  = nil
local barTextures  = {}
local barHitFrames = {}
local lineSegments = {}

local graphState = {
  anchor = 0,
  events = {},
  dirty = false,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

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

local function pruneGraphEvents(now)
  local cutoff = now - MAX_RETENTION_SECONDS - 60
  local events = graphState.events
  local i = 1
  while events[i] and events[i].t < cutoff do
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

local function aggregateSegments(now, W, S, N, anchor)
  local currentSegIdx = getSegmentIndex(now, anchor, S)
  local firstVisibleIdx = currentSegIdx - N + 1
  local segments = {}

  for _, ev in ipairs(graphState.events) do
    local segIdx = getSegmentIndex(ev.t, anchor, S)
    if segIdx >= firstVisibleIdx and segIdx <= currentSegIdx then
      segments[segIdx] = (segments[segIdx] or 0) + ev.xp
    end
  end

  return segments, currentSegIdx
end

local function zoomLabelForSeconds(seconds)
  for _, z in ipairs(ZOOM_LEVELS) do
    if z.seconds == seconds then return z.label end
  end
  return NS.fmtTime(seconds)
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function RedrawGraph()
  if not graphFrame or not graphFrame:IsShown() then return end

  local now = GetTime()
  graphState.dirty = false

  pruneGraphEvents(now)

  local W = DingTimerDB.graphWindowSeconds or 300
  local N = computeBarCount(W)
  local S = computeSegmentSeconds(W)
  local anchor = graphState.anchor
  if anchor == 0 then anchor = NS.state.sessionStartTime or now end

  local segments, currentSegIdx = aggregateSegments(now, W, S, N, anchor)

  local graphArea = graphFrame.graphArea
  local areaWidth  = graphArea:GetWidth()
  local areaHeight = graphArea:GetHeight()

  local gap = 1
  local barWidth = math.max(2, (areaWidth - (N - 1) * gap) / N)

  -- First pass: build bar data, find max XP/hr
  local barData = {}
  local maxXPH = 0
  local sessionStart = NS.state.sessionStartTime or now

  -- ⚡ Bolt: Optimize average line calculation from O(N*M) to O(N+M)
  -- Since events are sorted by time, we can iterate them alongside the N bars
  -- rather than starting from the beginning of the events list for each bar.
  local evIdx = 1
  local xp_up_to_t = 0

  for i = 1, N do
    local segIdx = currentSegIdx - (N - i)
    local xp = segments[segIdx] or 0
    local xph = (xp / S) * 3600
    
    local t_end = anchor + (segIdx + 1) * S

    while graphState.events[evIdx] and graphState.events[evIdx].t <= t_end do
      xp_up_to_t = xp_up_to_t + graphState.events[evIdx].xp
      evIdx = evIdx + 1
    end

    local elapsed = t_end - sessionStart
    if elapsed < 1 then elapsed = 1 end
    local avgXph = (xp_up_to_t / elapsed) * 3600

    barData[i] = { xp = xp, xph = xph, avgXph = avgXph, segIdx = segIdx }
    if xph > maxXPH then maxXPH = xph end
    if avgXph > maxXPH then maxXPH = avgXph end
  end

  -- Determine Y-axis scale
  local scaleMax
  if DingTimerDB.graphScaleMode == "auto" then
    scaleMax = (maxXPH > 0) and (maxXPH * 1.1) or 1
  else
    scaleMax = DingTimerDB.graphFixedMaxXPH or 100000
  end

  -- Update header labels
  graphFrame.zoomLabel:SetText(NS.C.mid .. zoomLabelForSeconds(W) .. NS.C.r)

  local scaleText
  if DingTimerDB.graphScaleMode == "auto" then
    scaleText = "Auto: " .. NS.FormatNumber(math.floor(scaleMax)) .. " max"
  else
    scaleText = "Fixed: " .. NS.FormatNumber(math.floor(scaleMax)) .. " max"
  end
  graphFrame.scaleLabel:SetText(scaleText)

  -- Second pass: position and color each bar
  local prevXCenter, prevYAvg = nil, nil

  for i = 1, MAX_BARS do
    local bar = barTextures[i]
    local hit = barHitFrames[i]

    if i <= N then
      local d = barData[i]
      local heightFrac = (scaleMax > 0) and math.min(d.xph / scaleMax, 1.0) or 0
      local barHeight = math.max(1, heightFrac * areaHeight)

      -- Determine color
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

      -- Brighten current (rightmost) segment
      if i == N then
        r = math.min(r + BRIGHT_BOOST, 1.0)
        g = math.min(g + BRIGHT_BOOST, 1.0)
        b = math.min(b + BRIGHT_BOOST, 1.0)
      end

      local xPos = (i - 1) * (barWidth + gap)

      bar:ClearAllPoints()
      bar:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", xPos, 0)
      bar:SetSize(barWidth, barHeight)
      bar:SetColorTexture(r, g, b, a)
      bar:Show()

      -- Position hit frame (full column height for easy hovering)
      hit:ClearAllPoints()
      hit:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", xPos, 0)
      hit:SetSize(barWidth, areaHeight)

      -- Tooltip data
      local segStart = anchor + d.segIdx * S
      local segEnd   = segStart + S
      local agoStart = now - segStart
      local agoEnd   = now - segEnd
      hit.tipData = {
        timeRange = NS.fmtTime(math.max(0, agoStart)) .. " ago \226\128\147 " .. NS.fmtTime(math.max(0, agoEnd)) .. " ago",
        xpText    = NS.FormatNumber(d.xp),
        xphText   = NS.FormatNumber(math.floor(d.xph)),
        avgXphText = NS.FormatNumber(math.floor(d.avgXph)),
        isCurrent = (i == N),
      }
      hit:Show()
      
      -- Average Line
      local xCenter = xPos + barWidth / 2
      local avgHeightFrac = (scaleMax > 0) and math.min(d.avgXph / scaleMax, 1.0) or 0
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

---------------------------------------------------------------------------
-- Frame creation
---------------------------------------------------------------------------

function NS.InitGraphWindow()
  if graphFrame then return end

  graphFrame = CreateFrame("Frame", "DingTimerXPGraphWindow", UIParent, "BackdropTemplate")
  graphFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  graphFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -60)

  graphFrame:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  graphFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  graphFrame:SetBackdropBorderColor(0.2, 0.6, 0.8, 1)

  -- Dragging
  graphFrame:SetMovable(true)
  graphFrame:EnableMouse(true)
  graphFrame:RegisterForDrag("LeftButton")
  graphFrame:SetClampedToScreen(true)

  graphFrame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    self:StartMoving()
  end)

  graphFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.graphPosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
  end)

  -- Restore saved position
  if DingTimerDB.graphPosition then
    local pos = DingTimerDB.graphPosition
    graphFrame:ClearAllPoints()
    graphFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  end

  -- Close button
  local closeBtn = CreateFrame("Button", nil, graphFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)

  -- Title
  local title = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText(NS.C.base .. "XP Graph" .. NS.C.r)

  -- Zoom label (right side of header)
  graphFrame.zoomLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  graphFrame.zoomLabel:SetPoint("TOPRIGHT", -32, -14)
  graphFrame.zoomLabel:SetText("")

  -- Separator
  local sep = graphFrame:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(0.2, 0.6, 0.8, 0.5)
  sep:SetSize(FRAME_WIDTH - 24, 1)
  sep:SetPoint("TOP", 0, -35)

  -- Graph rendering area
  local graphArea = CreateFrame("Frame", nil, graphFrame)
  graphArea:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", 12, -42)
  graphArea:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -12, 28)
  graphFrame.graphArea = graphArea

  -- Baseline
  local baseline = graphArea:CreateTexture(nil, "ARTWORK")
  baseline:SetColorTexture(0.3, 0.3, 0.3, 0.6)
  baseline:SetHeight(1)
  baseline:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", 0, 0)
  baseline:SetPoint("BOTTOMRIGHT", graphArea, "BOTTOMRIGHT", 0, 0)

  -- Scale label (bottom-right)
  graphFrame.scaleLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  graphFrame.scaleLabel:SetPoint("BOTTOMRIGHT", graphFrame, "BOTTOMRIGHT", -12, 10)
  graphFrame.scaleLabel:SetText("")

  -- Footer hint (bottom-left)
  local footer = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 12, 10)
  footer:SetText("Zoom:")

  local xPos = 50
  for _, z in ipairs(ZOOM_LEVELS) do
    local btn = CreateFrame("Button", nil, graphFrame, "UIPanelButtonTemplate")
    btn:SetSize(35, 20)
    btn:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", xPos, 6)
    btn:SetText(z.label)
    btn:SetScript("OnClick", function()
      NS.SetGraphZoom(z.label)
    end)
    xPos = xPos + 38
  end

  -- Pre-allocate line segments
  for i = 1, MAX_BARS - 1 do
    local line = graphArea:CreateLine(nil, "OVERLAY")
    line:SetColorTexture(1, 0.82, 0, 0.9) -- gold/yellow line
    line:SetThickness(2)
    line:Hide()
    lineSegments[i] = line
  end

  -- Pre-allocate bar textures and hit frames
  for i = 1, MAX_BARS do
    local bar = graphArea:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(1, 1, 1, 1)
    bar:Hide()
    barTextures[i] = bar

    local hit = CreateFrame("Frame", nil, graphArea)
    hit:EnableMouse(true)
    hit.tipData = nil

    hit:SetScript("OnEnter", function(self)
      if not self.tipData then return end
      local d = self.tipData
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:ClearLines()
      local headerColor = d.isCurrent and "|cff3fc7eb" or "|cffffffff"
      local suffix = d.isCurrent and " (current)" or ""
      GameTooltip:AddLine(headerColor .. d.timeRange .. suffix .. "|r")
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

  -- Show/Hide lifecycle
  graphFrame:SetScript("OnShow", function()
    DingTimerDB.graphVisible = true
    RedrawGraph()
    if not graphTicker then
      graphTicker = C_Timer.NewTicker(1, RedrawGraph)
    end
  end)

  graphFrame:SetScript("OnHide", function()
    DingTimerDB.graphVisible = false
    if graphTicker then
      graphTicker:Cancel()
      graphTicker = nil
    end
  end)

  -- Allow closing with Escape key
  tinsert(UISpecialFrames, graphFrame:GetName())

  graphFrame:Hide()
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function NS.GraphFeedXP(delta, timestamp)
  if delta <= 0 then return end
  table.insert(graphState.events, { t = timestamp, xp = delta })
  graphState.dirty = true
end

function NS.GraphReset()
  graphState.anchor = GetTime()
  graphState.events = {}
  graphState.dirty = true

  if graphFrame and graphFrame:IsShown() then
    RedrawGraph()
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
    if not graphFrame then NS.InitGraphWindow() end
    graphFrame:Show()
  else
    if graphFrame then graphFrame:Hide() end
  end
end

function NS.SetGraphZoom(label)
  for _, z in ipairs(ZOOM_LEVELS) do
    if z.label == label then
      DingTimerDB.graphWindowSeconds = z.seconds
      graphState.dirty = true
      if graphFrame and graphFrame:IsShown() then
        RedrawGraph()
      end
      return true
    end
  end
  return false
end

function NS.SetGraphScale(mode)
  if mode == "fixed" or mode == "auto" then
    DingTimerDB.graphScaleMode = mode
    graphState.dirty = true
    if graphFrame and graphFrame:IsShown() then
      RedrawGraph()
    end
    return true
  end
  return false
end