local _, NS = ...

local f = CreateFrame("Button", "DingTimerMinimapButton", Minimap)
f:SetSize(32, 32)
f:SetFrameStrata("MEDIUM")
f:SetFrameLevel(8)

-- === Minimap Button Design ================================================
-- Dark charcoal disc as the base canvas
local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface/Minimap/UI-Minimap-Background")
bg:SetSize(32, 32)
bg:SetPoint("TOPLEFT")
bg:SetVertexColor(0.08, 0.06, 0.03, 1)         -- near-black warm brown

-- Faint amber/XP-bar glow layer (same gold WoW uses for the XP bar)
local glow = f:CreateTexture(nil, "BACKGROUND")
glow:SetTexture("Interface/Minimap/MiniMap-TrackingHighlight")
glow:SetSize(32, 32)
glow:SetPoint("TOPLEFT")
glow:SetVertexColor(1, 0.76, 0.1, 0.25)        -- faint amber halo

-- Bold "DT" monogram in XP-bar gold
local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
label:SetPoint("CENTER", f, "CENTER", 0, 0)
label:SetText("DT")
label:SetTextColor(1, 0.82, 0.1)               -- XP-bar gold

-- Thin accent bar below the letters for a badge feel
local bar = f:CreateTexture(nil, "ARTWORK")
bar:SetTexture("Interface/Buttons/WHITE8X8")     -- solid white pixel, tinted below
bar:SetVertexColor(1, 0.76, 0.1, 0.9)            -- XP-bar gold
bar:SetSize(14, 1)
bar:SetPoint("TOP", label, "BOTTOM", 0, -1)

-- Standard circular minimap tracking border (drawn on top)
local border = f:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetVertexColor(1, 0.88, 0.5, 1)         -- warm gold tint on the ring

f:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
-- =========================================================================

f:RegisterForClicks("AnyUp")
f:RegisterForDrag("LeftButton")

local minimapShapes = {
  ["ROUND"]                = {true, true, true, true},
  ["SQUARE"]               = {false, false, false, false},
  ["CORNER-TOPLEFT"]       = {false, false, false, false},
  ["CORNER-TOPRIGHT"]      = {false, false, false, false},
  ["CORNER-BOTTOMLEFT"]    = {false, false, false, false},
  ["CORNER-BOTTOMRIGHT"]   = {false, false, false, false},
  ["SIDE-LEFT"]            = {false, true, false, true},
  ["SIDE-RIGHT"]           = {true, false, true, false},
  ["SIDE-TOP"]             = {false, false, true, true},
  ["SIDE-BOTTOM"]          = {true, true, false, false},
  ["TRICORNER-TOPLEFT"]    = {false, true, true, true},
  ["TRICORNER-TOPRIGHT"]   = {true, false, true, true},
  ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
  ["TRICORNER-BOTTOMRIGHT"]= {true, true, true, false},
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
    DingTimerDB.minimapAngle = math.deg(atan2(py - cy, px - cx))
    UpdatePosition()
  end)
end)

f:SetScript("OnDragStop", function()
  f:SetScript("OnUpdate", nil)
end)

-- Left: Live tab | Right: Analysis tab | Middle: Settings tab
f:SetScript("OnClick", function(_, button)
  if button == "LeftButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(1) end
  elseif button == "RightButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(2) end
  elseif button == "MiddleButton" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(4) end
  end
end)

f:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(NS.C.base .. "DingTimer" .. NS.C.r)
  GameTooltip:AddLine("Left-click to toggle the Live tab",      1, 1, 1)
  GameTooltip:AddLine("Right-click to toggle the Analysis tab",  1, 1, 1)
  GameTooltip:AddLine("Middle-click to toggle Settings",         1, 1, 1)
  GameTooltip:AddLine("Drag to move this button",                0.7, 0.7, 0.7)
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
