local ADDON, NS = ...

local FRAME_WIDTH = 640
local FRAME_HEIGHT = 440
local CARD_GAP = 12
local CARD_WIDTH = 188
local CARD_HEIGHT = 52

local statsFrame = nil

--- Creates a reusable metric card widget for the stats panel.
--- @param parent frame The parent frame to attach the card to.
--- @param x number The X offset relative to the parent's TOPLEFT.
--- @param y number The Y offset relative to the parent's TOPLEFT.
--- @param labelText string The text for the card's header label.
--- @return table A table containing refs to the background frame and its text elements.
local function createMetricCard(parent, x, y, labelText)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  card:SetSize(CARD_WIDTH, CARD_HEIGHT)
  card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  NS.ApplyThemeToFrame(card, true)

  local accent = card:CreateTexture(nil, "ARTWORK")
  accent:SetHeight(2)
  accent:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
  accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
  accent:SetColorTexture(0.24, 0.78, 0.92, 0.75)

  local label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -12)
  label:SetText(labelText)

  local value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  value:SetText("--")

  local sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
  sub:SetText("")

  return {
    frame = card,
    value = value,
    sub = sub,
  }
end

--- Creates a standard action button for the stats panel.
--- @param parent frame The parent frame to attach the button to.
--- @param x number The X offset relative to the parent's BOTTOMLEFT.
--- @param y number The Y offset relative to the parent's BOTTOMLEFT.
--- @param label string The text to display on the button.
--- @param callback function The function to call when the button is clicked.
--- @return button The created button widget.
local function createActionButton(parent, x, y, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(90, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  btn:SetText(label)
  btn:SetScript("OnClick", callback)
  return btn
end

--- Replaces the displayed text on a metric card.
--- @param card table The metric card object created by createMetricCard.
--- @param value string|nil The primary value text to display, defaults to "--".
--- @param subValue string|nil The secondary subtitle text to display, defaults to "".
local function setCard(card, value, subValue)
  card.value:SetText(value or "--")
  card.sub:SetText(subValue or "")
end

--- Computes and formats the percentage difference between current pace and session average.
--- Returns colored text indicating if the player is speeding up or slowing down.
--- @param currentXph number The player's current XP per hour pace.
--- @param sessionXph number The player's overall session XP per hour pace.
--- @return string, string The formatted value text and a subtitle text explaining it.
local function formatPaceDelta(currentXph, sessionXph)
  if not currentXph or currentXph <= 0 or not sessionXph or sessionXph <= 0 then
    return NS.C.mid .. "Waiting" .. NS.C.r, "Need live and session pace"
  end

  local deltaPct = ((currentXph / sessionXph) - 1) * 100
  local color = NS.C.mid
  if deltaPct > 1 then
    color = NS.C.xp
  elseif deltaPct < -1 then
    color = NS.C.bad
  end

  local sign = (deltaPct >= 0) and "+" or ""
  return color .. sign .. NS.fmtPercent(deltaPct, 1) .. NS.C.r, "Current vs session avg"
end

--- Called periodically to compute stats and update all displays in the stats panel.
--- Syncs UI widgets with the current tracking state via NS.GetSessionSnapshot.
local function updateValues()
  if not statsFrame or not statsFrame:IsShown() then
    return
  end

  local snapshot = NS.GetSessionSnapshot(GetTime())
  local progressPct = math.max(0, math.min(snapshot.progress * 100, 100))
  local progressWidth = math.max(1, math.floor((statsFrame.progressBar:GetWidth() or 1) * snapshot.progress))
  local paceValue, paceSub = formatPaceDelta(snapshot.currentXph, snapshot.sessionXph)

  statsFrame.zoneText:SetText(snapshot.zone or "Unknown")
  statsFrame.progressTitle:SetText(string.format("Level %s  |  %s / %s XP  (%.1f%%)",
    tostring(snapshot.level or "?"),
    NS.FormatNumber(snapshot.xp or 0),
    NS.FormatNumber(snapshot.maxXP or 0),
    progressPct
  ))
  statsFrame.progressSub:SetText(string.format("%s XP remaining  |  %s rolling window",
    NS.FormatNumber(snapshot.remainingXP or 0),
    NS.fmtTime(snapshot.rollingWindow or 0)
  ))
  statsFrame.progressFill:SetWidth(progressWidth)

  setCard(statsFrame.cards.sessionTime, NS.fmtTime(snapshot.sessionElapsed), "In this run")
  setCard(statsFrame.cards.sessionXP, NS.FormatNumber(snapshot.sessionXP), "Earned this session")
  setCard(statsFrame.cards.currentXph, NS.FormatNumber(NS.Round(snapshot.currentXph)), "Rolling pace")
  setCard(statsFrame.cards.sessionAvg, NS.FormatNumber(NS.Round(snapshot.sessionXph)), "Whole-session pace")
  setCard(statsFrame.cards.ttl, NS.fmtTime(snapshot.ttl), "Estimated time to ding")
  setCard(statsFrame.cards.paceDelta, paceValue, paceSub)
  setCard(statsFrame.cards.sessionMoney, NS.fmtMoney(snapshot.sessionMoney), "Net this session")
  setCard(statsFrame.cards.moneyPerHour, NS.fmtMoney(NS.Round(snapshot.moneyPerHour)) .. " / hr", "Income pace")
end

--- Initializes the primary stats dashboard, creating all visual elements.
--- Will return the existing frame if already created.
--- @param parent frame The parent tab container or window for this panel.
--- @return frame The initialized stats panel frame.
function NS.InitStatsPanel(parent)
  if statsFrame then
    return statsFrame
  end

  statsFrame = CreateFrame("Frame", "DingTimerStatsPanel", parent)
  statsFrame:SetAllPoints(parent)

  -- Removed standalone window controls (closeBtn, header, drag handlers)

  local zoneText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zoneText:SetPoint("TOPLEFT", 16, -16)
  zoneText:SetText("Unknown")
  statsFrame.zoneText = zoneText

  local separator = statsFrame:CreateTexture(nil, "ARTWORK")
  separator:SetColorTexture(0.2, 0.6, 0.8, 0.45)
  separator:SetSize(FRAME_WIDTH - 32, 1)
  separator:SetPoint("TOP", 0, -35)

  local progressFrame = CreateFrame("Frame", nil, statsFrame, "BackdropTemplate")
  progressFrame:SetSize(FRAME_WIDTH - 32, 54)
  progressFrame:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16, -46)
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
  progressBar:SetSize(progressFrame:GetWidth() - 20, 10)
  progressBar:SetPoint("BOTTOMLEFT", progressFrame, "BOTTOMLEFT", 10, 10)
  progressBar:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  progressBar:SetBackdropColor(0, 0, 0, 0.5)
  progressBar:SetBackdropBorderColor(0.2, 0.24, 0.28, 0.8)
  statsFrame.progressBar = progressBar

  local progressFill = progressBar:CreateTexture(nil, "ARTWORK")
  progressFill:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 2, -2)
  progressFill:SetPoint("BOTTOMLEFT", progressBar, "BOTTOMLEFT", 2, 2)
  progressFill:SetWidth(1)
  progressFill:SetColorTexture(0.24, 0.78, 0.92, 0.9)
  statsFrame.progressFill = progressFill

  -- Realign 3 cards per row
  local startX = 16
  statsFrame.cards = {
    sessionTime  = createMetricCard(statsFrame, startX, -112, "Session Time"),
    sessionXP    = createMetricCard(statsFrame, startX + CARD_WIDTH + CARD_GAP, -112, "Session XP"),
    currentXph   = createMetricCard(statsFrame, startX + (CARD_WIDTH + CARD_GAP)*2, -112, "Current XP / hr"),
    
    sessionAvg   = createMetricCard(statsFrame, startX, -112 - CARD_HEIGHT - CARD_GAP, "Session Avg / hr"),
    ttl          = createMetricCard(statsFrame, startX + CARD_WIDTH + CARD_GAP, -112 - CARD_HEIGHT - CARD_GAP, "Time To Level"),
    paceDelta    = createMetricCard(statsFrame, startX + (CARD_WIDTH + CARD_GAP)*2, -112 - CARD_HEIGHT - CARD_GAP, "Pace Delta"),
    
    sessionMoney = createMetricCard(statsFrame, startX, -112 - ((CARD_HEIGHT + CARD_GAP) * 2), "Session Money"),
    moneyPerHour = createMetricCard(statsFrame, startX + CARD_WIDTH + CARD_GAP, -112 - ((CARD_HEIGHT + CARD_GAP) * 2), "Money / hr"),
  }

  -- Removed individual window buttons (Graph, Insights, Settings) since they are tabs now

  local resetState = 0
  local resetTimer = nil
  local resetBtn
  resetBtn = createActionButton(statsFrame, 16, 14, "Reset", function()
    if resetState == 0 then
      resetState = 1
      resetBtn:SetText("Confirm")
      if resetTimer then
        resetTimer:Cancel()
      end
      resetTimer = C_Timer.NewTimer(3, function()
        resetState = 0
        resetBtn:SetText("Reset")
      end)
      return
    end

    resetState = 0
    if resetTimer then
      resetTimer:Cancel()
    end
    resetBtn:SetText("Reset")

    if NS.RecordSession then
      NS.RecordSession("MANUAL_RESET")
    end
    NS.resetXPState()
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)

  local footer = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", 112, 18)
  footer:SetText("Live dashboard. Use the tabs above to navigate.")

  statsFrame:Hide()
  NS.ManageFrameTicker(statsFrame, 1, updateValues, "uiWindowVisible")
  return statsFrame
end

-- Removed ToggleStatsWindow since ToggleMainWindow replaces it

--- Triggers an immediate refresh of the stats window if it is currently visible.
function NS.RefreshStatsWindow()
  if statsFrame and statsFrame:IsShown() then
    updateValues()
  end
end
