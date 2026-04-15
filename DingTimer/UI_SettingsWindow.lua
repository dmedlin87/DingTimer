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
  text:SetText(label)
  cb.text = text
  if cb.SetHitRectInsets then
    cb:SetHitRectInsets(0, -160, 0, 0)
  end
  return cb
end

local function createButton(parent, x, y, width, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 24)
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
  box:SetSize(width, 24)
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

  local _, scrollChild = NS.UI.CreateScrollFrame(settingsFrame, 680, 720)

  if NS.UI and NS.UI.CreateMetricCard then
    settingsFrame.summaryCards.output = NS.UI.CreateMetricCard(scrollChild, 151, 56, 16, -18, "Output")
    settingsFrame.summaryCards.hud = NS.UI.CreateMetricCard(scrollChild, 151, 56, 177, -18, "HUD")
    settingsFrame.summaryCards.graph = NS.UI.CreateMetricCard(scrollChild, 151, 56, 338, -18, "Graph")
    settingsFrame.summaryCards.pvp = NS.UI.CreateMetricCard(scrollChild, 151, 56, 499, -18, "PvP")
  end

  if NS.UI.CreateSectionBlock then
    NS.UI.CreateSectionBlock(scrollChild, 16, -92, 304, 130, "Output", "Chat behavior and rolling window controls.")
    NS.UI.CreateSectionBlock(scrollChild, 360, -92, 304, 160, "HUD", "On-screen visibility and launcher behavior.")
    NS.UI.CreateSectionBlock(scrollChild, 16, -268, 304, 190, "Coach", "Goal presets, alert behavior, and recap access.")
    NS.UI.CreateSectionBlock(scrollChild, 360, -268, 304, 190, "Graph", "Analysis scaling and zoom behavior.")
    NS.UI.CreateSectionBlock(scrollChild, 16, -474, 304, 130, "Data", "Run maintenance, history retention, and quick navigation.")
    NS.UI.CreateSectionBlock(scrollChild, 360, -474, 304, 230, "PvP", "Honor mode, battleground auto-switching, and local-only notices.")
  else
    NS.UI.CreateSectionTitle(scrollChild, 16, -92, "Output", "Chat behavior and rolling window controls.")
    NS.UI.CreateSectionTitle(scrollChild, 360, -92, "HUD", "On-screen visibility and launcher behavior.")
    NS.UI.CreateSectionTitle(scrollChild, 16, -268, "Coach", "Goal presets, alert behavior, and recap access.")
    NS.UI.CreateSectionTitle(scrollChild, 360, -268, "Graph", "Analysis scaling and zoom behavior.")
    NS.UI.CreateSectionTitle(scrollChild, 16, -474, "Data", "Run maintenance, history retention, and quick navigation.")
    NS.UI.CreateSectionTitle(scrollChild, 360, -474, "PvP", "Honor mode, battleground auto-switching, and local-only notices.")
  end

  settingsFrame.controls.enabled = createCheckbox(scrollChild, 16, -128, "Enable chat output", function(checked)
    DingTimerDB.enabled = checked
  end, "Print XP, XP/hr, TTL, and level-up summaries to chat.")
  settingsFrame.controls.modeButton = createButton(scrollChild, 16, -156, 116, "Cycle Mode", function()
    DingTimerDB.mode = cycleValue(DingTimerDB.mode or "full", MODE_ORDER)
  end)
  settingsFrame.controls.modeValue = NS.UI.CreateValueLabel(scrollChild, 142, -159)
  settingsFrame.controls.modeValue:ClearAllPoints()
  settingsFrame.controls.modeValue:SetPoint("TOPLEFT", settingsFrame.controls.modeButton, "TOPRIGHT", 10, -5)
  createButton(scrollChild, 16, -184, 44, "1m", function() NS.SetRollingWindowSeconds(60) end)
  createButton(scrollChild, 68, -184, 44, "5m", function() NS.SetRollingWindowSeconds(300) end)
  createButton(scrollChild, 120, -184, 52, "10m", function() NS.SetRollingWindowSeconds(600) end)
  settingsFrame.controls.windowButton = createButton(scrollChild, 180, -184, 52, "15m", function() NS.SetRollingWindowSeconds(900) end)
  settingsFrame.controls.windowValue = NS.UI.CreateValueLabel(scrollChild, 242, -193)
  settingsFrame.controls.windowValue:ClearAllPoints()
  settingsFrame.controls.windowValue:SetPoint("TOPLEFT", settingsFrame.controls.windowButton, "TOPRIGHT", 10, -5)

  settingsFrame.controls.float = createCheckbox(scrollChild, 360, -128, "Show floating HUD", function(checked)
    DingTimerDB.float = checked
    NS.setFloatVisible(checked)
  end, "Display the compact TTL and pace HUD above your character.")
  settingsFrame.controls.floatLocked = createCheckbox(scrollChild, 360, -156, "Lock floating HUD", function(checked)
    DingTimerDB.floatLocked = checked
  end, "Prevent the floating HUD from being dragged.")
  settingsFrame.controls.floatShowInCombat = createCheckbox(scrollChild, 360, -184, "Show floating HUD in combat", function(checked)
    DingTimerDB.floatShowInCombat = checked
    if DingTimerDB.float then
      NS.setFloatVisible(true)
    end
  end, "Keep the floating HUD visible during combat instead of hiding it automatically.")
  settingsFrame.controls.minimapHidden = createCheckbox(scrollChild, 360, -212, "Hide minimap button", function(checked)
    DingTimerDB.minimapHidden = checked
    if DingTimerMinimapButton then
      if checked then
        DingTimerMinimapButton:Hide()
      else
        DingTimerMinimapButton:Show()
      end
    end
  end, "Remove the DingTimer launcher from the minimap ring.")

  settingsFrame.controls.cycleGoalButton = createButton(scrollChild, 16, -304, 116, "Cycle Goal", function()
    local coach = ensureCoachConfig()
    if NS.SetCoachGoal then
      NS.SetCoachGoal(cycleValue(coach.goal, GOAL_ORDER))
    end
  end)
  settingsFrame.controls.goalValue = NS.UI.CreateValueLabel(scrollChild, 142, -283)
  settingsFrame.controls.goalValue:ClearAllPoints()
  settingsFrame.controls.goalValue:SetPoint("TOPLEFT", settingsFrame.controls.cycleGoalButton, "TOPRIGHT", 10, -5)
  settingsFrame.controls.alertsEnabled = createCheckbox(scrollChild, 16, -332, "Enable coach alerts", function(checked)
    ensureCoachConfig().alertsEnabled = checked
  end, "Store idle, pace-drop, and best-segment alerts during the session.")
  settingsFrame.controls.chatAlerts = createCheckbox(scrollChild, 16, -360, "Print coach alerts to chat", function(checked)
    ensureCoachConfig().chatAlerts = checked
  end, "Echo coach alerts into chat in addition to the Live panel.")
  settingsFrame.controls.recapButton = createButton(scrollChild, 16, -388, 88, "Recap", function()
    if NS.ShowCoachRecap then
      NS.ShowCoachRecap()
    end
  end)
  settingsFrame.controls.coachInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.coachInfo:SetPoint("TOPLEFT", settingsFrame.controls.recapButton, "TOPRIGHT", 8, -6)
  settingsFrame.controls.coachInfo:SetWidth(190)
  settingsFrame.controls.coachInfo:SetJustifyH("LEFT")
  settingsFrame.controls.coachInfo:SetText("")

  createButton(scrollChild, 360, -304, 116, "Cycle Scale", function()
    if NS.CycleGraphScaleMode then
      NS.CycleGraphScaleMode()
    end
  end)
  createButton(scrollChild, 484, -304, 70, "Fit", function()
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
  end)
  createButton(scrollChild, 562, -304, 28, "-", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(-25000)
    end
  end)
  createButton(scrollChild, 596, -304, 28, "+", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(25000)
    end
  end)
  settingsFrame.controls.graphScaleValue = NS.UI.CreateValueLabel(scrollChild, 360, -336)
  settingsFrame.controls.graphMaxValue = NS.UI.CreateValueLabel(scrollChild, 360, -358)
  settingsFrame.controls.graphZoomValue = NS.UI.CreateValueLabel(scrollChild, 360, -380)
  createButton(scrollChild, 360, -402, 40, "3m", function() NS.SetGraphZoom("3m") end)
  createButton(scrollChild, 406, -402, 40, "5m", function() NS.SetGraphZoom("5m") end)
  createButton(scrollChild, 452, -402, 40, "15m", function() NS.SetGraphZoom("15m") end)
  createButton(scrollChild, 498, -402, 40, "30m", function() NS.SetGraphZoom("30m") end)
  createButton(scrollChild, 544, -402, 40, "60m", function() NS.SetGraphZoom("60m") end)

  createButton(scrollChild, 360, -510, 116, "Toggle Mode", function()
    if NS.TogglePvpMode then
      NS.TogglePvpMode(GetTime and GetTime() or nil)
    end
  end)
  createButton(scrollChild, 484, -510, 70, "Goal Cap", function()
    if NS.SetPvpGoal then
      NS.SetPvpGoal("cap")
    end
  end)
  createButton(scrollChild, 562, -510, 62, "Goal Off", function()
    if NS.SetPvpGoal then
      NS.SetPvpGoal("off")
    end
  end)
  settingsFrame.controls.pvpGoalLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  settingsFrame.controls.pvpGoalLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 360, -538)
  settingsFrame.controls.pvpGoalLabel:SetText("Custom Honor goal")
  settingsFrame.controls.pvpGoal = createEditBox(scrollChild, 360, -558, 120, function(text)
    if NS.SetPvpGoal then
      local ok, result = NS.SetPvpGoal(text)
      if not ok and NS.chat then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " " .. tostring(result))
      end
    end
  end, "Enter a custom absolute Honor target and press Enter. Use /ding pvp goal <honor> for the same action.")
  settingsFrame.controls.pvpAutoSwitch = createCheckbox(scrollChild, 360, -586, "Auto-switch in battlegrounds", function(checked)
    if NS.SetPvpAutoSwitch then
      NS.SetPvpAutoSwitch(checked)
    end
  end, "When enabled, entering a battleground automatically enables PvP mode and leaving after the recap grace window returns to leveling mode.")
  settingsFrame.controls.pvpMilestones = createCheckbox(scrollChild, 360, -614, "Honor milestone notices", function(checked)
    local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
    if settings then
      settings.milestoneAnnouncements = checked
    end
  end, "Print local milestone notices when your total Honor crosses the configured threshold.")
  settingsFrame.controls.pvpRecap = createCheckbox(scrollChild, 360, -642, "Battleground recap notices", function(checked)
    local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
    if settings then
      settings.matchRecap = checked
    end
  end, "Print a local recap after battleground exit once the grace window closes.")
  settingsFrame.controls.pvpInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.pvpInfo:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 360, -670)
  settingsFrame.controls.pvpInfo:SetWidth(290)
  settingsFrame.controls.pvpInfo:SetJustifyH("LEFT")
  settingsFrame.controls.pvpInfo:SetText("")

  createButton(scrollChild, 16, -510, 72, "Live", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(1)
    end
  end)
  createButton(scrollChild, 96, -510, 72, "Graph", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(2)
    end
  end)
  createButton(scrollChild, 176, -510, 84, "History", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(3)
    end
  end)
  settingsFrame.controls.keep10Button = createButton(scrollChild, 16, -538, 84, "Keep 10", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(10)
    end
  end)
  settingsFrame.controls.keep30Button = createButton(scrollChild, 108, -538, 84, "Keep 30", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(30)
    end
  end)
  settingsFrame.controls.keep50Button = createButton(scrollChild, 200, -538, 84, "Keep 50", function()
    if NS.SetKeepSessions then
      NS.SetKeepSessions(50)
    end
  end)
  settingsFrame.controls.keepValue = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.keepValue:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 16, -566)
  settingsFrame.controls.keepValue:SetText("")

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
