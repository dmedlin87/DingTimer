local ADDON, NS = ...

local settingsFrame = nil

local GOAL_ORDER = { "off", "ding", "30m", "60m" }
local MODE_ORDER = { "full", "ttl" }

local function ensureCoachConfig()
  if NS.EnsureCoachConfig then
    return NS.EnsureCoachConfig()
  end

  DingTimerDB.coach = DingTimerDB.coach or {}
  if DingTimerDB.coach.goal ~= "off" and DingTimerDB.coach.goal ~= "ding" and DingTimerDB.coach.goal ~= "30m" and DingTimerDB.coach.goal ~= "60m" then
    DingTimerDB.coach.goal = "ding"
  end
  if DingTimerDB.coach.alertsEnabled == nil then DingTimerDB.coach.alertsEnabled = true end
  if DingTimerDB.coach.chatAlerts == nil then DingTimerDB.coach.chatAlerts = true end

  local idleSeconds = math.floor(tonumber(DingTimerDB.coach.idleSeconds) or 90)
  if idleSeconds < 30 then idleSeconds = 30 end
  DingTimerDB.coach.idleSeconds = idleSeconds

  local paceDropPct = math.floor(tonumber(DingTimerDB.coach.paceDropPct) or 15)
  if paceDropPct < 5 then paceDropPct = 5 end
  if paceDropPct > 50 then paceDropPct = 50 end
  DingTimerDB.coach.paceDropPct = paceDropPct

  local alertCooldownSeconds = math.floor(tonumber(DingTimerDB.coach.alertCooldownSeconds) or 90)
  if alertCooldownSeconds < 30 then alertCooldownSeconds = 30 end
  DingTimerDB.coach.alertCooldownSeconds = alertCooldownSeconds

  local alertHistoryLimit = math.floor(tonumber(DingTimerDB.coach.alertHistoryLimit) or 4)
  if alertHistoryLimit < 1 then alertHistoryLimit = 1 end
  if alertHistoryLimit > 8 then alertHistoryLimit = 8 end
  DingTimerDB.coach.alertHistoryLimit = alertHistoryLimit

  return DingTimerDB.coach
end

