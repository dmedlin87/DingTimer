local _, NS = ...

---@class DingTimerHUDPopup: Frame
---@field ClearAllPoints fun(self: DingTimerHUDPopup)
---@field SetPoint fun(self: DingTimerHUDPopup, point: string, relativeTo: any, relativePoint: string, xOfs: number, yOfs: number)
---@field SetSize fun(self: DingTimerHUDPopup, width: number, height: number)
---@field EnableMouse fun(self: DingTimerHUDPopup, enabled: boolean)
---@field SetClampedToScreen fun(self: DingTimerHUDPopup, clamped: boolean)
---@field SetScript fun(self: DingTimerHUDPopup, scriptName: string, handler: function)
---@field GetName fun(self: DingTimerHUDPopup): string
---@field Refresh fun(self: DingTimerHUDPopup)
---@field Show fun(self: DingTimerHUDPopup)
---@field Hide fun(self: DingTimerHUDPopup)
---@field IsShown fun(self: DingTimerHUDPopup): boolean
---@field _dingAccent Texture?
---@field _dingGlow Texture?
---@field controls table
---@field labels table

---@type DingTimerHUDPopup?
local popupFrame = nil

local function createCheckbox(parent, x, y, label, callback)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb:SetScript("OnClick", function(self)
    if callback then
      callback(self:GetChecked())
    end
  end)

  local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
  text:SetWidth(180)
  text:SetJustifyH("LEFT")
  text:SetText(label)
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(text, "body")
  end
  cb.text = text
  return cb
end

local function createLabel(parent, x, y, text)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetText(text)
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(label, "subtle")
  end
  return label
end

local function createButton(parent, x, y, width, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 24)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  btn:SetText(label)
  btn:SetScript("OnClick", function()
    if callback then
      callback()
    end
  end)
  if NS.UI and NS.UI.DecorateButton then
    NS.UI.DecorateButton(btn)
  end
  return btn
end

local function createConfirmButton(parent, x, y, width, idleLabel, confirmLabel, callback)
  local state = 0
  local timer = nil
  local btn = createButton(parent, x, y, width, idleLabel)

  local function resetToIdle()
    state = 0
    if timer then
      timer:Cancel()
    end
    timer = nil
    btn:SetText(idleLabel)
  end

  btn.ResetConfirmation = resetToIdle

  btn:SetScript("OnClick", function()
    if state == 0 then
      state = 1
      btn:SetText(confirmLabel)
      if C_Timer and C_Timer.NewTimer then
        timer = C_Timer.NewTimer(3, resetToIdle)
      end
      return
    end

    resetToIdle()
    if callback then
      callback()
    end
  end)

  return btn
end

