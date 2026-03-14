local ADDON, NS = ...

local f = CreateFrame("Button", "DingTimerMinimapButton", Minimap)
f:SetSize(32, 32)
f:SetFrameStrata("MEDIUM")
f:SetFrameLevel(8)

local icon = f:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Spell_Holy_Boh") -- Experience icon
icon:SetSize(21, 21)
icon:SetPoint("CENTER", -1, 1)

local border = f:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

f:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

f:RegisterForClicks("AnyUp")
f:RegisterForDrag("LeftButton")

local minimapShapes = {
  ["ROUND"] = {true, true, true, true},
  ["SQUARE"] = {false, false, false, false},
  ["CORNER-TOPLEFT"] = {false, false, false, false},
  ["CORNER-TOPRIGHT"] = {false, false, false, false},
  ["CORNER-BOTTOMLEFT"] = {false, false, false, false},
  ["CORNER-BOTTOMRIGHT"] = {false, false, false, false},
  ["SIDE-LEFT"] = {false, true, false, true},
  ["SIDE-RIGHT"] = {true, false, true, false},
  ["SIDE-TOP"] = {false, false, true, true},
  ["SIDE-BOTTOM"] = {true, true, false, false},
  ["TRICORNER-TOPLEFT"] = {false, true, true, true},
  ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
  ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
  ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function atan2(y, x)
  if math.atan2 then
    return math.atan2(y, x)
  end
  if x == 0 then
    if y > 0 then return math.pi / 2 end
    if y < 0 then return -(math.pi / 2) end
    return 0
  end
  local angle = math.atan(y / x)
  if x < 0 then
    angle = angle + (y >= 0 and math.pi or -math.pi)
  end
  return angle
end

local function UpdatePosition()
  local angle = math.rad(DingTimerDB.minimapAngle or 45)
  local x = math.cos(angle)
  local y = math.sin(angle)
  local q = 1
  
  if x < 0 then q = q + 1 end
  if y > 0 then q = q + 2 end
  
  local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
  local quadTable = minimapShapes[minimapShape]
  local isRound = quadTable and quadTable[q]
  
  -- Base radius off Minimap width, pushed out to sit on the outer rim
  local radius = (Minimap:GetWidth() / 2) + 5
  if not isRound then
    local xdist = x * radius
    local ydist = y * radius
    
    if math.abs(xdist) > radius then x = x * (radius / math.abs(xdist)) end
    if math.abs(ydist) > radius then y = y * (radius / math.abs(ydist)) end
  end
  
  f:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

f:SetScript("OnDragStart", function()
  f:SetScript("OnUpdate", function()
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    
    local angle = math.deg(atan2(py - cy, px - cx))
    DingTimerDB.minimapAngle = angle
    UpdatePosition()
  end)
end)

f:SetScript("OnDragStop", function()
  f:SetScript("OnUpdate", nil)
end)

f:SetScript("OnClick", function(self, button)
  if button == "LeftButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(1) end
  elseif button == "MiddleButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(2) end
  elseif button == "RightButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(4) end
  end
end)

f:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(NS.C.base .. "DingTimer" .. NS.C.r)
  GameTooltip:AddLine("Left-click to toggle the Live tab", 1, 1, 1)
  GameTooltip:AddLine("Middle-click to toggle the Analysis tab", 1, 1, 1)
  GameTooltip:AddLine("Right-click to toggle the Settings tab", 1, 1, 1)
  GameTooltip:AddLine("Drag to move this button", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)

f:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

function NS.InitMinimapButton()
  if DingTimerDB.minimapHidden then
    f:Hide()
  else
    f:Show()
    UpdatePosition()
  end
end
