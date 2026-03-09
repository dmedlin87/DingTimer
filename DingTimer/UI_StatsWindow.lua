local ADDON, NS = ...

local FRAME_WIDTH = 420
local FRAME_HEIGHT = 360
local CARD_GAP = 10
local CARD_WIDTH = 188
local CARD_HEIGHT = 48

local statsFrame = nil

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

local function createActionButton(parent, x, y, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(90, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  btn:SetText(label)
  btn:SetScript("OnClick", callback)
  return btn
end

local function setCard(card, value, subValue)
  card.value:SetText(value or "--")
  card.sub:SetText(subValue or "")
end

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

function NS.InitStatsWindow()
  if statsFrame then
    return
  end

  statsFrame = CreateFrame("Frame", "DingTimerStatsWindow", UIParent, "BackdropTemplate")
  statsFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  statsFrame:SetPoint("CENTER")
  NS.ApplyThemeToFrame(statsFrame)

  statsFrame:SetMovable(true)
  statsFrame:EnableMouse(true)
  statsFrame:RegisterForDrag("LeftButton")
  statsFrame:SetClampedToScreen(true)
  statsFrame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
      return
    end
    self:StartMoving()
  end)
  statsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.uiWindowPosition = {
      point = point,
      relativePoint = relativePoint,
      xOfs = xOfs,
      yOfs = yOfs,
    }
  end)

  if DingTimerDB.uiWindowPosition then
    local pos = DingTimerDB.uiWindowPosition
    statsFrame:ClearAllPoints()
    statsFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  end

  local closeBtn = CreateFrame("Button", nil, statsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
  end)
  closeBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local header = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOPLEFT", 14, -12)
  header:SetText(NS.C.base .. "DingTimer Dashboard" .. NS.C.r)

  local zoneText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  zoneText:SetPoint("TOPRIGHT", -32, -16)
  zoneText:SetText("Unknown")
  statsFrame.zoneText = zoneText

  local separator = statsFrame:CreateTexture(nil, "ARTWORK")
  separator:SetColorTexture(0.2, 0.6, 0.8, 0.45)
  separator:SetSize(FRAME_WIDTH - 24, 1)
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

  statsFrame.cards = {
    sessionTime = createMetricCard(statsFrame, 16, -112, "Session Time"),
    sessionXP = createMetricCard(statsFrame, 16 + CARD_WIDTH + CARD_GAP, -112, "Session XP"),
    currentXph = createMetricCard(statsFrame, 16, -112 - CARD_HEIGHT - CARD_GAP, "Current XP / hr"),
    sessionAvg = createMetricCard(statsFrame, 16 + CARD_WIDTH + CARD_GAP, -112 - CARD_HEIGHT - CARD_GAP, "Session Avg / hr"),
    ttl = createMetricCard(statsFrame, 16, -112 - ((CARD_HEIGHT + CARD_GAP) * 2), "Time To Level"),
    paceDelta = createMetricCard(statsFrame, 16 + CARD_WIDTH + CARD_GAP, -112 - ((CARD_HEIGHT + CARD_GAP) * 2), "Pace Delta"),
    sessionMoney = createMetricCard(statsFrame, 16, -112 - ((CARD_HEIGHT + CARD_GAP) * 3), "Session Money"),
    moneyPerHour = createMetricCard(statsFrame, 16 + CARD_WIDTH + CARD_GAP, -112 - ((CARD_HEIGHT + CARD_GAP) * 3), "Money / hr"),
  }

  createActionButton(statsFrame, 16, 14, "Graph", function()
    if NS.ToggleGraphWindow then
      NS.ToggleGraphWindow()
    end
  end)

  createActionButton(statsFrame, 112, 14, "Insights", function()
    if NS.ToggleInsightsWindow then
      NS.ToggleInsightsWindow()
    end
  end)

  createActionButton(statsFrame, 208, 14, "Settings", function()
    if NS.ToggleSettingsWindow then
      NS.ToggleSettingsWindow()
    end
  end)

  local resetState = 0
  local resetTimer = nil
  local resetBtn
  resetBtn = createActionButton(statsFrame, 304, 14, "Reset", function()
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
  footer:SetPoint("BOTTOM", 0, 46)
  footer:SetText("Live dashboard. Use the graph for pace spikes and the settings panel for controls.")

  statsFrame:Hide()
  tinsert(UISpecialFrames, statsFrame:GetName())
  NS.ManageFrameTicker(statsFrame, 1, updateValues, "uiWindowVisible")
end

function NS.ToggleStatsWindow()
  if not statsFrame then
    NS.InitStatsWindow()
  end

  if statsFrame:IsShown() then
    statsFrame:Hide()
  else
    statsFrame:Show()
  end
end

function NS.RefreshStatsWindow()
  if statsFrame and statsFrame:IsShown() then
    updateValues()
  end
end
