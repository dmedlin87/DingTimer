local _, NS = ...

local settingsFrame = nil

local GOAL_ORDER = { "off", "ding", "30m", "60m" }
local MODE_ORDER = { "full", "ttl" }

local function refreshSettingsOwner(parent)
  if settingsFrame and settingsFrame.Refresh then
    settingsFrame:Refresh()
    return
  end
  if parent and parent.Refresh then
    parent:Refresh()
  end
end

local function ensureCoachConfig()
  if NS.EnsureCoachConfig then
    return NS.EnsureCoachConfig()
  end
  -- Fallback: SessionCoach not loaded yet; return raw DB table so the
  -- settings panel can still open without throwing.
  return DingTimerDB.coach or {}
end

local function createCheckbox(parent, x, y, label, callback, tooltipText)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb:SetScript("OnClick", function(self)
    if callback then
      callback(self:GetChecked())
    end
    refreshSettingsOwner(parent)
  end)
  if tooltipText then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
  text:SetWidth(220)
  text:SetJustifyH("LEFT")
  text:SetText(label)
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(text, "body")
  end
  cb.text = text
  if cb.SetHitRectInsets then
    cb:SetHitRectInsets(0, -160, 0, 0)
  end
  return cb
end

local function createButton(parent, x, y, width, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 26)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  btn:SetText(label)
  if NS.UI and NS.UI.DecorateButton then
    NS.UI.DecorateButton(btn)
  end
  btn:SetScript("OnClick", function(...)
    if callback then
      callback(...)
    end
    refreshSettingsOwner(parent)
  end)
  return btn
end

local function createEditBox(parent, x, y, width, callback, tooltipText)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width, 26)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  if box.SetAutoFocus then
    box:SetAutoFocus(false)
  end
  if box.SetNumeric then
    box:SetNumeric(true)
  end
  if box.SetMaxLetters then
    box:SetMaxLetters(8)
  end
  box:SetScript("OnEnterPressed", function(self)
    if callback then
      callback(self:GetText())
    end
    refreshSettingsOwner(parent)
  end)
  if tooltipText then
    box:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  return box
end

local function cycleValue(current, ordered)
  local currentIndex = 1
  for i = 1, #ordered do
    if ordered[i] == current then
      currentIndex = i
      break
    end
  end
  local nextIndex = currentIndex + 1
  if nextIndex > #ordered then
    nextIndex = 1
  end
  return ordered[nextIndex]
end

