local ADDON, NS = ...

local settingsFrame = nil

local function createSectionTitle(parent, x, y, title, description)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  header:SetText(title)

  local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  sub:SetText(description)

  return header, sub
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
    cb:SetHitRectInsets(0, -140, 0, 0)
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

local function createValueLabel(parent, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText("--")
  return fs
end

local function cycleMode()
  if DingTimerDB.mode == "ttl" then
    DingTimerDB.mode = "full"
  else
    DingTimerDB.mode = "ttl"
  end
end

function NS.InitSettingsPanel(parent)
  if settingsFrame then
    return settingsFrame
  end

  settingsFrame = CreateFrame("Frame", "DingTimerSettingsPanel", parent)
  settingsFrame:SetAllPoints(parent)

  -- Removed standalone window controls (movable, drag, closeBtn, title, sep)
  settingsFrame.controls = {}

  -- Removed Quick Actions section as navigation is now handled by tabs

  createSectionTitle(settingsFrame, 16, -118, "Visibility", "Choose which UI surfaces stay on screen.")
  settingsFrame.controls.enabled = createCheckbox(settingsFrame, 16, -146, "Enable chat output", function(checked)
    DingTimerDB.enabled = checked
  end, "Print XP, XP/hr, TTL, and level-up summaries to chat.")
  settingsFrame.controls.float = createCheckbox(settingsFrame, 16, -174, "Show floating HUD", function(checked)
    DingTimerDB.float = checked
    NS.setFloatVisible(checked)
  end, "Display the compact TTL and pace HUD above your character.")
  settingsFrame.controls.floatLocked = createCheckbox(settingsFrame, 16, -202, "Lock floating HUD", function(checked)
    DingTimerDB.floatLocked = checked
  end, "Prevent the floating HUD from being dragged.")
  settingsFrame.controls.minimapHidden = createCheckbox(settingsFrame, 16, -230, "Hide minimap button", function(checked)
    DingTimerDB.minimapHidden = checked
    if DingTimerMinimapButton then
      if checked then
        DingTimerMinimapButton:Hide()
      else
        DingTimerMinimapButton:Show()
      end
    end
  end, "Remove the DingTimer launcher from the minimap ring.")

  createSectionTitle(settingsFrame, 340, -118, "Graph", "Scale modes, fixed cap, and zoom presets.")
  local scaleButton = createButton(settingsFrame, 340, -146, 116, "Cycle Scale", function()
    if NS.CycleGraphScaleMode then
      NS.CycleGraphScaleMode()
    end
  end)
  local fitButton = createButton(settingsFrame, 464, -146, 70, "Fit", function()
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
  end)
  local minusMaxButton = createButton(settingsFrame, 542, -146, 32, "-", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(-25000)
    end
  end)
  local plusMaxButton = createButton(settingsFrame, 582, -146, 32, "+", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(25000)
    end
  end)
  settingsFrame.controls.graphScaleValue = createValueLabel(settingsFrame, 340, -179)
  settingsFrame.controls.graphMaxValue = createValueLabel(settingsFrame, 340, -198)
  settingsFrame.controls.graphZoomValue = createValueLabel(settingsFrame, 340, -217)

  local graphZoomButtons = {
    { label = "3m", x = 340 },
    { label = "5m", x = 398 },
    { label = "15m", x = 456 },
    { label = "30m", x = 514 },
    { label = "60m", x = 572 },
  }
  for _, button in ipairs(graphZoomButtons) do
    createButton(settingsFrame, button.x, -244, 40, button.label, function()
      if NS.SetGraphZoom then
        NS.SetGraphZoom(button.label)
      end
    end)
  end

  createSectionTitle(settingsFrame, 16, -286, "Output", "Set the rolling window and message style.")
  local modeButton = createButton(settingsFrame, 16, -314, 116, "Cycle Mode", function()
    cycleMode()
  end)
  settingsFrame.controls.modeValue = createValueLabel(settingsFrame, 144, -319)

  local windowButtons = {
    { label = "1m", seconds = 60, x = 16 },
    { label = "5m", seconds = 300, x = 74 },
    { label = "10m", seconds = 600, x = 132 },
    { label = "15m", seconds = 900, x = 198 },
  }
  for _, button in ipairs(windowButtons) do
    createButton(settingsFrame, button.x, -350, 52, button.label, function()
      if NS.SetRollingWindowSeconds then
        NS.SetRollingWindowSeconds(button.seconds)
      end
    end)
  end
  settingsFrame.controls.windowValue = createValueLabel(settingsFrame, 270, -355)
  settingsFrame.controls.windowValue:SetText("")

  createSectionTitle(settingsFrame, 16, -394, "Session", "Reset the current run when you are done with it.")
  local resetState = 0
  local resetTimer = nil
  local resetButton
  resetButton = createButton(settingsFrame, 16, -422, 140, "Reset Session", function()
    if resetState == 0 then
      resetState = 1
      resetButton:SetText("Confirm Reset")
      if resetTimer then
        resetTimer:Cancel()
      end
      resetTimer = C_Timer.NewTimer(3, function()
        resetState = 0
        resetButton:SetText("Reset Session")
      end)
      return
    end

    resetState = 0
    if resetTimer then
      resetTimer:Cancel()
    end
    resetButton:SetText("Reset Session")

    if NS.RecordSession then
      NS.RecordSession("MANUAL_RESET")
    end
    NS.resetXPState()
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end)

  local footer = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMRIGHT", -16, 10)
  footer:SetText("Tip: middle-click the minimap button to jump to the Graph tab.")

  function settingsFrame:Refresh()
    self.controls.enabled:SetChecked(DingTimerDB.enabled)
    self.controls.float:SetChecked(DingTimerDB.float)
    self.controls.floatLocked:SetChecked(DingTimerDB.floatLocked)
    self.controls.minimapHidden:SetChecked(DingTimerDB.minimapHidden)

    local modeText = (DingTimerDB.mode == "ttl") and "TTL only" or "Full output"
    self.controls.modeValue:SetText("Mode: " .. modeText)
    self.controls.windowValue:SetText("Window: " .. NS.fmtTime(DingTimerDB.windowSeconds or 600))

    local scaleMode = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
    self.controls.graphScaleValue:SetText("Scale: " .. NS.GetGraphScaleModeLabel(scaleMode, true))
    self.controls.graphMaxValue:SetText("Fixed max: " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))
    self.controls.graphZoomValue:SetText("Zoom: " .. tostring(math.floor((DingTimerDB.graphWindowSeconds or 300) / 60)) .. "m")
  end

  settingsFrame:SetScript("OnShow", function(self)
    self:Refresh()
  end)

  settingsFrame:Hide()
  return settingsFrame
end

-- Removed ToggleSettingsWindow since we use Tabs now
