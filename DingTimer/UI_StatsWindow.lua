local ADDON, NS = ...

local FRAME_WIDTH = 664
local CARD_WIDTH = 151
local CARD_HEIGHT = 56
local CARD_GAP = 10

local statsFrame = nil

local function formatGoalCard(goal)
  if not goal then
    return "--", "Coach unavailable"
  end
  if goal.goal == "off" then
    return "Off", "Alerts only"
  end
  if goal.targetXph and goal.targetXph > 0 then
    return NS.FormatNumber(NS.Round(goal.targetXph)), goal.goalLabel
  end
  return goal.goalLabel or "Ding", goal.status or ""
end

local function setProgress(snapshot)
  if not statsFrame then return end
  local progressPct = math.max(0, math.min((snapshot.progress or 0) * 100, 100))
  local width = math.max(1, math.floor((statsFrame.progressBar:GetWidth() or 1) * (snapshot.progress or 0)))
  statsFrame.zoneText:SetText(snapshot.zone or "Unknown")
  statsFrame.progressTitle:SetText(string.format(
    "Level %s  |  %s / %s XP  (%.1f%%)",
    tostring(snapshot.level or "?"),
    NS.FormatNumber(snapshot.xp or 0),
    NS.FormatNumber(snapshot.maxXP or 0),
    progressPct
  ))
  statsFrame.progressSub:SetText(string.format(
    "%s XP remaining  |  %s rolling window  |  %s session time",
    NS.FormatNumber(snapshot.remainingXP or 0),
    NS.fmtTime(snapshot.rollingWindow or 0),
    NS.fmtTime(snapshot.sessionElapsed or 0)
  ))
  statsFrame.progressFill:SetWidth(width)
end

local function buildAlertRows(coach)
  local rows = {}
  local alerts = coach and coach.alerts or {}
  local now = GetTime()
  for i = 1, #alerts do
    rows[i] = string.format(
      "%s ago  |  %s",
      NS.fmtTime(math.max(1, now - (alerts[i].at or now))),
      alerts[i].text or ""
    )
  end
  return rows
end

local function buildRecapLines(coach)
  local summary = coach and coach.lastRecap or nil
  if not summary then
    return {
      "No coach recap yet. Finish a run or type /ding recap during a session.",
    }
  end
  return {
    summary.headline or "",
    summary.detail or "",
    summary.segmentLine or "",
  }
end

local function updateButtons()
  if not statsFrame then return end
  statsFrame.hudButton:SetText(DingTimerDB.float and "Hide HUD" or "Show HUD")
end

local function updateValues()
  if not statsFrame or not statsFrame:IsShown() then
    return
  end

  local now = GetTime()
  local snapshot = NS.GetSessionSnapshot(now)
  local coach = NS.GetCoachStatus and NS.GetCoachStatus(now) or nil
  local goalValue, goalSub = formatGoalCard(coach and coach.goal)
  local bestSegment = coach and coach.bestSegment or nil
  local currentSegment = coach and coach.currentSegment or nil

  setProgress(snapshot)
  updateButtons()

  local currentPaceSub = "Rolling pace"
  if snapshot.showSettledOverlay then
    currentPaceSub = string.format(
      "Raw %s  |  %s %s",
      NS.FormatNumber(NS.Round(snapshot.rawCurrentXph or 0)),
      snapshot.settleLabel or "Settled",
      NS.FormatNumber(NS.Round(snapshot.currentXph or 0))
    )
  end

  NS.UI.SetMetricCard(statsFrame.cards.currentXph, NS.FormatNumber(NS.Round(snapshot.currentXph)), currentPaceSub)
  NS.UI.SetMetricCard(statsFrame.cards.sessionAvg, NS.FormatNumber(NS.Round(snapshot.sessionXph)), "Whole-session pace")
  NS.UI.SetMetricCard(statsFrame.cards.ttl, NS.fmtTime(snapshot.ttl), "Time to next ding")
  NS.UI.SetMetricCard(statsFrame.cards.goal, goalValue, goalSub)
  NS.UI.SetMetricCard(statsFrame.cards.sessionXP, NS.FormatNumber(snapshot.sessionXP), "Earned this run")
  NS.UI.SetMetricCard(statsFrame.cards.sessionMoney, NS.fmtMoney(snapshot.sessionMoney), "Net session gold")
  NS.UI.SetMetricCard(statsFrame.cards.moneyPerHour, NS.fmtMoney(NS.Round(snapshot.moneyPerHour)) .. " / hr", "Gross income / hr")
  NS.UI.SetMetricCard(
    statsFrame.cards.bestSegment,
    bestSegment and NS.FormatNumber(NS.Round(bestSegment.avgXph or 0)) or "--",
    bestSegment and ("Best segment: " .. tostring(bestSegment.zone or "Unknown")) or "No completed segment yet"
  )

  statsFrame.goalStatus:SetText((coach and coach.goal and coach.goal.status) or "Coach goal unavailable.")
  statsFrame.segmentStatus:SetText(
    currentSegment and string.format(
      "Current segment: %s  |  %s XP/hr over %s",
      tostring(currentSegment.zone or "Unknown"),
      NS.FormatNumber(NS.Round(currentSegment.avgXph or 0)),
      NS.fmtTime(currentSegment.durationSec or 0)
    ) or "Current segment starts tracking with your next checkpoint."
  )

  NS.UI.SetRows(
    statsFrame.alertRows,
    buildAlertRows(coach),
    NS.C.mid .. "No recent coach alerts. Keep moving to build guidance." .. NS.C.r
  )
  NS.UI.SetRows(
    statsFrame.recapRows,
    buildRecapLines(coach),
    NS.C.mid .. "No recap yet." .. NS.C.r
  )
