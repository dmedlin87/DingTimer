local ADDON, NS = ...

local MAX_ROWS = 8
local MAX_SPARK_POINTS = 20

local insightsFrame = nil
local rowTexts = {}
local sparkLines = {}

local function formatRate(value)
  return NS.FormatNumber(NS.Round(value or 0)) .. " / hr"
end

local function isPvpHistoryView()
  return NS.GetPvpHistoryView and NS.GetPvpHistoryView() == "pvp"
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

local function formatSessionRow(i, session)
  return string.format(
    "%02d) Lv %s-%s  %s  %s XP/hr  %s  %s  [%s]",
    i,
    tostring(session.levelStart or "?"),
    tostring(session.levelEnd or "?"),
    NS.fmtTime(session.durationSec or 0),
    NS.FormatNumber(NS.Round(session.avgXph or 0)),
    NS.fmtMoney(session.moneyNetCopper or 0),
    session.zone or "Unknown",
    session.reason or "UNKNOWN"
  )
end

local function formatPvpSessionRow(i, session)
  return string.format(
    "%02d) %s  %s Honor/hr  %s HK/hr  %s Honor  %s HKs  [%s]",
    i,
    NS.fmtTime(session.durationSec or 0),
    NS.FormatNumber(NS.Round(session.avgHonorPerHour or 0)),
    NS.FormatNumber(NS.Round(session.avgHKPerHour or 0)),
    NS.FormatNumber(session.honorGained or 0),
    NS.FormatNumber(session.hkGained or 0),
    session.zone or "Unknown"
  )
end

local function hideSparkline()
  for i = 1, #sparkLines do
    sparkLines[i]:Hide()
  end
end

local function drawSparkline(values)
  hideSparkline()
  local n = #values
  if n < 2 or not insightsFrame then
    return
  end

  local area = insightsFrame.sparkArea
  local width = math.max(area:GetWidth(), 1)
  local height = math.max(area:GetHeight(), 1)

  local maxValue = 1
  for i = 1, n do
    if values[i] > maxValue then
      maxValue = values[i]
    end
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

local function updateComparison(summary)
  local frame = insightsFrame
  if not frame or not frame.compareLine1 or not frame.compareLine2 then
    return
  end

  if isPvpHistoryView() then
    local snapshot = NS.GetPvpSnapshot and NS.GetPvpSnapshot(GetTime()) or nil
    local lastSession = summary.lastSession
    if not snapshot or not lastSession then
      frame.compareLine1:SetText("No prior PvP session to compare against.")
      frame.compareLine2:SetText("Start tracking Honor to build PvP history context.")
      return
    end

    local delta = (snapshot.sessionHonorPerHour or 0) - (lastSession.avgHonorPerHour or 0)
    local deltaColor = NS.C.mid
    if delta > 0 then
      deltaColor = NS.C.xp
    elseif delta < 0 then
      deltaColor = NS.C.bad
    end

    frame.compareLine1:SetText(string.format(
      "Current PvP session: %s Honor/hr over %s in %s",
      NS.FormatNumber(NS.Round(snapshot.sessionHonorPerHour or 0)),
      NS.fmtTime(snapshot.sessionElapsed or 0),
      snapshot.zone or "Unknown"
    ))
    frame.compareLine2:SetText(string.format(
      "Last PvP session: %s Honor/hr over %s  |  Delta %s%s%s",
      NS.FormatNumber(NS.Round(lastSession.avgHonorPerHour or 0)),
      NS.fmtTime(lastSession.durationSec or 0),
      deltaColor,
      NS.FormatNumber(NS.Round(delta)),
      NS.C.r
    ))
    return
  end

  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(GetTime()) or nil
  local lastSession = summary.lastSession
  if not snapshot or not lastSession then
    frame.compareLine1:SetText("No prior session to compare against.")
    frame.compareLine2:SetText("Complete a run to start building history context.")
    return
  end

  local delta = snapshot.sessionXph - (lastSession.avgXph or 0)
  local deltaColor = NS.C.mid
  if delta > 0 then
    deltaColor = NS.C.xp
  elseif delta < 0 then
    deltaColor = NS.C.bad
  end

  frame.compareLine1:SetText(string.format(
    "Current run: %s XP/hr over %s in %s",
    NS.FormatNumber(NS.Round(snapshot.sessionXph or 0)),
    NS.fmtTime(snapshot.sessionElapsed or 0),
    snapshot.zone or "Unknown"
  ))
  frame.compareLine2:SetText(string.format(
    "Last run: %s XP/hr over %s  |  Delta %s%s%s",
    NS.FormatNumber(NS.Round(lastSession.avgXph or 0)),
    NS.fmtTime(lastSession.durationSec or 0),
    deltaColor,
    NS.FormatNumber(NS.Round(delta)),
    NS.C.r
  ))
