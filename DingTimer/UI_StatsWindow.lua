local ADDON, NS = ...

local statsFrame = nil

local function FormatNumber(num)
  if not num then return "0" end
  if num ~= num or num == math.huge or num == -math.huge then return "0" end
  local formatted = tostring(math.floor(num))
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return formatted
end

local function GetXPData()
  local now = GetTime()
  local window = DingTimerDB.windowSeconds or 600
  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0
  
  local xph = NS.computeXPPerHour(now, window)
  local remaining = maxXP - xp
  local ttl = (xph > 0) and (remaining / (xph / 3600)) or math.huge
  
  return xp, maxXP, xph, ttl
end

local function GetMoneyData()
  local now = GetTime()
  local window = DingTimerDB.windowSeconds or 600
  local mph = NS.computeMoneyPerHour(now, window)
  local sessionMoney = NS.state.sessionMoney or 0
  return sessionMoney, mph
end

local function UpdateValues()
  if not statsFrame or not statsFrame:IsShown() then return end
  
  local now = GetTime()
  local sessionTime = now - (NS.state.sessionStartTime or now)
  statsFrame.valTime:SetText(NS.fmtTime(sessionTime))
  
  local xp, maxXP, xph, ttl = GetXPData()
  statsFrame.valXPH:SetText(FormatNumber(xph) .. " / hr")
  statsFrame.valTTL:SetText(NS.fmtTime(ttl))
  
  -- Use actual session XP tracker (events get pruned)
  local totalSessionXP = NS.state.sessionXP or 0
  statsFrame.valSessionXP:SetText(FormatNumber(totalSessionXP))

  local sessionMoney, mph = GetMoneyData()
  statsFrame.valSessionMoney:SetText(NS.fmtMoney(sessionMoney))
  statsFrame.valMoneyPH:SetText(NS.fmtMoney(math.floor(mph)) .. " / hr")
end

function NS.InitStatsWindow()
  if statsFrame then return end

  statsFrame = CreateFrame("Frame", "DingTimerStatsWindow", UIParent, "BackdropTemplate")
  statsFrame:SetSize(300, 240)
  statsFrame:SetPoint("CENTER")
  
  -- Elegant dark theme
  statsFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  statsFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  statsFrame:SetBackdropBorderColor(0.2, 0.6, 0.8, 1) -- matching base color
  
  statsFrame:SetMovable(true)
  statsFrame:EnableMouse(true)
  statsFrame:RegisterForDrag("LeftButton")
  statsFrame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then return end
    self:StartMoving()
  end)
  statsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    DingTimerDB.uiWindowPosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
  end)
  
  if DingTimerDB.uiWindowPosition then
    local pos = DingTimerDB.uiWindowPosition
    statsFrame:ClearAllPoints()
    statsFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
  else
    statsFrame:SetPoint("CENTER")
  end
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, statsFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)
  
  -- Header
  local header = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOP", 0, -12)
  header:SetText(NS.C.base .. "DingTimer Stats" .. NS.C.r)
  
  -- Separator
  local tex = statsFrame:CreateTexture(nil, "ARTWORK")
  tex:SetColorTexture(0.2, 0.6, 0.8, 0.5)
  tex:SetSize(280, 1)
  tex:SetPoint("TOP", 0, -35)

  local function CreateRow(yOffset, labelText)
    local label = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 15, yOffset)
    label:SetText(labelText)
    
    local val = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPRIGHT", -15, yOffset)
    val:SetJustifyH("RIGHT")
    val:SetText("-")
    
    return val
  end

  local yStart = -50
  local rowHeight = -25

  statsFrame.valTime = CreateRow(yStart, "Session Time:")
  statsFrame.valSessionXP = CreateRow(yStart + rowHeight, "Session XP:")
  statsFrame.valXPH = CreateRow(yStart + rowHeight * 2, "XP Per Hour:")
  statsFrame.valTTL = CreateRow(yStart + rowHeight * 3, "Time To Level:")
  
  -- Section Separator
  local tex2 = statsFrame:CreateTexture(nil, "ARTWORK")
  tex2:SetColorTexture(0.5, 0.5, 0.5, 0.3)
  tex2:SetSize(260, 1)
  tex2:SetPoint("TOP", 0, yStart + rowHeight * 4 + 8)

  statsFrame.valSessionMoney = CreateRow(yStart + rowHeight * 4, "Session Money:")
  statsFrame.valMoneyPH = CreateRow(yStart + rowHeight * 5, "Money Per Hour:")

  -- Footer Hint
  local footer = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOM", 0, 10)
  footer:SetText("Updates automatically. /ding ui to close.")

  -- Allow closing with Escape key
  tinsert(UISpecialFrames, statsFrame:GetName())

  statsFrame:Hide()
  
  NS.ManageFrameTicker(statsFrame, 1, UpdateValues, "uiWindowVisible")
end

function NS.ToggleStatsWindow()
  if not statsFrame then
    NS.InitStatsWindow()
  end
  
  if statsFrame:IsShown() then
    statsFrame:Hide()
  else
    statsFrame:Show()
  end
end

function NS.RefreshStatsWindow()
  if statsFrame and statsFrame:IsShown() then
    UpdateValues()
  end
end