end

function NS.InitStatsPanel(parent)
  if statsFrame then
    return statsFrame
  end

  statsFrame = CreateFrame("Frame", "DingTimerStatsPanel", parent)
  statsFrame:SetAllPoints(parent)

  local scrollFrame, scrollChild = NS.UI.CreateScrollFrame(statsFrame, 664, 550)

  local zoneText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zoneText:SetPoint("TOPLEFT", 16, -16)
  zoneText:SetText("Unknown")
  statsFrame.zoneText = zoneText

  local progressFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
  progressFrame:SetSize(FRAME_WIDTH, 60)
  progressFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -36)
  NS.ApplyThemeToFrame(progressFrame, true)

  local progressTitle = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  progressTitle:SetPoint("TOPLEFT", 10, -12)
  progressTitle:SetText("--")
  statsFrame.progressTitle = progressTitle

  local progressSub = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  progressSub:SetPoint("TOPLEFT", progressTitle, "BOTTOMLEFT", 0, -4)
  progressSub:SetText("")
  statsFrame.progressSub = progressSub

  local progressBar = CreateFrame("Frame", nil, progressFrame, "BackdropTemplate")
  progressBar:SetSize(FRAME_WIDTH - 20, 10)
  progressBar:SetPoint("BOTTOMLEFT", progressFrame, "BOTTOMLEFT", 10, 10)
  progressBar:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  progressBar:SetBackdropColor(0, 0, 0, 0.45)
  progressBar:SetBackdropBorderColor(0.2, 0.24, 0.28, 0.8)
  statsFrame.progressBar = progressBar

  local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
  progressFill:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 2, -2)
  progressFill:SetPoint("BOTTOMLEFT", progressBar, "BOTTOMLEFT", 2, 2)
  progressFill:SetWidth(1)
  progressFill:SetColorTexture(0.24, 0.78, 0.92, 0.9)
  statsFrame.progressFill = progressFill

  statsFrame.cards = {
    currentXph = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16, -112, "Current Pace"),
    sessionAvg = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + CARD_WIDTH + CARD_GAP, -112, "Session Avg"),
    ttl = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + ((CARD_WIDTH + CARD_GAP) * 2), -112, "Time To Level"),
    goal = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + ((CARD_WIDTH + CARD_GAP) * 3), -112, "Goal Pace"),
    sessionXP = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16, -178, "Session XP"),
    sessionMoney = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + CARD_WIDTH + CARD_GAP, -178, "Session Money"),
    moneyPerHour = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + ((CARD_WIDTH + CARD_GAP) * 2), -178, "Money / hr"),
    bestSegment = NS.UI.CreateMetricCard(scrollChild, CARD_WIDTH, CARD_HEIGHT, 16 + ((CARD_WIDTH + CARD_GAP) * 3), -178, "Best Segment"),
  }

  NS.UI.CreateSectionTitle(scrollChild, 16, -254, "Session Coach", "Goal tracking, current segment status, and recent guidance.")
  statsFrame.goalStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statsFrame.goalStatus:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -282)
  statsFrame.goalStatus:SetWidth(680)
  statsFrame.goalStatus:SetJustifyH("LEFT")
  statsFrame.goalStatus:SetText("")

  statsFrame.segmentStatus = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statsFrame.segmentStatus:SetPoint("TOPLEFT", statsFrame.goalStatus, "BOTTOMLEFT", 0, -6)
  statsFrame.segmentStatus:SetWidth(680)
  statsFrame.segmentStatus:SetJustifyH("LEFT")
  statsFrame.segmentStatus:SetText("")

  NS.UI.CreateSectionTitle(scrollChild, 16, -332, "Recent Alerts", "Coach warnings and milestones from this run.")
  statsFrame.alertRows = NS.UI.CreateListRows(scrollChild, 16, -360, 680, 4, 16, "GameFontHighlightSmall")

  NS.UI.CreateSectionTitle(scrollChild, 16, -438, "Latest Recap", "The most recent recap is kept here for quick review.")
  statsFrame.recapRows = NS.UI.CreateListRows(scrollChild, 16, -466, 680, 3, 16, "GameFontDisableSmall")

  statsFrame.hudButton = NS.UI.CreateActionButton(statsFrame, 16, 12, 88, "Show HUD", function()
    DingTimerDB.float = not DingTimerDB.float
    NS.setFloatVisible(DingTimerDB.float)
    updateButtons()
  end)
  NS.UI.CreateActionButton(statsFrame, 112, 12, 88, "Split", function()
    if NS.SplitSession then
      NS.SplitSession("MANUAL_SPLIT")
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " manual split recorded.")
    end
    updateValues()
  end)
  NS.UI.CreateActionButton(statsFrame, 208, 12, 88, "Analysis", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(2)
    end
  end)
  NS.UI.CreateActionButton(statsFrame, 304, 12, 88, "History", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(3)
    end
  end)
  NS.CreateConfirmButton(statsFrame, 400, 12, 100, "Reset", "Confirm Reset", function()
    if NS.ResetSession then
      NS.ResetSession("MANUAL_RESET")
    end
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)

  local footer = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMRIGHT", -16, 18)
  footer:SetText("Live panel")

  statsFrame:Hide()
  NS.ManageFrameTicker(statsFrame, 1, updateValues, "uiWindowVisible")
  return statsFrame
end

function NS.RefreshStatsWindow()
  if statsFrame and statsFrame:IsShown() then
    updateValues()
  end
end