end

local function updateZoneLeaders(summary)
  local frame = insightsFrame
  if not frame or not frame.zoneRows then
    return
  end

  local values = {}
  for i = 1, 3 do
    local zone = summary.zoneLeaders[i]
    if zone then
      values[i] = string.format(
        "%d. %s  |  %s %s avg across %d run%s",
        i,
        zone.zone or "Unknown",
        NS.FormatNumber(NS.Round(zone.avgXph or 0)),
        isPvpHistoryView() and "Honor/hr" or "XP/hr",
        zone.sessions or 0,
        ((zone.sessions or 0) == 1) and "" or "s"
      )
    end
  end
  NS.UI.SetRows(
    frame.zoneRows,
    values,
    NS.C.mid .. "No zone leaders yet. Finish a few sessions first." .. NS.C.r
  )
end

local function refreshInsights()
  if not insightsFrame or not insightsFrame:IsShown() then
    return
  end

  local pvpView = isPvpHistoryView()
  if insightsFrame.xpToggle and insightsFrame.pvpToggle then
    if pvpView then
      insightsFrame.pvpToggle:LockHighlight()
      insightsFrame.xpToggle:UnlockHighlight()
    else
      insightsFrame.xpToggle:LockHighlight()
      insightsFrame.pvpToggle:UnlockHighlight()
    end
  end
  local summary = pvpView and (NS.GetPvpInsightsSummary and NS.GetPvpInsightsSummary(MAX_ROWS) or { totalSessions = 0, rows = {}, chartValues = {}, zoneLeaders = {} })
    or NS.GetInsightsSummary(MAX_ROWS)

  if pvpView then
    insightsFrame.labels.median:SetText("Median Honor/hr")
    insightsFrame.labels.best:SetText("Best Honor/hr")
    insightsFrame.labels.avg:SetText("Median HK/hr")
    insightsFrame.labels.bestSession:SetText("Best PvP Session")
    insightsFrame.labels.compare:SetText("Current vs Last PvP Session")
    insightsFrame.labels.spark:SetText("Recent Honor/hr Trend")
    insightsFrame.labels.rows:SetText("Recent PvP Sessions (newest first)")
    insightsFrame.valueMedianXPH:SetText(formatRate(summary.medianHonorPerHour))
    insightsFrame.valueBestXPH:SetText(formatRate(summary.bestHonorPerHour))
    insightsFrame.valueAvgLevel:SetText(formatRate(summary.medianHKPerHour))
    insightsFrame.valueTrend:SetText(formatTrend(summary.trendPct, summary.totalSessions))
    insightsFrame.valueCount:SetText(tostring(summary.totalSessions))
    insightsFrame.bestSessionValue:SetText(
      summary.bestSession and string.format(
        "%s in %s",
        summary.bestSession.zone or "Unknown",
        formatRate(summary.bestSession.avgHonorPerHour or 0)
      ) or "--"
    )
  else
    insightsFrame.labels.median:SetText("Median XP/hr")
    insightsFrame.labels.best:SetText("Best XP/hr")
    insightsFrame.labels.avg:SetText("Avg Time in Level")
    insightsFrame.labels.bestSession:SetText("Best Session")
    insightsFrame.labels.compare:SetText("Current vs Last Run")
    insightsFrame.labels.spark:SetText("Recent XP/hr Trend")
    insightsFrame.labels.rows:SetText("Recent Sessions (newest first)")
    insightsFrame.valueMedianXPH:SetText(formatRate(summary.medianXph))
    insightsFrame.valueBestXPH:SetText(formatRate(summary.bestXph))
    insightsFrame.valueAvgLevel:SetText(NS.fmtTime(summary.avgLevelTime))
    insightsFrame.valueTrend:SetText(formatTrend(summary.trendPct, summary.totalSessions))
    insightsFrame.valueCount:SetText(tostring(summary.totalSessions))
    insightsFrame.bestSessionValue:SetText(
      summary.bestSession and string.format(
        "%s in %s",
        summary.bestSession.zone or "Unknown",
        formatRate(summary.bestSession.avgXph or 0)
      ) or "--"
    )
  end

  if summary.totalSessions == 0 then
    rowTexts[1]:SetText(NS.C.mid .. (pvpView and "No PvP history yet. Start earning Honor to build history." or "No session history yet. Start leveling to build history.") .. NS.C.r)
    for i = 2, MAX_ROWS do
      rowTexts[i]:SetText("")
    end
    updateComparison(summary)
    updateZoneLeaders(summary)
    drawSparkline({})
    insightsFrame.recapValue:SetText(pvpView and "No PvP recap stored yet." or "No recap stored yet.")
    return
  end

  for i = 1, MAX_ROWS do
    local row = summary.rows[i]
    rowTexts[i]:SetText(row and ((pvpView and formatPvpSessionRow(i, row)) or formatSessionRow(i, row)) or "")
  end

  local recap = pvpView
    and (summary.lastRecap or (summary.lastSession and summary.lastSession.summary) or nil)
    or ((summary.lastSession and summary.lastSession.coachSummary) or (DingTimerDB.coach and DingTimerDB.coach.lastRecap) or nil)
  if recap then
    insightsFrame.recapValue:SetText((recap.headline or "") .. "  " .. (recap.segmentLine or ""))
  else
    insightsFrame.recapValue:SetText(pvpView and "No PvP recap stored yet." or "No recap stored yet.")
  end

  updateComparison(summary)
  updateZoneLeaders(summary)
  drawSparkline(summary.chartValues or {})
