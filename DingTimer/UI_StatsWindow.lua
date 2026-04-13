local _, NS = ...

local FRAME_WIDTH = 664
local CARD_WIDTH = 151
local CARD_HEIGHT = 56
local CARD_GAP = 10

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

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
  local progressPct = math_max(0, math_min((snapshot.progress or 0) * 100, 100))
  local width = math_max(1, math_floor((statsFrame.progressBar:GetWidth() or 1) * (snapshot.progress or 0)))
  statsFrame.progressFill:SetColorTexture(0.24, 0.78, 0.92, 0.9)
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

local function setPvpProgress(snapshot)
  if not statsFrame then return end
  local progressPct = math_max(0, math_min((snapshot.progress or 0) * 100, 100))
  local width = math_max(1, math_floor((statsFrame.progressBar:GetWidth() or 1) * (snapshot.progress or 0)))
  statsFrame.progressFill:SetColorTexture(0.92, 0.74, 0.24, 0.9)
  local goalValue = snapshot.targetHonor and NS.FormatNumber(snapshot.targetHonor) or "Off"
  statsFrame.zoneText:SetText(snapshot.zone or "Unknown")
  statsFrame.progressTitle:SetText(string.format(
    "Honor %s / %s  (%.1f%%)",
    NS.FormatNumber(snapshot.currentHonor or 0),
    goalValue,
    progressPct
  ))
  statsFrame.progressSub:SetText(string.format(
    "%s  |  %s rolling window  |  %s session time",
    snapshot.goalStatus or "PvP goal unavailable.",
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
      NS.fmtTime(math_max(1, now - (alerts[i].at or now))),
      alerts[i].text or ""
    )
  end
  return rows
end

local function buildPvpNoticeRows()
  local rows = {}
  local notices = NS.GetPvpRecentNotices and NS.GetPvpRecentNotices(4) or {}
  local now = GetTime()
  for i = 1, #notices do
    rows[i] = string.format(
      "%s ago  |  %s",
      NS.fmtTime(math_max(1, now - (notices[i].at or now))),
      notices[i].text or ""
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

local function buildPvpRecapLines()
  local summary = DingTimerDB and DingTimerDB.pvp and DingTimerDB.pvp.lastRecap or nil
  if not summary then
    return {
      "No PvP recap yet. Finish a battleground or type /ding pvp recap during a session.",
    }
  end
  return {
    summary.headline or "",
    summary.detail or "",
    summary.segmentLine or "",
  }
end

local function applyModeLabels()
  if not statsFrame then
    return
  end

  local isPvp = NS.IsPvpMode and NS.IsPvpMode()
  if isPvp then
    statsFrame.cards.currentXph.label:SetText("Honor / hr")
    statsFrame.cards.sessionAvg.label:SetText("Session Avg")
    statsFrame.cards.ttl.label:SetText("Time To Goal")
    statsFrame.cards.goal.label:SetText("Goal")
    statsFrame.cards.sessionXP.label:SetText("Session Honor")
    statsFrame.cards.sessionMoney.label:SetText("Session HKs")
    statsFrame.cards.moneyPerHour.label:SetText("HK / hr")
    statsFrame.cards.bestSegment.label:SetText("Match Honor")
    statsFrame.sectionTitles.alertTitle:SetText("Recent PvP Notices")
    statsFrame.sectionTitles.alertSub:SetText("Match recaps, milestones, and queued PvP notices.")
    statsFrame.sectionTitles.recapTitle:SetText("Latest PvP Recap")
    statsFrame.sectionTitles.recapSub:SetText("The latest PvP recap is kept here for quick review.")
    statsFrame.goalStatus:SetText("")
    if statsFrame.secondaryButton then
      statsFrame.secondaryButton:SetText("Recap")
    end
    return
  end

  statsFrame.cards.currentXph.label:SetText("Current Pace")
  statsFrame.cards.sessionAvg.label:SetText("Session Avg")
  statsFrame.cards.ttl.label:SetText("Time To Level")
  statsFrame.cards.goal.label:SetText("Goal Pace")
  statsFrame.cards.sessionXP.label:SetText("Session XP")
  statsFrame.cards.sessionMoney.label:SetText("Session Money")
  statsFrame.cards.moneyPerHour.label:SetText("Money / hr")
  statsFrame.cards.bestSegment.label:SetText("Best Segment")
  statsFrame.sectionTitles.alertTitle:SetText("Recent Alerts")
  statsFrame.sectionTitles.alertSub:SetText("Coach warnings and milestones from this run.")
  statsFrame.sectionTitles.recapTitle:SetText("Latest Recap")
  statsFrame.sectionTitles.recapSub:SetText("The most recent recap is kept here for quick review.")
  if statsFrame.secondaryButton then
    statsFrame.secondaryButton:SetText("Split")
  end
end

local function setStatusPills(isPvp, snapshot, coach)
  if not statsFrame or not NS.UI or not NS.UI.SetPill then
    return
  end

  if isPvp then
    NS.UI.SetPill(statsFrame.modePill, "PvP Mode", "warn")
    if snapshot and snapshot.targetHonor and snapshot.targetHonor > 0 then
      NS.UI.SetPill(
        statsFrame.goalPill,
        "Goal " .. NS.FormatNumber(snapshot.targetHonor),
        "good"
      )
    else
      NS.UI.SetPill(statsFrame.goalPill, "Honor Run", "neutral")
    end
    return
  end

  NS.UI.SetPill(statsFrame.modePill, "Leveling", "good")
  if coach and coach.goal and coach.goal.targetXph and coach.goal.targetXph > 0 then
    local delta = (snapshot.currentXph or 0) - (coach.goal.targetXph or 0)
    if delta >= 0 then
      NS.UI.SetPill(statsFrame.goalPill, "On Pace +" .. NS.FormatNumber(NS.Round(delta)), "good")
    else
      NS.UI.SetPill(statsFrame.goalPill, "Behind " .. NS.FormatNumber(NS.Round(math_abs(delta))), "bad")
    end
  elseif snapshot.currentXph and snapshot.currentXph > 0 then
    NS.UI.SetPill(statsFrame.goalPill, "Rolling Window", "info")
  else
    NS.UI.SetPill(statsFrame.goalPill, "Need XP", "neutral")
  end
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
  local isPvp = NS.IsPvpMode and NS.IsPvpMode()
  applyModeLabels()
  updateButtons()

  if isPvp then
    local snapshot = NS.GetPvpSnapshot and NS.GetPvpSnapshot(now) or nil
    local recentMatches = NS.GetRecentPvpMatches and NS.GetRecentPvpMatches(1) or {}
    if not snapshot then
      return
    end

    setPvpProgress(snapshot)
    setStatusPills(true, snapshot, nil)

    local goalValue = snapshot.targetHonor and NS.FormatNumber(snapshot.targetHonor) or "Off"
    local matchValue = "--"
    local matchSub = "No active battleground match"
    if snapshot.hasActiveMatch and NS.state and NS.state.pvp and NS.state.pvp.activeMatch then
      local match = NS.state.pvp.activeMatch
      matchValue = NS.FormatNumber(match.honorGained or 0)
      matchSub = string.format("%s  |  %s HKs", match.zone or "Unknown", NS.FormatNumber(match.hkGained or 0))
    elseif recentMatches and recentMatches[1] then
      matchValue = NS.FormatNumber(recentMatches[1].honorGained or 0)
      matchSub = string.format("Last: %s", recentMatches[1].zone or "Unknown")
    end

    NS.UI.SetMetricCard(statsFrame.cards.currentXph, NS.FormatNumber(NS.Round(snapshot.currentHonorPerHour or 0)), "Rolling pace")
    NS.UI.SetMetricCard(statsFrame.cards.sessionAvg, NS.FormatNumber(NS.Round(snapshot.sessionHonorPerHour or 0)), "Whole-session pace")
    NS.UI.SetMetricCard(statsFrame.cards.ttl, snapshot.ttgText or "--", snapshot.goalHeadline or "Goal")
    NS.UI.SetMetricCard(statsFrame.cards.goal, goalValue, snapshot.goalLabel or "Goal")
    NS.UI.SetMetricCard(statsFrame.cards.sessionXP, NS.FormatNumber(snapshot.sessionHonor or 0), "Earned this PvP session")
    NS.UI.SetMetricCard(statsFrame.cards.sessionMoney, NS.FormatNumber(snapshot.sessionHKs or 0), "Session honorable kills")
    NS.UI.SetMetricCard(statsFrame.cards.moneyPerHour, NS.FormatNumber(NS.Round(snapshot.currentHKPerHour or 0)), "Rolling HK pace")
    NS.UI.SetMetricCard(statsFrame.cards.bestSegment, matchValue, matchSub)

    statsFrame.goalStatus:SetText(snapshot.goalStatus or "PvP goal unavailable.")
    statsFrame.segmentStatus:SetText(snapshot.matchStatus or "No active battleground match.")

    NS.UI.SetRows(
      statsFrame.alertRows,
      buildPvpNoticeRows(),
      NS.C.mid .. "No PvP notices yet. Enable match recap or milestone announcements to populate this area." .. NS.C.r
    )
    NS.UI.SetRows(
      statsFrame.recapRows,
      buildPvpRecapLines(),
      NS.C.mid .. "No PvP recap yet." .. NS.C.r
    )
    return
  end

  local snapshot = NS.GetSessionSnapshot(now)
  local coach = NS.GetCoachStatus and NS.GetCoachStatus(now) or nil
  local goalValue, goalSub = formatGoalCard(coach and coach.goal)
  local bestSegment = coach and coach.bestSegment or nil
  local currentSegment = coach and coach.currentSegment or nil

  setProgress(snapshot)
  setStatusPills(false, snapshot, coach)

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

  local _, scrollChild = NS.UI.CreateScrollFrame(statsFrame, 664, 550)

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

  if NS.UI and NS.UI.CreatePill then
    statsFrame.modePill = NS.UI.CreatePill(progressFrame, FRAME_WIDTH - 196, -10, 84, "Leveling")
    statsFrame.goalPill = NS.UI.CreatePill(progressFrame, FRAME_WIDTH - 104, -10, 92, "Rolling")
  end

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

  local coachSection = NS.UI.CreateSectionBlock and NS.UI.CreateSectionBlock(
    scrollChild,
    16,
    -254,
    664,
    70,
    "Session Coach",
    "Goal tracking, current segment status, and recent guidance."
  ) or scrollChild
  statsFrame.goalStatus = coachSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statsFrame.goalStatus:SetPoint("TOPLEFT", coachSection, "TOPLEFT", 12, -42)
  statsFrame.goalStatus:SetWidth(636)
  statsFrame.goalStatus:SetJustifyH("LEFT")
  statsFrame.goalStatus:SetText("")

  statsFrame.segmentStatus = coachSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statsFrame.segmentStatus:SetPoint("TOPLEFT", statsFrame.goalStatus, "BOTTOMLEFT", 0, -6)
  statsFrame.segmentStatus:SetWidth(636)
  statsFrame.segmentStatus:SetJustifyH("LEFT")
  statsFrame.segmentStatus:SetText("")

  local alertsSection, alertTitle, alertSub
  if NS.UI.CreateSectionBlock then
    alertsSection, alertTitle, alertSub = NS.UI.CreateSectionBlock(
      scrollChild,
      16,
      -332,
      664,
      96,
      "Recent Alerts",
      "Coach warnings and milestones from this run."
    )
  else
    alertsSection = scrollChild
    alertTitle, alertSub = NS.UI.CreateSectionTitle(scrollChild, 16, -332, "Recent Alerts", "Coach warnings and milestones from this run.")
  end
  statsFrame.alertRows = NS.UI.CreateListRows(alertsSection, {
    startX = 12, startY = -42, width = 636, rowCount = 4, spacing = 16, fontObject = "GameFontHighlightSmall"
  })

  local recapSection, recapTitle, recapSub
  if NS.UI.CreateSectionBlock then
    recapSection, recapTitle, recapSub = NS.UI.CreateSectionBlock(
      scrollChild,
      16,
      -438,
      664,
      88,
      "Latest Recap",
      "The most recent recap is kept here for quick review."
    )
  else
    recapSection = scrollChild
    recapTitle, recapSub = NS.UI.CreateSectionTitle(scrollChild, 16, -438, "Latest Recap", "The most recent recap is kept here for quick review.")
  end
  statsFrame.recapRows = NS.UI.CreateListRows(recapSection, {
    startX = 12, startY = -42, width = 636, rowCount = 3, spacing = 16, fontObject = "GameFontDisableSmall"
  })
  statsFrame.sectionTitles = {
    alertTitle = alertTitle,
    alertSub = alertSub,
    recapTitle = recapTitle,
    recapSub = recapSub,
  }

  statsFrame.hudButton = NS.UI.CreateActionButton(statsFrame, 16, 12, 76, "Show HUD", function()
    DingTimerDB.float = not DingTimerDB.float
    NS.setFloatVisible(DingTimerDB.float)
    updateButtons()
  end)
  statsFrame.secondaryButton = NS.UI.CreateActionButton(statsFrame, 100, 12, 72, "Split", function()
    if NS.IsPvpMode and NS.IsPvpMode() then
      if NS.ShowPvpRecap then
        NS.ShowPvpRecap()
      end
      return
    end
    if NS.SplitSession then
      NS.SplitSession("MANUAL_SPLIT")
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " manual split recorded.")
    end
    updateValues()
  end)
  statsFrame.graphButton = NS.UI.CreateActionButton(statsFrame, 180, 12, 72, "Graph", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(2)
    end
  end)
  statsFrame.historyButton = NS.UI.CreateActionButton(statsFrame, 260, 12, 76, "History", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(3)
    end
  end)
  statsFrame.settingsButton = NS.UI.CreateActionButton(statsFrame, 344, 12, 76, "Settings", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(4)
    end
  end)
  local resetButton = NS.CreateConfirmButton(statsFrame, 428, 12, 96, "Reset", "Confirm Reset", function()
    if NS.ResetSession then
      NS.ResetSession("MANUAL_RESET")
    end
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)
  if NS.UI and NS.UI.DecorateButton then
    NS.UI.DecorateButton(resetButton)
  end

  local footer = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMRIGHT", -16, 18)
  footer:SetText("Live tab")

  statsFrame:Hide()
  NS.ManageFrameTicker(statsFrame, 1, updateValues, "uiWindowVisible")
  return statsFrame
end

function NS.RefreshStatsWindow()
  if statsFrame and statsFrame:IsShown() then
    updateValues()
  end
end
