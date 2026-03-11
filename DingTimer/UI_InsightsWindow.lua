local ADDON, NS = ...

local MAX_ROWS = 10
local MAX_SPARK_POINTS = 20
local FRAME_WIDTH = 640
local FRAME_HEIGHT = 440

local insightsFrame = nil
local rowTexts = {}
local sparkLines = {}

--- Formats a numeric value into a standard "X / hr" string.
--- @param value number The raw rate value (e.g., XP per hour).
--- @return string The formatted rate string.
local function formatRate(value)
  return NS.FormatNumber(math.floor((value or 0) + 0.5)) .. " / hr"
end

--- Formats a percentage trend into a colored string.
--- Depends on a minimum number of recorded sessions to show a valid trend.
--- @param trendPct number The trend change as a raw percentage (-1.5 to 1.5, etc).
--- @param totalSessions number The total amount of available session records.
--- @return string The color-coded trend display text.
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

--- Hides all currently active sparkline segments.
local function hideSparkline()
  for i = 1, #sparkLines do
    sparkLines[i]:Hide()
  end
end

--- Renders a miniature line chart (sparkline) of recent XP/hr values.
--- @param values number[] A series of recent XP/hr numbers.
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

--- Formats a single recorded session into a readable line for the UI list.
--- @param i number The row index.
--- @param session table The stored session data record.
--- @return string The formatted textual row.
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

--- Re-fetches current metrics and redelivers data to the visual elements on the panel.
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

--- Initializes the insights datatable and sparkline UI frame.
--- Consolidates the historical ledger of what a player has recently earned.
--- @param parent frame The host tab or container frame.
--- @return frame The initialized insights panel.
function NS.InitInsightsPanel(parent)
  if insightsFrame then return insightsFrame end

  insightsFrame = CreateFrame("Frame", "DingTimerInsightsPanel", parent)
  insightsFrame:SetAllPoints(parent)

  -- Removed standalone window controls (movable, drag, closeBtn, title, sep)

  -- Position the summary block headers
  local function createSummaryBlock(anchorX, label)
    local labelFS = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelFS:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", anchorX, -16)
    labelFS:SetText(label)

    local valueFS = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueFS:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 0, -2)
    valueFS:SetText("--")
    return valueFS
  end

  insightsFrame.valueMedianXPH = createSummaryBlock(16, "Median XP/hr")
  insightsFrame.valueBestXPH = createSummaryBlock(140, "Best XP/hr")
  insightsFrame.valueAvgLevel = createSummaryBlock(264, "Avg Time in Level")
  insightsFrame.valueTrend = createSummaryBlock(408, "Trend")

  local countLabel = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  countLabel:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -68)
  countLabel:SetText("Stored Sessions")

  insightsFrame.valueCount = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  insightsFrame.valueCount:SetPoint("LEFT", countLabel, "RIGHT", 8, 0)
  insightsFrame.valueCount:SetText("0")

  local sparkLabel = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sparkLabel:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -88)
  sparkLabel:SetText("Recent XP/hr Trend")

  local sparkArea = CreateFrame("Frame", nil, insightsFrame, "BackdropTemplate")
  sparkArea:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -108)
  sparkArea:SetPoint("TOPRIGHT", insightsFrame, "TOPRIGHT", -16, -108)
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
  rowsHeader:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -216)
  rowsHeader:SetText("Recent Sessions (newest first)")

  for i = 1, MAX_ROWS do
    local fs = insightsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", insightsFrame, "TOPLEFT", 16, -230 - ((i - 1) * 14))
    fs:SetJustifyH("LEFT")
    fs:SetWidth(FRAME_WIDTH - 32)
    fs:SetText("")
    rowTexts[i] = fs
  end

  local clearState = 0
  local clearTimer
  local clearBtn = CreateFrame("Button", nil, insightsFrame, "UIPanelButtonTemplate")
  clearBtn:SetSize(120, 24)
  clearBtn:SetPoint("BOTTOMLEFT", insightsFrame, "BOTTOMLEFT", 16, 10)
  clearBtn:SetText("Clear History")
  clearBtn:SetScript("OnClick", function()
    if clearState == 0 then
      clearState = 1
      clearBtn:SetText("|cffff4040Confirm Clear|r")
      if clearTimer then clearTimer:Cancel() end
      clearTimer = C_Timer.NewTimer(3, function()
        clearState = 0
        clearBtn:SetText("Clear History")
      end)
    else
      clearState = 0
      if clearTimer then clearTimer:Cancel() end
      clearBtn:SetText("Clear History")
      if NS.ClearProfileSessions then
        NS.ClearProfileSessions()
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights history cleared for this character.")
      end
    end
  end)

  -- Removed close button since we use tabs now

  insightsFrame:SetScript("OnShow", function()
    refreshInsights()
  end)

  insightsFrame:Hide()
  return insightsFrame
end

-- Removed ToggleInsightsWindow and SetInsightsVisible since we use tabs

--- Triggers an immediate refresh if the insights window is actively visible.
function NS.RefreshInsightsWindow()
  if insightsFrame and insightsFrame:IsShown() then
    refreshInsights()
  end
end
