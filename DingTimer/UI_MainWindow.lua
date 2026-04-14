local _, NS = ...

local MAIN_WIDTH = (NS.MainWindowDefaults and NS.MainWindowDefaults.width) or 720
local MAIN_HEIGHT = (NS.MainWindowDefaults and NS.MainWindowDefaults.height) or 540

local mainWindow = nil
local tabs = {}
local panels = {}
local TAB_META = {
  [1] = {
    label = "Live",
    description = "Live pacing, coach status, recap, and quick actions.",
    hint = "Best for checking the current run at a glance.",
  },
  [2] = {
    label = "Analysis",
    description = "Rolling graph, scale controls, and recent segment history.",
    hint = "Use zoom and scale controls to inspect pace swings.",
  },
  [3] = {
    label = "History",
    description = "Recent leveling or PvP session history with trend context.",
    hint = "Switch between leveling and PvP history from the footer toggle.",
  },
  [4] = {
    label = "Settings",
    description = "Output, HUD, graph, coach, PvP, and maintenance controls.",
    hint = "Use this hub to tune visibility, graph scale, and retention.",
  },
}

local function getActiveTabId(tabId)
  if tabId then
    return tabId
  end
  if DingTimerDB and DingTimerDB.lastOpenTab then
    return DingTimerDB.lastOpenTab
  end
  return 1
end

local function saveMainWindowPosition(frame)
  local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
  DingTimerDB.mainWindowPosition = {
    point = point,
    relativePoint = relativePoint,
    xOfs = xOfs,
    yOfs = yOfs,
  }
end

local function saveMainWindowSize(frame)
  local width, height = NS.ClampMainWindowSize(frame:GetWidth(), frame:GetHeight())
  DingTimerDB.mainWindowSize = {
    width = width,
    height = height,
  }
end

local function restoreMainWindowPosition(frame)
  local pos = DingTimerDB and DingTimerDB.mainWindowPosition
  frame:ClearAllPoints()
  if pos and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or 0, pos.yOfs or 0)
    return
  end
  frame:SetPoint("CENTER")
end

local function restoreMainWindowSize(frame)
  local size = DingTimerDB and DingTimerDB.mainWindowSize
  local width, height = MAIN_WIDTH, MAIN_HEIGHT
  if size and size.width and size.height then
    width, height = NS.ClampMainWindowSize(size.width, size.height)
  end
  frame:SetSize(width, height)
end