function NS.InitSettingsPanel(parent)
  if settingsFrame then
    return settingsFrame
  end

  settingsFrame = CreateFrame("Frame", "DingTimerSettingsPanel", parent)
  settingsFrame:SetAllPoints(parent)
  settingsFrame.controls = {}
  settingsFrame.summaryCards = {}

  local _, scrollChild = NS.UI.CreateScrollFrame(settingsFrame, 704, 736)

  if NS.UI and NS.UI.CreateMetricCard then
    settingsFrame.summaryCards.output = NS.UI.CreateMetricCard(scrollChild, 160, 60, 16, -18, "Output")
    settingsFrame.summaryCards.hud = NS.UI.CreateMetricCard(scrollChild, 160, 60, 186, -18, "HUD")
    settingsFrame.summaryCards.graph = NS.UI.CreateMetricCard(scrollChild, 160, 60, 356, -18, "Graph")
    settingsFrame.summaryCards.pvp = NS.UI.CreateMetricCard(scrollChild, 160, 60, 526, -18, "PvP")
  end

  local outputSection, hudSection, coachSection, graphSection, dataSection, pvpSection
  if NS.UI.CreateSectionBlock then
    outputSection = NS.UI.CreateSectionBlock(scrollChild, 16, -96, 324, 152, "Output", "Chat behavior and rolling window controls.")
    hudSection = NS.UI.CreateSectionBlock(scrollChild, 360, -96, 324, 170, "HUD", "On-screen visibility and launcher behavior.")
    coachSection = NS.UI.CreateSectionBlock(scrollChild, 16, -282, 324, 210, "Coach", "Goal presets, alert behavior, and recap access.")
    graphSection = NS.UI.CreateSectionBlock(scrollChild, 360, -282, 324, 210, "Graph", "Analysis scaling and zoom behavior.")
    dataSection = NS.UI.CreateSectionBlock(scrollChild, 16, -506, 324, 152, "Data", "Run maintenance, history retention, and quick navigation.")
    pvpSection = NS.UI.CreateSectionBlock(scrollChild, 360, -506, 324, 268, "PvP", "Honor mode, battleground auto-switching, and local-only notices.")
  else
    outputSection = CreateFrame("Frame", nil, scrollChild)
    outputSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -96)
    outputSection:SetSize(324, 152)
    outputSection.content = outputSection
    hudSection = CreateFrame("Frame", nil, scrollChild)
    hudSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 360, -96)
    hudSection:SetSize(324, 170)
    hudSection.content = hudSection
    coachSection = CreateFrame("Frame", nil, scrollChild)
    coachSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -282)
    coachSection:SetSize(324, 210)
    coachSection.content = coachSection
    graphSection = CreateFrame("Frame", nil, scrollChild)
    graphSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 360, -282)
    graphSection:SetSize(324, 210)
    graphSection.content = graphSection
    dataSection = CreateFrame("Frame", nil, scrollChild)
    dataSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -506)
    dataSection:SetSize(324, 152)
    dataSection.content = dataSection
    pvpSection = CreateFrame("Frame", nil, scrollChild)
    pvpSection:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 360, -506)
    pvpSection:SetSize(324, 268)
    pvpSection.content = pvpSection
  end

  settingsFrame.sections = {
    output = outputSection,
    hud = hudSection,
    coach = coachSection,
    graph = graphSection,
    data = dataSection,
    pvp = pvpSection,
  }

  local outputGrid = NS.UI.CreateGridLayout(outputSection.content, {
    columns = 6, cellWidth = 42, rowHeight = 26, columnGap = 8, rowGap = 10,
  })
  local hudGrid = NS.UI.CreateGridLayout(hudSection.content, {
    columns = 1, cellWidth = 280, rowHeight = 24, rowGap = 8,
  })
  local coachGrid = NS.UI.CreateGridLayout(coachSection.content, {
    columns = 6, cellWidth = 42, rowHeight = 26, columnGap = 8, rowGap = 10,
  })
  local graphGrid = NS.UI.CreateGridLayout(graphSection.content, {
    columns = 6, cellWidth = 42, rowHeight = 24, columnGap = 8, rowGap = 10,
  })
  local dataGrid = NS.UI.CreateGridLayout(dataSection.content, {
    columns = 6, cellWidth = 42, rowHeight = 26, columnGap = 8, rowGap = 10,
  })
  local pvpGrid = NS.UI.CreateGridLayout(pvpSection.content, {
    columns = 6, cellWidth = 42, rowHeight = 24, columnGap = 8, rowGap = 10,
  })

  settingsFrame.controls.enabled = createCheckbox(outputSection.content, 0, 0, "Enable chat output", function(checked)
    DingTimerDB.enabled = checked
  end, "Print XP, XP/hr, TTL, and level-up summaries to chat.")
  outputGrid:Place(settingsFrame.controls.enabled, 1, 1)
  settingsFrame.controls.modeButton = createButton(outputSection.content, 0, 0, 116, "Cycle Mode", function()
    DingTimerDB.mode = cycleValue(DingTimerDB.mode or "full", MODE_ORDER)
  end)
  outputGrid:Place(settingsFrame.controls.modeButton, 1, 2)
  settingsFrame.controls.modeValue = NS.UI.CreateValueLabel(scrollChild, 142, -159)
  settingsFrame.controls.modeValue:ClearAllPoints()
  settingsFrame.controls.modeValue:SetPoint("TOPLEFT", settingsFrame.controls.modeButton, "TOPRIGHT", 10, -5)
  settingsFrame.controls.window1m = createButton(outputSection.content, 0, 0, 44, "1m", function() NS.SetRollingWindowSeconds(60) end)
  settingsFrame.controls.window5m = createButton(outputSection.content, 0, 0, 44, "5m", function() NS.SetRollingWindowSeconds(300) end)
  settingsFrame.controls.window10m = createButton(outputSection.content, 0, 0, 52, "10m", function() NS.SetRollingWindowSeconds(600) end)
  settingsFrame.controls.windowButton = createButton(outputSection.content, 0, 0, 52, "15m", function() NS.SetRollingWindowSeconds(900) end)
  outputGrid:Place(settingsFrame.controls.window1m, 1, 3)
  outputGrid:Place(settingsFrame.controls.window5m, 2, 3, 10)
  outputGrid:Place(settingsFrame.controls.window10m, 3, 3, 20)
  outputGrid:Place(settingsFrame.controls.windowButton, 5, 3, 8)
  settingsFrame.controls.windowValue = NS.UI.CreateValueLabel(scrollChild, 242, -193)
  settingsFrame.controls.windowValue:ClearAllPoints()
  settingsFrame.controls.windowValue:SetPoint("TOPLEFT", settingsFrame.controls.windowButton, "TOPRIGHT", 10, -5)

  settingsFrame.controls.float = createCheckbox(hudSection.content, 0, 0, "Show floating HUD", function(checked)
    DingTimerDB.float = checked
    NS.setFloatVisible(checked)
  end, "Display the compact TTL and pace HUD above your character.")
  hudGrid:Place(settingsFrame.controls.float, 1, 1)
  settingsFrame.controls.floatLocked = createCheckbox(hudSection.content, 0, 0, "Lock floating HUD", function(checked)
    DingTimerDB.floatLocked = checked
  end, "Prevent the floating HUD from being dragged.")
  hudGrid:Place(settingsFrame.controls.floatLocked, 1, 2)
  settingsFrame.controls.floatShowInCombat = createCheckbox(hudSection.content, 0, 0, "Show floating HUD in combat", function(checked)
    DingTimerDB.floatShowInCombat = checked
    if DingTimerDB.float then
      NS.setFloatVisible(true)
    end
  end, "Keep the floating HUD visible during combat instead of hiding it automatically.")
  hudGrid:Place(settingsFrame.controls.floatShowInCombat, 1, 3)
  settingsFrame.controls.minimapHidden = createCheckbox(hudSection.content, 0, 0, "Hide minimap button", function(checked)
    DingTimerDB.minimapHidden = checked
    if DingTimerMinimapButton then
      if checked then
        DingTimerMinimapButton:Hide()
      else
        DingTimerMinimapButton:Show()
      end
    end
  end, "Remove the DingTimer launcher from the minimap ring.")
  hudGrid:Place(settingsFrame.controls.minimapHidden, 1, 4)

  settingsFrame.controls.cycleGoalButton = createButton(coachSection.content, 0, 0, 116, "Cycle Goal", function()
    local coach = ensureCoachConfig()
    if NS.SetCoachGoal then
      NS.SetCoachGoal(cycleValue(coach.goal, GOAL_ORDER))
    end
  end)
  coachGrid:Place(settingsFrame.controls.cycleGoalButton, 1, 1)
  settingsFrame.controls.goalValue = NS.UI.CreateValueLabel(scrollChild, 142, -283)
  settingsFrame.controls.goalValue:ClearAllPoints()
  settingsFrame.controls.goalValue:SetPoint("TOPLEFT", settingsFrame.controls.cycleGoalButton, "TOPRIGHT", 10, -5)
  settingsFrame.controls.alertsEnabled = createCheckbox(coachSection.content, 0, 0, "Enable coach alerts", function(checked)
    ensureCoachConfig().alertsEnabled = checked
  end, "Store idle, pace-drop, and best-segment alerts during the session.")
  coachGrid:Place(settingsFrame.controls.alertsEnabled, 1, 2)
  settingsFrame.controls.chatAlerts = createCheckbox(coachSection.content, 0, 0, "Print coach alerts to chat", function(checked)
    ensureCoachConfig().chatAlerts = checked
  end, "Echo coach alerts into chat in addition to the Live panel.")
  coachGrid:Place(settingsFrame.controls.chatAlerts, 1, 3)
  settingsFrame.controls.recapButton = createButton(coachSection.content, 0, 0, 88, "Recap", function()
    if NS.ShowCoachRecap then
      NS.ShowCoachRecap()
    end
  end)
  coachGrid:Place(settingsFrame.controls.recapButton, 1, 4)
  settingsFrame.controls.coachInfo = coachSection.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.coachInfo:SetPoint("TOPLEFT", settingsFrame.controls.recapButton, "TOPRIGHT", 8, -6)
  settingsFrame.controls.coachInfo:SetWidth(200)
  settingsFrame.controls.coachInfo:SetJustifyH("LEFT")
  settingsFrame.controls.coachInfo:SetText("")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(settingsFrame.controls.coachInfo, "subtle")
  end

  settingsFrame.controls.cycleScaleButton = createButton(graphSection.content, 0, 0, 116, "Cycle Scale", function()
    if NS.CycleGraphScaleMode then
      NS.CycleGraphScaleMode()
    end
  end)
  graphGrid:Place(settingsFrame.controls.cycleScaleButton, 1, 1)
  settingsFrame.controls.fitButton = createButton(graphSection.content, 0, 0, 70, "Fit", function()
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
  end)
  graphGrid:Place(settingsFrame.controls.fitButton, 4, 1, 8)
  settingsFrame.controls.graphDecButton = createButton(graphSection.content, 0, 0, 28, "-", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(-25000)
    end
  end)
  graphGrid:Place(settingsFrame.controls.graphDecButton, 5, 1, 16)
  settingsFrame.controls.graphIncButton = createButton(graphSection.content, 0, 0, 28, "+", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(25000)
    end
  end)
  graphGrid:Place(settingsFrame.controls.graphIncButton, 6, 1, 12)
  settingsFrame.controls.graphScaleValue = NS.UI.CreateValueLabel(graphSection.content, 0, 0)
  graphGrid:Place(settingsFrame.controls.graphScaleValue, 1, 2)
  settingsFrame.controls.graphMaxValue = NS.UI.CreateValueLabel(graphSection.content, 0, 0)
  graphGrid:Place(settingsFrame.controls.graphMaxValue, 1, 3)
  settingsFrame.controls.graphZoomValue = NS.UI.CreateValueLabel(graphSection.content, 0, 0)
  graphGrid:Place(settingsFrame.controls.graphZoomValue, 1, 4)
  settingsFrame.controls.zoom3m = createButton(graphSection.content, 0, 0, 40, "3m", function() NS.SetGraphZoom("3m") end)
  settingsFrame.controls.zoom5m = createButton(graphSection.content, 0, 0, 40, "5m", function() NS.SetGraphZoom("5m") end)
  settingsFrame.controls.zoom15m = createButton(graphSection.content, 0, 0, 40, "15m", function() NS.SetGraphZoom("15m") end)
  settingsFrame.controls.zoom30m = createButton(graphSection.content, 0, 0, 40, "30m", function() NS.SetGraphZoom("30m") end)
  settingsFrame.controls.zoom60m = createButton(graphSection.content, 0, 0, 40, "60m", function() NS.SetGraphZoom("60m") end)
  graphGrid:Place(settingsFrame.controls.zoom3m, 1, 5)
  graphGrid:Place(settingsFrame.controls.zoom5m, 2, 5, 6)
  graphGrid:Place(settingsFrame.controls.zoom15m, 3, 5, 12)
  graphGrid:Place(settingsFrame.controls.zoom30m, 4, 5, 18)
  graphGrid:Place(settingsFrame.controls.zoom60m, 5, 5, 24)

  settingsFrame.controls.togglePvpMode = createButton(pvpSection.content, 0, 0, 116, "Toggle Mode", function()
    if NS.TogglePvpMode then
      NS.TogglePvpMode(GetTime and GetTime() or nil)
    end
  end)
  pvpGrid:Place(settingsFrame.controls.togglePvpMode, 1, 1)
  settingsFrame.controls.goalCapButton = createButton(pvpSection.content, 0, 0, 70, "Goal Cap", function()
    if NS.SetPvpGoal then
      NS.SetPvpGoal("cap")
    end
  end)
  pvpGrid:Place(settingsFrame.controls.goalCapButton, 4, 1, 8)
  settingsFrame.controls.goalOffButton = createButton(pvpSection.content, 0, 0, 62, "Goal Off", function()
    if NS.SetPvpGoal then
      NS.SetPvpGoal("off")
    end
  end)
  pvpGrid:Place(settingsFrame.controls.goalOffButton, 5, 1, 10)
  settingsFrame.controls.pvpGoalLabel = pvpSection.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  settingsFrame.controls.pvpGoalLabel:SetPoint("TOPLEFT", pvpSection.content, "TOPLEFT", 0, -38)
  settingsFrame.controls.pvpGoalLabel:SetText("Custom Honor goal")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(settingsFrame.controls.pvpGoalLabel, "subtle")
  end
  settingsFrame.controls.pvpGoal = createEditBox(pvpSection.content, 0, 0, 120, function(text)
    if NS.SetPvpGoal then
      local ok, result = NS.SetPvpGoal(text)
      if not ok and NS.chat then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " " .. tostring(result))
      end
    end
  end, "Enter a custom absolute Honor target and press Enter. Use /ding pvp goal <honor> for the same action.")
  pvpGrid:Place(settingsFrame.controls.pvpGoal, 1, 2)
  settingsFrame.controls.pvpAutoSwitch = createCheckbox(pvpSection.content, 0, 0, "Auto-switch in battlegrounds", function(checked)
    if NS.SetPvpAutoSwitch then
      NS.SetPvpAutoSwitch(checked)
    end
  end, "When enabled, entering a battleground automatically enables PvP mode and leaving after the recap grace window returns to leveling mode.")
  pvpGrid:Place(settingsFrame.controls.pvpAutoSwitch, 1, 4)
  settingsFrame.controls.pvpMilestones = createCheckbox(pvpSection.content, 0, 0, "Honor milestone notices", function(checked)
    local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
    if settings then
      settings.milestoneAnnouncements = checked
    end
  end, "Print local milestone notices when your total Honor crosses the configured threshold.")
  pvpGrid:Place(settingsFrame.controls.pvpMilestones, 1, 5)
  settingsFrame.controls.pvpRecap = createCheckbox(pvpSection.content, 0, 0, "Battleground recap notices", function(checked)
    local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
    if settings then
      settings.matchRecap = checked
    end
  end, "Print a local recap after battleground exit once the grace window closes.")
  pvpGrid:Place(settingsFrame.controls.pvpRecap, 1, 6)
  settingsFrame.controls.pvpInfo = pvpSection.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.pvpInfo:SetPoint("TOPLEFT", pvpSection.content, "TOPLEFT", 0, -174)
  settingsFrame.controls.pvpInfo:SetWidth(284)
  settingsFrame.controls.pvpInfo:SetJustifyH("LEFT")
  settingsFrame.controls.pvpInfo:SetText("")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(settingsFrame.controls.pvpInfo, "subtle")
  end

  settingsFrame.controls.gotoLive = createButton(dataSection.content, 0, 0, 72, "Live", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(1)
    end
  end)
  dataGrid:Place(settingsFrame.controls.gotoLive, 1, 1)
  settingsFrame.controls.gotoGraph = createButton(dataSection.content, 0, 0, 72, "Graph", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(2)
    end
  end)
  dataGrid:Place(settingsFrame.controls.gotoGraph, 3, 1, 6)
  settingsFrame.controls.gotoHistory = createButton(dataSection.content, 0, 0, 84, "History", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(3)
    end
  end)
  dataGrid:Place(settingsFrame.controls.gotoHistory, 5, 1, 4)
  settingsFrame.controls.keep10Button = createButton(dataSection.content, 0, 0, 84, "Keep 10", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(10)
    end
  end)
  dataGrid:Place(settingsFrame.controls.keep10Button, 1, 2)
  settingsFrame.controls.keep30Button = createButton(dataSection.content, 0, 0, 84, "Keep 30", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(30)
    end
  end)
  dataGrid:Place(settingsFrame.controls.keep30Button, 3, 2, 6)
  settingsFrame.controls.keep50Button = createButton(dataSection.content, 0, 0, 84, "Keep 50", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(50)
    end
  end)
  dataGrid:Place(settingsFrame.controls.keep50Button, 5, 2, 4)
  settingsFrame.controls.keepValue = dataSection.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.keepValue:SetPoint("TOPLEFT", dataSection.content, "TOPLEFT", 0, -70)
  settingsFrame.controls.keepValue:SetWidth(284)
  settingsFrame.controls.keepValue:SetText("")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(settingsFrame.controls.keepValue, "subtle")
  end

  NS.CreateConfirmButton(settingsFrame, 16, 14, 140, "Reset Session", "Confirm Reset", function()
    if NS.ResetSession then
      NS.ResetSession("MANUAL_RESET")
    end
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)
  NS.CreateConfirmButton(settingsFrame, 166, 14, 140, "Clear History", "Confirm Clear", function()
    if NS.ClearCurrentProfileHistory then
      NS.ClearCurrentProfileHistory()
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " history cleared for this character.")
    end
  end)

  local footer = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMRIGHT", -16, 12)
  footer:SetText("Settings hub")
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(footer, "subtle")
  end

  function settingsFrame:Refresh()
    local coach = ensureCoachConfig()
    self.controls.enabled:SetChecked(DingTimerDB.enabled)
    self.controls.float:SetChecked(DingTimerDB.float)
    self.controls.floatLocked:SetChecked(DingTimerDB.floatLocked)
    self.controls.floatShowInCombat:SetChecked(DingTimerDB.floatShowInCombat)
    self.controls.minimapHidden:SetChecked(DingTimerDB.minimapHidden)
    self.controls.alertsEnabled:SetChecked(coach.alertsEnabled)
    self.controls.chatAlerts:SetChecked(coach.chatAlerts)
    local pvp = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or {}
    self.controls.pvpAutoSwitch:SetChecked(pvp.autoSwitchBattlegrounds == true)
    self.controls.pvpMilestones:SetChecked(pvp.milestoneAnnouncements == true)
    self.controls.pvpRecap:SetChecked(pvp.matchRecap == true)
    local customGoalText = ""
    if pvp.goalMode == "custom" and pvp.customGoalHonor ~= nil then
      customGoalText = tostring(pvp.customGoalHonor)
    end
    self.controls.pvpGoal:SetText(customGoalText)

    local modeText = (DingTimerDB.mode == "ttl") and "TTL only" or "Full output"
    self.controls.modeValue:SetText("Mode: " .. modeText)
    self.controls.windowValue:SetText("Window: " .. NS.fmtTime(DingTimerDB.windowSeconds or 600))

    self.controls.goalValue:SetText("Goal: " .. tostring(coach.goal))
    self.controls.coachInfo:SetText(string.format(
      "Idle after %ss  |  Pace drop threshold %s%%  |  Alert cooldown %ss",
      tostring(coach.idleSeconds),
      tostring(coach.paceDropPct),
      tostring(coach.alertCooldownSeconds)
    ))

    local scaleMode = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
    self.controls.graphScaleValue:SetText("Scale: " .. NS.GetGraphScaleModeLabel(scaleMode, true))
    self.controls.graphMaxValue:SetText("Fixed max: " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))
    self.controls.graphZoomValue:SetText("Zoom: " .. tostring(math.floor((tonumber(DingTimerDB.graphWindowSeconds) or 300) / 60)) .. "m")
    self.controls.pvpInfo:SetText(string.format(
      "Mode: %s  |  Goal: %s  |  History: %d PvP sessions\nUse '/ding pvp goal <honor>' to set a custom absolute Honor goal.",
      (NS.IsPvpMode and NS.IsPvpMode()) and "PvP" or "Leveling",
      (NS.GetPvpGoalLabel and NS.GetPvpGoalLabel()) or "Cap",
      tonumber(pvp.keepSessions) or 30
    ))
    self.controls.keepValue:SetText("History retention: " .. tostring((DingTimerDB.xp and DingTimerDB.xp.keepSessions) or 30) .. " runs")

    if self.summaryCards and NS.UI and NS.UI.SetMetricCard then
      NS.UI.SetMetricCard(
        self.summaryCards.output,
        modeText,
        "Window " .. NS.fmtTime(DingTimerDB.windowSeconds or 600)
      )
      NS.UI.SetMetricCard(
        self.summaryCards.hud,
        DingTimerDB.float and "Shown" or "Hidden",
        (DingTimerDB.floatLocked and "Locked" or "Unlocked")
          .. "  |  "
          .. ((DingTimerDB.minimapHidden and "Minimap hidden") or "Minimap shown")
      )
      NS.UI.SetMetricCard(
        self.summaryCards.graph,
        NS.GetGraphScaleModeLabel(scaleMode, true),
        "Zoom " .. tostring(math.floor((tonumber(DingTimerDB.graphWindowSeconds) or 300) / 60)) .. "m"
      )
      NS.UI.SetMetricCard(
        self.summaryCards.pvp,
        (NS.IsPvpMode and NS.IsPvpMode()) and "PvP" or "Leveling",
        "Goal " .. ((NS.GetPvpGoalLabel and NS.GetPvpGoalLabel()) or "Cap")
      )
    end
  end

  settingsFrame:SetScript("OnShow", function(self)
    self:Refresh()
  end)

  settingsFrame:Hide()
  return settingsFrame
end

function NS.RefreshSettingsPanel()
  if settingsFrame then
    settingsFrame:Refresh()
  end
end