end

function NS.InitInsightsPanel(parent)
  if insightsFrame then return insightsFrame end

  insightsFrame = CreateFrame("Frame", "DingTimerInsightsPanel", parent)
  insightsFrame:SetAllPoints(parent)

  local scrollFrame, scrollChild = NS.UI.CreateScrollFrame(insightsFrame, 680, 580)

  local function createSummaryBlock(anchorX, label)
    local labelFS = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelFS:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", anchorX, -16)
    labelFS:SetText(label)

    local valueFS = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueFS:SetPoint("TOPLEFT", labelFS, "BOTTOMLEFT", 0, -2)
    valueFS:SetText("--")
    return labelFS, valueFS
  end

  insightsFrame.labels = {}
  insightsFrame.labels.median, insightsFrame.valueMedianXPH = createSummaryBlock(16, "Median XP/hr")
  insightsFrame.labels.best, insightsFrame.valueBestXPH = createSummaryBlock(150, "Best XP/hr")
  insightsFrame.labels.avg, insightsFrame.valueAvgLevel = createSummaryBlock(284, "Avg Time in Level")
  insightsFrame.valueTrend = select(2, createSummaryBlock(438, "Trend"))

  local countLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  countLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 572, -16)
  countLabel:SetText("Stored Runs")

  insightsFrame.valueCount = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  insightsFrame.valueCount:SetPoint("TOPLEFT", countLabel, "BOTTOMLEFT", 0, -2)
  insightsFrame.valueCount:SetText("0")

  local bestSessionLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bestSessionLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -68)
  bestSessionLabel:SetText("Best Session")
  insightsFrame.labels.bestSession = bestSessionLabel

  insightsFrame.bestSessionValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  insightsFrame.bestSessionValue:SetPoint("TOPLEFT", bestSessionLabel, "BOTTOMLEFT", 0, -4)
  insightsFrame.bestSessionValue:SetWidth(320)
  insightsFrame.bestSessionValue:SetJustifyH("LEFT")
  insightsFrame.bestSessionValue:SetText("--")

  local compareLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  compareLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -108)
  compareLabel:SetText("Current vs Last Run")
  insightsFrame.labels.compare = compareLabel

  insightsFrame.compareLine1 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  insightsFrame.compareLine1:SetPoint("TOPLEFT", compareLabel, "BOTTOMLEFT", 0, -4)
  insightsFrame.compareLine1:SetWidth(680)
  insightsFrame.compareLine1:SetJustifyH("LEFT")
  insightsFrame.compareLine1:SetText("")

  insightsFrame.compareLine2 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  insightsFrame.compareLine2:SetPoint("TOPLEFT", insightsFrame.compareLine1, "BOTTOMLEFT", 0, -4)
  insightsFrame.compareLine2:SetWidth(680)
  insightsFrame.compareLine2:SetJustifyH("LEFT")
  insightsFrame.compareLine2:SetText("")

  local sparkLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sparkLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -162)
  sparkLabel:SetText("Recent XP/hr Trend")
  insightsFrame.labels.spark = sparkLabel

  local sparkArea = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
  sparkArea:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -182)
  sparkArea:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, -182)
  sparkArea:SetHeight(84)
  sparkArea:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  sparkArea:SetBackdropColor(0, 0, 0, 0.35)
  sparkArea:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
  insightsFrame.sparkArea = sparkArea

  for i = 1, MAX_SPARK_POINTS - 1 do
    local line = NS.CreateLineCompat(sparkArea, "OVERLAY")
    line:SetColorTexture(0.24, 0.78, 0.92, 0.95)
    line:SetThickness(2)
    line:Hide()
    sparkLines[i] = line
  end

  NS.UI.CreateSectionTitle(scrollChild, 16, -286, "Zone Leaders", "Where your best historical pace has been.")
  insightsFrame.zoneRows = NS.UI.CreateListRows(scrollChild, {
    startX = 16, startY = -314, width = 680, rowCount = 3, spacing = 16, fontObject = "GameFontHighlightSmall"
  })

  NS.UI.CreateSectionTitle(scrollChild, 16, -374, "Latest Recap", "The most recent coach summary stored with your runs.")
  insightsFrame.recapValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  insightsFrame.recapValue:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -402)
  insightsFrame.recapValue:SetWidth(680)
  insightsFrame.recapValue:SetJustifyH("LEFT")
  insightsFrame.recapValue:SetText("")

  local rowsHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rowsHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -438)
  rowsHeader:SetText("Recent Sessions (newest first)")
  insightsFrame.labels.rows = rowsHeader

  insightsFrame.xpToggle = CreateFrame("Button", nil, insightsFrame, "UIPanelButtonTemplate")
  insightsFrame.xpToggle:SetSize(72, 22)
  insightsFrame.xpToggle:SetPoint("BOTTOMLEFT", insightsFrame, "BOTTOMLEFT", 146, 10)
  insightsFrame.xpToggle:SetText("Leveling")
  insightsFrame.xpToggle:SetScript("OnClick", function()
    if NS.SetPvpHistoryView then
      NS.SetPvpHistoryView("xp")
    end
    refreshInsights()
  end)

  insightsFrame.pvpToggle = CreateFrame("Button", nil, insightsFrame, "UIPanelButtonTemplate")
  insightsFrame.pvpToggle:SetSize(56, 22)
  insightsFrame.pvpToggle:SetPoint("LEFT", insightsFrame.xpToggle, "RIGHT", 6, 0)
  insightsFrame.pvpToggle:SetText("PvP")
  insightsFrame.pvpToggle:SetScript("OnClick", function()
    if NS.SetPvpHistoryView then
      NS.SetPvpHistoryView("pvp")
    end
    refreshInsights()
  end)

  rowTexts = NS.UI.CreateListRows(scrollChild, {
    startX = 16, startY = -458, width = 680, rowCount = MAX_ROWS, spacing = 14, fontObject = "GameFontHighlightSmall"
  })

  NS.CreateConfirmButton(insightsFrame, 16, 10, 120, "Clear History", "Confirm Clear", function()
    if NS.ClearCurrentProfileHistory then
      NS.ClearCurrentProfileHistory()
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " history cleared for this character.")
    end
  end)

  insightsFrame:SetScript("OnShow", refreshInsights)
  insightsFrame:Hide()
  return insightsFrame
end

function NS.RefreshInsightsWindow()
  if insightsFrame and insightsFrame:IsShown() then
    refreshInsights()
  end
end