local function createTabButton(parent, id, text, x, y)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(102, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", x, y)
  btn:SetText(text)
  if NS.UI and NS.UI.DecorateButton then
    NS.UI.DecorateButton(btn)
  end
  
  btn:SetScript("OnClick", function()
    NS.SelectTab(id)
  end)

  local meta = TAB_META[id]
  btn:SetScript("OnEnter", function(self)
    if meta then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(meta.label, 1, 1, 1)
      GameTooltip:AddLine(meta.description, 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  
  return btn
end

local function refreshSubtitle()
  if not mainWindow or not mainWindow.subtitle then
    return
  end
  if NS.IsPvpMode and NS.IsPvpMode() then
    local goal = NS.GetPvpGoalLabel and NS.GetPvpGoalLabel() or "Cap"
    mainWindow.subtitle:SetText("PvP Mode  |  Goal: " .. tostring(goal))
    if mainWindow.modePill and NS.UI and NS.UI.SetPill then
      NS.UI.SetPill(mainWindow.modePill, "PvP Active", "warn")
    end
    return
  end
  local coachGoal = DingTimerDB and DingTimerDB.coach and DingTimerDB.coach.goal or "ding"
  mainWindow.subtitle:SetText("Session Coach  |  Goal: " .. tostring(coachGoal))
  if mainWindow.modePill and NS.UI and NS.UI.SetPill then
    NS.UI.SetPill(mainWindow.modePill, "Leveling", "good")
  end
end

NS.RefreshMainWindowSubtitle = refreshSubtitle

local function refreshActiveTabMeta(tabId)
  if not mainWindow then
    return
  end

  local meta = TAB_META[tabId] or TAB_META[1]
  if mainWindow.activeTabPill and NS.UI and NS.UI.SetPill then
    NS.UI.SetPill(mainWindow.activeTabPill, meta.label, "neutral")
  end
  if mainWindow.contextLine then
    mainWindow.contextLine:SetText(meta.description or "")
  end
  if mainWindow.helpLine then
    mainWindow.helpLine:SetText((meta.hint or "") .. "  |  Minimap: Left Live, Right Analysis, Middle Settings")
  end
end

function NS.InitMainWindow()
  if mainWindow then return end

  mainWindow = CreateFrame("Frame", "DingTimerMainWindow", UIParent, "BackdropTemplate")
  restoreMainWindowSize(mainWindow)
  mainWindow:SetMovable(true)
  if mainWindow.SetResizable then
    mainWindow:SetResizable(true)
  end
  if mainWindow.SetResizeBounds then
    local bounds = NS.MainWindowDefaults or {}
    mainWindow:SetResizeBounds(bounds.minWidth or MAIN_WIDTH, bounds.minHeight or MAIN_HEIGHT, bounds.maxWidth or MAIN_WIDTH, bounds.maxHeight or MAIN_HEIGHT)
  else
    if mainWindow.SetMinResize and NS.MainWindowDefaults then
      mainWindow:SetMinResize(NS.MainWindowDefaults.minWidth, NS.MainWindowDefaults.minHeight)
    end
    if mainWindow.SetMaxResize and NS.MainWindowDefaults then
      mainWindow:SetMaxResize(NS.MainWindowDefaults.maxWidth, NS.MainWindowDefaults.maxHeight)
    end
  end
  mainWindow:EnableMouse(true)
  mainWindow:RegisterForDrag("LeftButton")
  mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
  mainWindow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveMainWindowPosition(self)
  end)

  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(mainWindow)
  end
  restoreMainWindowPosition(mainWindow)

  local closeBtn = CreateFrame("Button", nil, mainWindow, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function()
    mainWindow:Hide()
  end)
  closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Close", 1, 1, 1)
    GameTooltip:Show()
  end)
  closeBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local header = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOPLEFT", 14, -12)
  header:SetText(NS.C.base .. "DingTimer" .. NS.C.r)
  mainWindow.header = header

  local subtitle = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  subtitle:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("Session Coach")
  mainWindow.subtitle = subtitle

  if NS.UI and NS.UI.CreatePill then
    local modePill = NS.UI.CreatePill(mainWindow, 0, 0, 96, "Leveling")
    modePill:ClearAllPoints()
    modePill:SetPoint("TOPRIGHT", mainWindow, "TOPRIGHT", -28, -14)
    mainWindow.modePill = modePill

    local activeTabPill = NS.UI.CreatePill(mainWindow, 0, 0, 84, "Live")
    activeTabPill:ClearAllPoints()
    activeTabPill:SetPoint("RIGHT", modePill, "LEFT", -8, 0)
    mainWindow.activeTabPill = activeTabPill
  end

  local contextLine = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  contextLine:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
  contextLine:SetText("")
  mainWindow.contextLine = contextLine

  local helpLine = mainWindow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  helpLine:SetPoint("TOPLEFT", contextLine, "BOTTOMLEFT", 0, -4)
  helpLine:SetText("")
  mainWindow.helpLine = helpLine

  local contentArea = CreateFrame("Frame", "DingTimerMainContent", mainWindow, "BackdropTemplate")
  contentArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, -88)
  contentArea:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -10, 10)
  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(contentArea, true)
  end
  mainWindow.contentArea = contentArea

  -- Create Tabs
  tabs[1] = createTabButton(contentArea, 1, "Live", 0, 2)
  tabs[2] = createTabButton(contentArea, 2, "Analysis", 106, 2)
  tabs[3] = createTabButton(contentArea, 3, "History", 212, 2)
  tabs[4] = createTabButton(contentArea, 4, "Settings", 318, 2)
  mainWindow.tabs = tabs
  mainWindow.panels = panels

  mainWindow:SetScript("OnShow", function()
    DingTimerDB.mainWindowVisible = true
    refreshSubtitle()
    refreshActiveTabMeta(DingTimerDB.lastOpenTab or 1)
  end)
  mainWindow:SetScript("OnHide", function()
    DingTimerDB.mainWindowVisible = false
  end)

  mainWindow:SetScript("OnSizeChanged", function(self, width, height)
    local clampedWidth, clampedHeight = NS.ClampMainWindowSize(width or self:GetWidth(), height or self:GetHeight())
    if self:GetWidth() ~= clampedWidth or self:GetHeight() ~= clampedHeight then
      self:SetSize(clampedWidth, clampedHeight)
      return
    end
    saveMainWindowSize(self)
  end)

  local resizeGrip = CreateFrame("Button", nil, mainWindow)
  resizeGrip:SetSize(18, 18)
  resizeGrip:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -6, 6)
  resizeGrip:EnableMouse(true)
  resizeGrip:SetScript("OnMouseDown", function()
    if mainWindow.StartSizing then
      mainWindow:StartSizing("BOTTOMRIGHT")
    end
  end)
  resizeGrip:SetScript("OnMouseUp", function()
    mainWindow:StopMovingOrSizing()
    saveMainWindowSize(mainWindow)
  end)
  local gripTex = resizeGrip:CreateTexture(nil, "ARTWORK")
  gripTex:SetAllPoints(resizeGrip)
  gripTex:SetColorTexture(0.24, 0.78, 0.92, 0.35)
  mainWindow.resizeGrip = resizeGrip

  tinsert(UISpecialFrames, mainWindow:GetName())
  mainWindow:Hide()
