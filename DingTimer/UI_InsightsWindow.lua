local ADDON, NS = ...

local MAX_ROWS = 10
local MAX_SPARK_POINTS = 20
local FRAME_WIDTH = 560
local FRAME_HEIGHT = 420

local insightsFrame = nil
local rowTexts = {}
local sparkLines = {}

local function formatRate(value)
  return NS.FormatNumber(math.floor((value or 0) + 0.5)) .. " / hr"
end

local function formatTrend(trendPct, totalSessions)
  if totalSessions < 4 then
    return NS.C.mid .. "--" .. NS.C.r
  end

  local color = NS.C.mid
  if trendPct > 0.25 then
    color = NS.C.xp
  elseif trendPct < -0.25 then
    color = NS.C.bad
  end

  return string.format("%s%.1f%%%s", color, trendPct, NS.C.r)
end

local function hideSparkline()
  for i = 1, #sparkLines do
    sparkLines[i]:Hide()
  end
end

local function drawSparkline(values)
  hideSparkline()

  local n = #values
  if n < 2 then return end

  local area = insightsFrame.sparkArea
  local width = math.max(area:GetWidth(), 1)
  local height = math.max(area:GetHeight(), 1)

  local maxValue = 0
  for i = 1, n do
    if values[i] > maxValue then
      maxValue = values[i]
    end
  end
  if maxValue <= 0 then
    maxValue = 1
  end

  local prevX, prevY = nil, nil
  for i = 1, n do
    local x = ((i - 1) / (n - 1)) * width
    local y = (values[i] / maxValue) * height
    if prevX ~= nil then
      local line = sparkLines[i - 1]
      line:SetStartPoint("BOTTOMLEFT", prevX, prevY)
      line:SetEndPoint("BOTTOMLEFT", x, y)
      line:Show()
    end
    prevX = x
    prevY = y
  end
end

local function formatSessionRow(i, session)
  local reason = session.reason or "UNKNOWN"
  local zone = session.zone or "Unknown"
  local money = NS.fmtMoney(session.moneyNetCopper or 0)
  local levelStart = tostring(session.levelStart or "?")
  local levelEnd = tostring(session.levelEnd or "?")
  local dur = NS.fmtTime(session.durationSec or 0)
  local xph = NS.FormatNumber(math.floor((session.avgXph or 0) + 0.5))

  return string.format(
    "%02d) Lv %s-%s  %s  %s XP/hr  %s  %s  [%s]",
    i, levelStart, levelEnd, dur, xph, money, zone, reason
  )
end

local function refreshInsights()
  if not insightsFrame or not insightsFrame:IsShown() then return end

  local summary = NS.GetInsightsSummary(MAX_ROWS)
  insightsFrame.valueMedianXPH:SetText(formatRate(summary.medianXph))
  insightsFrame.valueBestXPH:SetText(formatRate(summary.bestXph))
  insightsFrame.valueAvgLevel:SetText(NS.fmtTime(summary.avgLevelTime))
  insightsFrame.valueTrend:SetText(formatTrend(summary.trendPct, summary.totalSessions))
  insightsFrame.valueCount:SetText(tostring(summary.totalSessions))

  if summary.totalSessions == 0 then
    rowTexts[1]:SetText(NS.C.mid .. "No session history yet. Start leveling to build insights." .. NS.C.r)
    for i = 2, MAX_ROWS do
      rowTexts[i]:SetText("")
    end
    drawSparkline({})
    return
  end

  for i = 1, MAX_ROWS do
    local row = summary.rows[i]
    if row then
      rowTexts[i]:SetText(formatSessionRow(i, row))
    else
      rowTexts[i]:SetText("")
    end
  end

  drawSparkline(summary.chartValues or {})
end

