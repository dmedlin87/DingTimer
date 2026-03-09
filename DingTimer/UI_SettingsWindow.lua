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

function NS.InitSettingsWindow()
  if settingsFrame then
    return
  end

  settingsFrame = CreateFrame("Frame", "DingTimerSettingsWindow", UIParent, "BackdropTemplate")
  settingsFrame:SetSize(470, 500)
  settingsFrame:SetPoint("CENTER")
  NS.ApplyThemeToFrame(settingsFrame)

  settingsFrame:SetMovable(true)
  settingsFrame:EnableMouse(true)
  settingsFrame:RegisterForDrag("LeftButton")
  settingsFrame:SetClampedToScreen(true)
  settingsFrame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
      return
    end
    self:StartMoving()
  end)
  settingsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.settingsWindowPosition = {
      point = point,
      relativePoint = relativePoint,
      xOfs = xOfs,
      yOfs = yOfs,
    }
  end)

  if DingTimerDB.settingsWindowPosition then
    local pos = DingTimerDB.settingsWindowPosition
    settingsFrame:ClearAllPoints()
    settingsFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  end

  local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
  end)
  closeBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  local header = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOPLEFT", 14, -12)
  header:SetText(NS.C.base .. "DingTimer Control Center" .. NS.C.r)

  local subtitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  subtitle:SetText("The graph now resizes and defaults to a visible-data fit.")

  local separator = settingsFrame:CreateTexture(nil, "ARTWORK")
  separator:SetColorTexture(0.2, 0.6, 0.8, 0.45)
  separator:SetSize(446, 1)
  separator:SetPoint("TOP", 0, -35)

  settingsFrame.controls = {}

  createSectionTitle(settingsFrame, 16, -48, "Quick Actions", "Open the surfaces you use most.")
  createButton(settingsFrame, 16, -76, 98, "Dashboard", function()
    if NS.ToggleStatsWindow then
      NS.ToggleStatsWindow()
    end
  end)
  createButton(settingsFrame, 122, -76, 98, "Graph", function()
    if NS.ToggleGraphWindow then
      NS.ToggleGraphWindow()
    end
  end)
  createButton(settingsFrame, 228, -76, 98, "Insights", function()
    if NS.ToggleInsightsWindow then
      NS.ToggleInsightsWindow()
    end
  end)
  createButton(settingsFrame, 334, -76, 98, "Reset Graph", function()
    if NS.ResetGraphLayout then
      NS.ResetGraphLayout()
    end
  end)

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
  settingsFrame.controls.graphVisible = createCheckbox(settingsFrame, 240, -146, "Show XP graph", function(checked)
    DingTimerDB.graphVisible = checked
    NS.SetGraphVisible(checked)
  end, "Show the resizable XP pace graph window.")
  settingsFrame.controls.graphLocked = createCheckbox(settingsFrame, 240, -174, "Lock XP graph", function(checked)
    DingTimerDB.graphLocked = checked
  end, "Prevent the graph window from being moved or resized.")
  settingsFrame.controls.minimapHidden = createCheckbox(settingsFrame, 240, -202, "Hide minimap button", function(checked)
    DingTimerDB.minimapHidden = checked
    if DingTimerMinimapButton then
      if checked then
        DingTimerMinimapButton:Hide()
      else
        DingTimerMinimapButton:Show()
      end
    end
  end, "Remove the DingTimer launcher from the minimap ring.")

  createSectionTitle(settingsFrame, 16, -240, "Output", "Set the rolling window and message style.")
  local modeButton = createButton(settingsFrame, 16, -268, 116, "Cycle Mode", function()
    cycleMode()
  end)
  settingsFrame.controls.modeValue = createValueLabel(settingsFrame, 144, -273)

  local windowButtons = {
    { label = "1m", seconds = 60, x = 16 },
    { label = "5m", seconds = 300, x = 74 },
    { label = "10m", seconds = 600, x = 132 },
    { label = "15m", seconds = 900, x = 198 },
  }
  for _, button in ipairs(windowButtons) do
    createButton(settingsFrame, button.x, -304, 52, button.label, function()
      if NS.SetRollingWindowSeconds then
        NS.SetRollingWindowSeconds(button.seconds)
      end
    end)
  end
  settingsFrame.controls.windowValue = createValueLabel(settingsFrame, 270, -309)
  settingsFrame.controls.windowValue:SetText("")

  createSectionTitle(settingsFrame, 16, -346, "Graph", "Scale modes, zoom presets, and the new resizable frame.")
  local scaleButton = createButton(settingsFrame, 16, -374, 116, "Cycle Scale", function()
    if NS.CycleGraphScaleMode then
      NS.CycleGraphScaleMode()
    end
  end)
  local fitButton = createButton(settingsFrame, 140, -374, 70, "Fit", function()
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
  end)
  local minusMaxButton = createButton(settingsFrame, 218, -374, 32, "-", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(-25000)
    end
  end)
  local plusMaxButton = createButton(settingsFrame, 258, -374, 32, "+", function()
    if NS.AdjustGraphFixedMax then
      NS.AdjustGraphFixedMax(25000)
    end
  end)
  settingsFrame.controls.graphScaleValue = createValueLabel(settingsFrame, 302, -379)
  settingsFrame.controls.graphMaxValue = createValueLabel(settingsFrame, 302, -398)
  settingsFrame.controls.graphSizeValue = createValueLabel(settingsFrame, 302, -417)

  local graphZoomButtons = {
    { label = "3m", x = 16 },
    { label = "5m", x = 74 },
    { label = "15m", x = 132 },
    { label = "30m", x = 198 },
    { label = "60m", x = 264 },
  }
  for _, button in ipairs(graphZoomButtons) do
    createButton(settingsFrame, button.x, -410, 52, button.label, function()
      if NS.SetGraphZoom then
        NS.SetGraphZoom(button.label)
      end
    end)
  end

  createSectionTitle(settingsFrame, 16, -446, "Session", "Reset the current run when you are done with it.")
  local resetState = 0
  local resetTimer = nil
  local resetButton
  resetButton = createButton(settingsFrame, 16, -474, 140, "Reset Session", function()
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
  footer:SetText("Tip: middle-click the minimap button to open the graph.")

  function settingsFrame:Refresh()
    self.controls.enabled:SetChecked(DingTimerDB.enabled)
    self.controls.float:SetChecked(DingTimerDB.float)
    self.controls.floatLocked:SetChecked(DingTimerDB.floatLocked)
    self.controls.graphVisible:SetChecked(DingTimerDB.graphVisible)
    self.controls.graphLocked:SetChecked(DingTimerDB.graphLocked)
    self.controls.minimapHidden:SetChecked(DingTimerDB.minimapHidden)

    local modeText = (DingTimerDB.mode == "ttl") and "TTL only" or "Full output"
    self.controls.modeValue:SetText("Mode: " .. modeText)
    self.controls.windowValue:SetText("Window: " .. NS.fmtTime(DingTimerDB.windowSeconds or 600))

    local scaleMode = NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode)
    self.controls.graphScaleValue:SetText("Scale: " .. NS.GetGraphScaleModeLabel(scaleMode, true))
    self.controls.graphMaxValue:SetText("Fixed max: " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))

    local graphDefaults = NS.GraphWindowDefaults or { width = 660, height = 340 }
    local graphWidth, graphHeight = graphDefaults.width, graphDefaults.height
    if NS.GetGraphWindowSize then
      graphWidth, graphHeight = NS.GetGraphWindowSize()
    end
    self.controls.graphSizeValue:SetText(string.format("Size: %dx%d  |  Zoom: %s", graphWidth, graphHeight, tostring((DingTimerDB.graphWindowSeconds and NS.fmtTime(DingTimerDB.graphWindowSeconds)) or "5m")))
  end

  settingsFrame:SetScript("OnShow", function(self)
    self:Refresh()
  end)

  settingsFrame:Hide()
  tinsert(UISpecialFrames, settingsFrame:GetName())
end

function NS.ToggleSettingsWindow()
  if not settingsFrame then
    NS.InitSettingsWindow()
  end
  if settingsFrame:IsShown() then
    settingsFrame:Hide()
  else
    settingsFrame:Show()
  end
end