local function createCheckbox(parent, x, y, label, callback, tooltipText)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb:SetScript("OnClick", function(self)
    if callback then
      callback(self:GetChecked())
    end
    if parent.Refresh then
      parent:Refresh()
    end
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
  btn:SetScript("OnClick", function(...)
    if callback then
      callback(...)
    end
    if parent.Refresh then
      parent:Refresh()
    end
  end)
  return btn
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

  NS.UI.CreateSectionTitle(settingsFrame, 16, -18, "Output", "Chat behavior and rolling window controls.")
  settingsFrame.controls.enabled = createCheckbox(settingsFrame, 16, -48, "Enable chat output", function(checked)
    DingTimerDB.enabled = checked
  end, "Print XP, XP/hr, TTL, and level-up summaries to chat.")
  createButton(settingsFrame, 16, -80, 116, "Cycle Mode", function()
    DingTimerDB.mode = cycleValue(DingTimerDB.mode or "full", MODE_ORDER)
  end)
  settingsFrame.controls.modeValue = NS.UI.CreateValueLabel(settingsFrame, 142, -85)
  createButton(settingsFrame, 16, -114, 44, "1m", function() NS.SetRollingWindowSeconds(60) end)
  createButton(settingsFrame, 68, -114, 44, "5m", function() NS.SetRollingWindowSeconds(300) end)
  createButton(settingsFrame, 120, -114, 52, "10m", function() NS.SetRollingWindowSeconds(600) end)
  createButton(settingsFrame, 180, -114, 52, "15m", function() NS.SetRollingWindowSeconds(900) end)
  settingsFrame.controls.windowValue = NS.UI.CreateValueLabel(settingsFrame, 242, -119)

  NS.UI.CreateSectionTitle(settingsFrame, 360, -18, "HUD", "On-screen visibility and launcher behavior.")
  settingsFrame.controls.float = createCheckbox(settingsFrame, 360, -48, "Show floating HUD", function(checked)
    DingTimerDB.float = checked
    NS.setFloatVisible(checked)
  end, "Display the compact TTL and pace HUD above your character.")
  settingsFrame.controls.floatLocked = createCheckbox(settingsFrame, 360, -76, "Lock floating HUD", function(checked)
    DingTimerDB.floatLocked = checked
  end, "Prevent the floating HUD from being dragged.")
  settingsFrame.controls.minimapHidden = createCheckbox(settingsFrame, 360, -104, "Hide minimap button", function(checked)
    DingTimerDB.minimapHidden = checked
    if DingTimerMinimapButton then
      if checked then
        DingTimerMinimapButton:Hide()
      else
        DingTimerMinimapButton:Show()
      end
    end
  end, "Remove the DingTimer launcher from the minimap ring.")

  NS.UI.CreateSectionTitle(settingsFrame, 16, -168, "Coach", "Goal presets, alert behavior, and recap access.")
  createButton(settingsFrame, 16, -198, 116, "Cycle Goal", function()
    local coach = ensureCoachConfig()
    coach.goal = cycleValue(coach.goal, GOAL_ORDER)
  end)
  settingsFrame.controls.goalValue = NS.UI.CreateValueLabel(settingsFrame, 142, -203)
  settingsFrame.controls.alertsEnabled = createCheckbox(settingsFrame, 16, -232, "Enable coach alerts", function(checked)
    ensureCoachConfig().alertsEnabled = checked
  end, "Store idle, pace-drop, and best-segment alerts during the session.")
  settingsFrame.controls.chatAlerts = createCheckbox(settingsFrame, 16, -260, "Print coach alerts to chat", function(checked)
    ensureCoachConfig().chatAlerts = checked
  end, "Echo coach alerts into chat in addition to the Live panel.")
  createButton(settingsFrame, 16, -294, 88, "Recap", function()
    if NS.ShowCoachRecap then
      NS.ShowCoachRecap()
    end
  end)
  settingsFrame.controls.coachInfo = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.coachInfo:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 112, -300)
  settingsFrame.controls.coachInfo:SetWidth(220)
  settingsFrame.controls.coachInfo:SetJustifyH("LEFT")
  settingsFrame.controls.coachInfo:SetText("")

  NS.UI.CreateSectionTitle(settingsFrame, 360, -168, "Graph", "Analysis scaling and zoom behavior.")
  createButton(settingsFrame, 360, -198, 116, "Cycle Scale", function()
    if NS.CycleGraphScaleMode then
      NS.CycleGraphScaleMode()
    end
  end)
  createButton(settingsFrame, 484, -198, 70, "Fit", function()
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
  end)
  createButton(settingsFrame, 562, -198, 28, "-", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(-25000)
    end
  end)
  createButton(settingsFrame, 596, -198, 28, "+", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(25000)
    end
  end)
  settingsFrame.controls.graphScaleValue = NS.UI.CreateValueLabel(settingsFrame, 360, -231)
  settingsFrame.controls.graphMaxValue = NS.UI.CreateValueLabel(settingsFrame, 360, -250)
  settingsFrame.controls.graphZoomValue = NS.UI.CreateValueLabel(settingsFrame, 360, -269)
  createButton(settingsFrame, 360, -286, 40, "3m", function() NS.SetGraphZoom("3m") end)
  createButton(settingsFrame, 406, -286, 40, "5m", function() NS.SetGraphZoom("5m") end)
  createButton(settingsFrame, 452, -286, 40, "15m", function() NS.SetGraphZoom("15m") end)
  createButton(settingsFrame, 498, -286, 40, "30m", function() NS.SetGraphZoom("30m") end)
  createButton(settingsFrame, 544, -286, 40, "60m", function() NS.SetGraphZoom("60m") end)

  NS.UI.CreateSectionTitle(settingsFrame, 16, -360, "Data", "Run maintenance, history retention, and recovery actions.")
  createButton(settingsFrame, 16, -390, 120, "Open History", function()
    if NS.ShowMainWindow then
      NS.ShowMainWindow(3)
    end
  end)
  createButton(settingsFrame, 144, -390, 92, "Keep 10", function()
    DingTimerDB.xp.keepSessions = 10
    if NS.GetProfileStore and NS.TrimSessions then
      NS.TrimSessions(NS.GetProfileStore(true), 10)
    end
  end)
  createButton(settingsFrame, 244, -390, 92, "Keep 30", function()
    DingTimerDB.xp.keepSessions = 30
    if NS.GetProfileStore and NS.TrimSessions then
      NS.TrimSessions(NS.GetProfileStore(true), 30)
    end
  end)
  createButton(settingsFrame, 344, -390, 92, "Keep 50", function()
    DingTimerDB.xp.keepSessions = 50
    if NS.GetProfileStore and NS.TrimSessions then
      NS.TrimSessions(NS.GetProfileStore(true), 50)
    end
  end)
  settingsFrame.controls.keepValue = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  settingsFrame.controls.keepValue:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -422)
  settingsFrame.controls.keepValue:SetText("")

  NS.CreateConfirmButton(settingsFrame, 16, 14, 140, "Reset Session", "Confirm Reset", function()
    if NS.RecordSession then NS.RecordSession("MANUAL_RESET") end
    NS.resetXPState()
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)
  NS.CreateConfirmButton(settingsFrame, 166, 14, 140, "Clear History", "Confirm Clear", function()
    if NS.ClearProfileSessions then
      NS.ClearProfileSessions()
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " history cleared for this character.")
    end
  end)

  local footer = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMRIGHT", -16, 12)
  footer:SetText("WoW-native coach settings")

  function settingsFrame:Refresh()
    local coach = ensureCoachConfig()
    self.controls.enabled:SetChecked(DingTimerDB.enabled)
    self.controls.float:SetChecked(DingTimerDB.float)
    self.controls.floatLocked:SetChecked(DingTimerDB.floatLocked)
    self.controls.minimapHidden:SetChecked(DingTimerDB.minimapHidden)
    self.controls.alertsEnabled:SetChecked(coach.alertsEnabled)
    self.controls.chatAlerts:SetChecked(coach.chatAlerts)

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
    self.controls.graphZoomValue:SetText("Zoom: " .. tostring(math.floor((DingTimerDB.graphWindowSeconds or 300) / 60)) .. "m")
    self.controls.keepValue:SetText("History retention: " .. tostring((DingTimerDB.xp and DingTimerDB.xp.keepSessions) or 30) .. " runs")
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