function NS.InitInsightsWindow()
  if insightsFrame then return end

  insightsFrame = CreateFrame("Frame", "DingTimerInsightsWindow", UIParent, "BackdropTemplate")
  insightsFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  insightsFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 10)

  NS.ApplyThemeToFrame(insightsFrame)

  insightsFrame:SetMovable(true)
  insightsFrame:EnableMouse(true)
  insightsFrame:RegisterForDrag("LeftButton")
  insightsFrame:SetClampedToScreen(true)

  insightsFrame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    self:StartMoving()
  end)

  insightsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.insightsWindowPosition = {
      point = point,
      relativePoint = relativePoint,
      xOfs = xOfs,
      yOfs = yOfs
    }
  end)

  if DingTimerDB.insightsWindowPosition then
    local pos = DingTimerDB.insightsWindowPosition
    insightsFrame:ClearAllPoints()
    insightsFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  end

  local closeBtn = CreateFrame("Button", nil, insightsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)

  local title = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText(NS.C.base .. "Session Insights" .. NS.C.r)

  local sep = insightsFrame:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(0.2, 0.6, 0.8, 0.5)
  sep:SetSize(FRAME_WIDTH - 24, 1)
  sep:SetPoint("TOP", 0, -35)

  local function createSummaryBlock(anchorX, label)
    local labelFS = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelFS:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", anchorX, -48)
    labelFS:SetText(label)

    local valueFS = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueFS:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 0, -2)
    valueFS:SetText("--")
    return valueFS
  end

  insightsFrame.valueMedianXPH = createSummaryBlock(16, "Median XP/hr")
  insightsFrame.valueBestXPH = createSummaryBlock(160, "Best XP/hr")
  insightsFrame.valueAvgLevel = createSummaryBlock(304, "Avg Time in Level")
  insightsFrame.valueTrend = createSummaryBlock(448, "Trend")

  local countLabel = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  countLabel:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -95)
  countLabel:SetText("Stored Sessions")

  insightsFrame.valueCount = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  insightsFrame.valueCount:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
  insightsFrame.valueCount:SetText("0")

  local sparkLabel = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sparkLabel:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -115)
  sparkLabel:SetText("Recent XP/hr Trend")

  local sparkArea = CreateFrame("Frame", nil, insightsFrame, "BackdropTemplate")
  sparkArea:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -132)
  sparkArea:SetPoint("TOPRIGHT", insightsFrame, "TOPRIGHT", -16, -132)
  sparkArea:SetHeight(92)
  sparkArea:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  sparkArea:SetBackdropColor(0, 0, 0, 0.35)
  sparkArea:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
  insightsFrame.sparkArea = sparkArea

  local baseline = sparkArea:CreateTexture(nil, "ARTWORK")
  baseline:SetColorTexture(0.35, 0.35, 0.35, 0.7)
  baseline:SetHeight(1)
  baseline:SetPoint("BOTTOMLEFT", sparkArea, "BOTTOMLEFT", 0, 0)
  baseline:SetPoint("BOTTOMRIGHT", sparkArea, "BOTTOMRIGHT", 0, 0)

  for i = 1, MAX_SPARK_POINTS - 1 do
    local line = sparkArea:CreateLine(nil, "OVERLAY")
    line:SetColorTexture(0.24, 0.78, 0.92, 0.95)
    line:SetThickness(2)
    line:Hide()
    sparkLines[i] = line
  end

  local rowsHeader = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rowsHeader:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -236)
  rowsHeader:SetText("Recent Sessions (newest first)")

  for i = 1, MAX_ROWS do
    local fs = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -250 - ((i - 1) * 14))
    fs:SetJustifyH("LEFT")
    fs:SetWidth(FRAME_WIDTH - 32)
    fs:SetText("")
    rowTexts[i] = fs
  end

  local clearBtn = CreateFrame("Button", nil, insightsFrame, "UIPanelButtonTemplate")
  clearBtn:SetSize(120, 24)
  clearBtn:SetPoint("BOTTOMLEFT", insightsFrame, "BOTTOMLEFT", 16, 10)
  clearBtn:SetText("Clear History")
  clearBtn:SetScript("OnClick", function()
    if NS.ClearProfileSessions then
      NS.ClearProfileSessions()
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights history cleared for this character.")
    end
  end)

  local closeFooterBtn = CreateFrame("Button", nil, insightsFrame, "UIPanelButtonTemplate")
  closeFooterBtn:SetSize(120, 24)
  closeFooterBtn:SetPoint("BOTTOMRIGHT", insightsFrame, "BOTTOMRIGHT", -16, 10)
  closeFooterBtn:SetText("Close")
  closeFooterBtn:SetScript("OnClick", function()
    insightsFrame:Hide()
  end)

  insightsFrame:SetScript("OnShow", function()
    DingTimerDB.insightsWindowVisible = true
    refreshInsights()
  end)

  insightsFrame:SetScript("OnHide", function()
    DingTimerDB.insightsWindowVisible = false
  end)

  tinsert(UISpecialFrames, insightsFrame:GetName())
  insightsFrame:Hide()
end

function NS.ToggleInsightsWindow()
  if not insightsFrame then
    NS.InitInsightsWindow()
  end

  if insightsFrame:IsShown() then
    insightsFrame:Hide()
  else
    insightsFrame:Show()
  end
end

function NS.SetInsightsVisible(on)
  if on then
    if not insightsFrame then
      NS.InitInsightsWindow()
    end
    insightsFrame:Show()
  else
    if insightsFrame then
      insightsFrame:Hide()
    end
  end
end

function NS.RefreshInsightsWindow()
  if insightsFrame and insightsFrame:IsShown() then
    refreshInsights()
  end
end