end

local function ensurePanel(id)
  if panels[id] then
    return panels[id]
  end

  local init
  if id == 1 then
    init = NS.InitStatsPanel
  elseif id == 2 then
    init = NS.InitGraphPanel
  elseif id == 3 then
    init = NS.InitInsightsPanel
  elseif id == 4 then
    init = NS.InitSettingsPanel
  end

  local contentArea = mainWindow and mainWindow.contentArea
  if not init or not contentArea then
    return nil
  end

  local ok, panel = pcall(init, contentArea)
  if not ok then
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " panel failed to load: " .. tostring(panel))
    return nil
  end

  panels[id] = panel
  if mainWindow then
    mainWindow.panels = panels
  end
  return panel
end

function NS.SelectTab(id)
  if not mainWindow then NS.InitMainWindow() end
  ensurePanel(id)
  refreshSubtitle()
  refreshActiveTabMeta(id)
  
  -- Update button states
  for i = 1, #tabs do
    local tab = tabs[i]
    if i == id then
      tab:LockHighlight()
      if NS.UI and NS.UI.SetButtonActive then
        NS.UI.SetButtonActive(tab, true)
      end
    else
      tab:UnlockHighlight()
      if NS.UI and NS.UI.SetButtonActive then
        NS.UI.SetButtonActive(tab, false)
      end
    end
  end

  -- Show selected panel, hide others
  for i = 1, 4 do
    local panel = panels[i]
    if panel then
      if i == id then
        panel:Show()
      else
        panel:Hide()
      end
    end
  end
  
  DingTimerDB.lastOpenTab = id
end

function NS.IsMainWindowShown()
  return mainWindow and mainWindow:IsShown() or false
end

function NS.ShowMainWindow(tabId)
  if not mainWindow then
    NS.InitMainWindow()
  end

  NS.SelectTab(getActiveTabId(tabId))
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  if not mainWindow:IsShown() then
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    mainWindow:Show()
  end
  return true
end

function NS.HideMainWindow()
  if mainWindow and mainWindow:IsShown() then
    mainWindow:Hide()
    return true
  end
  return false
end

function NS.ToggleMainWindow(tabId)
  if not mainWindow then
    NS.InitMainWindow()
  end

  local activeTabId = getActiveTabId(tabId)
  local sameTab = (DingTimerDB.lastOpenTab or 1) == activeTabId
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  if mainWindow:IsShown() and sameTab then
    return NS.HideMainWindow()
  end

  return NS.ShowMainWindow(activeTabId)
end
