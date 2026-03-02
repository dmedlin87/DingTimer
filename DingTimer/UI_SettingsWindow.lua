local ADDON, NS = ...

local settingsFrame = nil

function NS.InitSettingsWindow()
  if settingsFrame then return end

  settingsFrame = CreateFrame("Frame", "DingTimerSettingsWindow", UIParent, "BackdropTemplate")
  settingsFrame:SetSize(300, 320)
  settingsFrame:SetPoint("CENTER")
  
  settingsFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  settingsFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  settingsFrame:SetBackdropBorderColor(0.2, 0.6, 0.8, 1)
  
  settingsFrame:SetMovable(true)
  settingsFrame:EnableMouse(true)
  settingsFrame:RegisterForDrag("LeftButton")
  settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  
  local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  
  local header = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOP", 0, -12)
  header:SetText(NS.C.base .. "DingTimer Settings" .. NS.C.r)
  
  local sep = settingsFrame:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(0.2, 0.6, 0.8, 0.5)
  sep:SetSize(280, 1)
  sep:SetPoint("TOP", 0, -35)

  local function CreateCheckbox(y, label, dbKey, callback)
    local cb = CreateFrame("CheckButton", nil, settingsFrame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, y)
    cb:SetScript("OnShow", function(self) self:SetChecked(DingTimerDB[dbKey]) end)
    cb:SetScript("OnClick", function(self)
      DingTimerDB[dbKey] = self:GetChecked()
      if callback then callback(self:GetChecked()) end
    end)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    text:SetText(label)
    return cb
  end

  local function CreateButton(y, label, callback)
    local btn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    btn:SetSize(140, 25)
    btn:SetPoint("TOP", 0, y)
    btn:SetText(label)
    btn:SetScript("OnClick", callback)
    return btn
  end

  CreateCheckbox(-50, "Enable Chat Output", "enabled")
  CreateCheckbox(-80, "Show Floating Text", "float", function(checked) NS.setFloatVisible(checked) end)
  CreateCheckbox(-110, "Lock Floating Text", "floatLocked")
  CreateCheckbox(-140, "Show XP Graph", "graphVisible", function(checked) NS.SetGraphVisible(checked) end)
  CreateCheckbox(-170, "Hide Minimap Button", "minimapHidden", function(checked) 
    if DingTimerMinimapButton then
      if checked then DingTimerMinimapButton:Hide() else DingTimerMinimapButton:Show() end 
    end
  end)

  CreateButton(-220, "Reset Session", function()
    NS.resetXPState()
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Session reset.")
  end)

  settingsFrame:Hide()
end

function NS.ToggleSettingsWindow()
  if not settingsFrame then NS.InitSettingsWindow() end
  if settingsFrame:IsShown() then
    settingsFrame:Hide()
  else
    settingsFrame:Show()
  end
end