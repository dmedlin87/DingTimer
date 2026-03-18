local ADDON, NS = ...

local MAIN_WIDTH = 720
local MAIN_HEIGHT = 540

local mainWindow = nil
local tabs = {}
local panels = {}

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

local function restoreMainWindowPosition(frame)
  local pos = DingTimerDB and DingTimerDB.mainWindowPosition
  frame:ClearAllPoints()
  if pos and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or 0, pos.yOfs or 0)
    return
  end
  frame:SetPoint("CENTER")
end

local function createTabButton(parent, id, text, x, y)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(110, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", x, y)
  btn:SetText(text)
  
  btn:SetScript("OnClick", function()
    NS.SelectTab(id)
  end)
  
  return btn
end

function NS.InitMainWindow()
  if mainWindow then return end

  mainWindow = CreateFrame("Frame", "DingTimerMainWindow", UIParent, "BackdropTemplate")
  mainWindow:SetSize(MAIN_WIDTH, MAIN_HEIGHT)
  mainWindow:SetMovable(true)
  mainWindow:EnableMouse(true)
  mainWindow:RegisterForDrag("LeftButton")
  mainWindow:SetScript("OnDragStart", mainWindow.StartMoving)
  mainWindow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveMainWindowPosition(self)
  end)

  NS.ApplyThemeToFrame(mainWindow)
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

  local contentArea = CreateFrame("Frame", "DingTimerMainContent", mainWindow)
  contentArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, -54)
  contentArea:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -10, 10)
  mainWindow.contentArea = contentArea

  -- Create Tabs
  tabs[1] = createTabButton(contentArea, 1, "Live", 0, 2)
  tabs[2] = createTabButton(contentArea, 2, "Analysis", 112, 2)
  tabs[3] = createTabButton(contentArea, 3, "History", 224, 2)
  tabs[4] = createTabButton(contentArea, 4, "Settings", 336, 2)
  mainWindow.tabs = tabs
  mainWindow.panels = panels

  mainWindow:SetScript("OnShow", function()
    DingTimerDB.mainWindowVisible = true
    if mainWindow.subtitle then
      local coachGoal = DingTimerDB and DingTimerDB.coach and DingTimerDB.coach.goal or "ding"
      mainWindow.subtitle:SetText("Session Coach  |  Goal: " .. tostring(coachGoal))
    end
  end)
  mainWindow:SetScript("OnHide", function()
    DingTimerDB.mainWindowVisible = false
  end)

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
  
  -- Update button states
  for i = 1, #tabs do
    local tab = tabs[i]
    if i == id then
      tab:LockHighlight()
    else
      tab:UnlockHighlight()
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
