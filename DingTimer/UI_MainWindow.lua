local ADDON, NS = ...

local MAIN_WIDTH = 660
local MAIN_HEIGHT = 500

local mainWindow = nil
local tabs = {}
local panels = {}

-- This allows us to hook into the creation of the panels later
NS.UIPanels = {}

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
  btn:SetSize(100, 24)
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

  local contentArea = CreateFrame("Frame", "DingTimerMainContent", mainWindow)
  contentArea:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, -40)
  contentArea:SetPoint("BOTTOMRIGHT", mainWindow, "BOTTOMRIGHT", -10, 10)
  mainWindow.contentArea = contentArea

  -- Create Tabs
  tabs[1] = createTabButton(contentArea, 1, "Dashboard", 0, 2)
  tabs[2] = createTabButton(contentArea, 2, "Graph", 102, 2)
  tabs[3] = createTabButton(contentArea, 3, "Insights", 204, 2)
  tabs[4] = createTabButton(contentArea, 4, "Settings", 306, 2)

  -- Initialize panels (these will attach to contentArea)
  if NS.InitStatsPanel then panels[1] = NS.InitStatsPanel(contentArea) end
  if NS.InitGraphPanel then panels[2] = NS.InitGraphPanel(contentArea) end
  if NS.InitInsightsPanel then panels[3] = NS.InitInsightsPanel(contentArea) end
  if NS.InitSettingsPanel then panels[4] = NS.InitSettingsPanel(contentArea) end

  mainWindow:SetScript("OnShow", function()
    DingTimerDB.mainWindowVisible = true
  end)
  mainWindow:SetScript("OnHide", function()
    DingTimerDB.mainWindowVisible = false
  end)

  tinsert(UISpecialFrames, mainWindow:GetName())
  mainWindow:Hide()
end

function NS.SelectTab(id)
  if not mainWindow then NS.InitMainWindow() end
  
  -- Update button states
  for i, tab in pairs(tabs) do
    if i == id then
      tab:LockHighlight()
    else
      tab:UnlockHighlight()
    end
  end

  -- Show selected panel, hide others
  for i, panel in pairs(panels) do
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
  ---@diagnostic disable-next-line: need-check-nil
  if not mainWindow:IsShown() then
    ---@diagnostic disable-next-line: need-check-nil
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
  ---@diagnostic disable-next-line: need-check-nil
  if mainWindow:IsShown() and sameTab then
    return NS.HideMainWindow()
  end

  return NS.ShowMainWindow(activeTabId)
end