local function refreshAnchor()
  if not popupFrame then
    return
  end

  local anchor = NS.GetFloatFrame and NS.GetFloatFrame() or nil
  popupFrame:ClearAllPoints()
  if anchor and DingTimerDB and DingTimerDB.float and anchor.IsShown and anchor:IsShown() then
    popupFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -10)
  else
    popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function NS.InitHUDPopup()
  if popupFrame then
    return popupFrame
  end

  local frame = CreateFrame("Frame", "DingTimerHUDPopup", UIParent, "BackdropTemplate") --[[@as DingTimerHUDPopup]]
  popupFrame = frame
  popupFrame:SetSize(248, 228)
  popupFrame:EnableMouse(true)
  popupFrame:SetClampedToScreen(true)
  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(popupFrame, true)
    -- The compact HUD popup does not have a header, so the shared
    -- top accent/glow reads as a stray teal block here.
    if popupFrame._dingAccent and popupFrame._dingAccent.Hide then
      popupFrame._dingAccent:Hide()
    end
    if popupFrame._dingGlow and popupFrame._dingGlow.Hide then
      popupFrame._dingGlow:Hide()
    end
  end

  popupFrame.controls = {}

  popupFrame.controls.float = createCheckbox(popupFrame, 14, -16, "HUD on/off", function(checked)
    if NS.SetFloatEnabled then
      NS.SetFloatEnabled(checked)
    end
  end)
  popupFrame.controls.lock = createCheckbox(popupFrame, 14, -40, "Lock", function(checked)
    if NS.SetFloatLocked then
      NS.SetFloatLocked(checked)
    end
  end)
  popupFrame.controls.floatShowInCombat = createCheckbox(popupFrame, 14, -64, "Show in combat", function(checked)
    if NS.SetFloatShowInCombat then
      NS.SetFloatShowInCombat(checked)
    end
  end)
  popupFrame.controls.chat = createCheckbox(popupFrame, 14, -88, "Chat on/off", function(checked)
    if NS.SetChatOutputEnabled then
      NS.SetChatOutputEnabled(checked)
    end
  end)
  popupFrame.controls.dingSoundEnabled = createCheckbox(popupFrame, 14, -112, "Level-up sound", function(checked)
    if NS.SetDingSoundEnabled then
      NS.SetDingSoundEnabled(checked)
    end
  end)

  popupFrame.labels = {}
  popupFrame.labels.mode = createLabel(popupFrame, 14, -142, "Chat mode")
  popupFrame.controls.modeFull = createButton(popupFrame, 86, -136, 56, "Full", function()
    if NS.SetOutputMode then
      NS.SetOutputMode("full")
    end
  end)
  popupFrame.controls.modeTTL = createButton(popupFrame, 148, -136, 56, "TTL", function()
    if NS.SetOutputMode then
      NS.SetOutputMode("ttl")
    end
  end)

  popupFrame.labels.window = createLabel(popupFrame, 14, -172, "Window")
  popupFrame.controls.window1m = createButton(popupFrame, 72, -166, 36, "1m", function()
    NS.SetRollingWindowSeconds(60)
  end)
  popupFrame.controls.window5m = createButton(popupFrame, 112, -166, 36, "5m", function()
    NS.SetRollingWindowSeconds(300)
  end)
  popupFrame.controls.window10m = createButton(popupFrame, 152, -166, 44, "10m", function()
    NS.SetRollingWindowSeconds(600)
  end)
  popupFrame.controls.window15m = createButton(popupFrame, 198, -166, 44, "15m", function()
    NS.SetRollingWindowSeconds(900)
  end)

  popupFrame.controls.reset = createConfirmButton(popupFrame, 14, -198, 228, "Reset session", "|cffff4040Confirm reset|r", function()
    if NS.ResetSession then
      NS.ResetSession("MANUAL_RESET")
    end
  end)

  function popupFrame:Refresh()
    refreshAnchor()

    self.controls.float:SetChecked(DingTimerDB and DingTimerDB.float == true)
    self.controls.lock:SetChecked(DingTimerDB == nil or DingTimerDB.floatLocked ~= false)
    self.controls.floatShowInCombat:SetChecked(DingTimerDB and DingTimerDB.floatShowInCombat == true)
    self.controls.chat:SetChecked(DingTimerDB == nil or DingTimerDB.enabled == true)
    self.controls.dingSoundEnabled:SetChecked(DingTimerDB == nil or DingTimerDB.dingSoundEnabled == true)

    if NS.UI and NS.UI.SetButtonActive then
      NS.UI.SetButtonActive(self.controls.modeFull, (DingTimerDB and DingTimerDB.mode or "full") == "full")
      NS.UI.SetButtonActive(self.controls.modeTTL, (DingTimerDB and DingTimerDB.mode or "full") == "ttl")

      local window = tonumber(DingTimerDB and DingTimerDB.windowSeconds) or 600
      NS.UI.SetButtonActive(self.controls.window1m, window == 60)
      NS.UI.SetButtonActive(self.controls.window5m, window == 300)
      NS.UI.SetButtonActive(self.controls.window10m, window == 600)
      NS.UI.SetButtonActive(self.controls.window15m, window == 900)
    end
  end

  popupFrame:SetScript("OnShow", function(self)
    self:Refresh()
  end)

  popupFrame:SetScript("OnHide", function(self)
    if self.controls and self.controls.reset and self.controls.reset.ResetConfirmation then
      self.controls.reset:ResetConfirmation()
    end
  end)

  tinsert(UISpecialFrames, popupFrame:GetName())
  popupFrame:Hide()
  return popupFrame
end

function NS.GetHUDPopup()
  return popupFrame
end

function NS.IsHUDPopupShown()
  return popupFrame and popupFrame:IsShown() or false
end

function NS.ShowHUDPopup()
  if not popupFrame then
    NS.InitHUDPopup()
  end
  local frame = popupFrame
  if not frame then
    return false
  end
  frame:Refresh()
  frame:Show()
  return true
end

function NS.HideHUDPopup()
  if popupFrame and popupFrame:IsShown() then
    popupFrame:Hide()
    return true
  end
  return false
end

function NS.ToggleHUDPopup()
  if NS.IsHUDPopupShown() then
    return NS.HideHUDPopup()
  end
  return NS.ShowHUDPopup()
end

function NS.RefreshHUDPopup()
  if popupFrame then
    popupFrame:Refresh()
  end
end
