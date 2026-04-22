local _, NS = ...

-- ⚡ Localize frequently-used globals to avoid repeated table lookups in hot paths
local math_floor = math.floor
local math_abs = math.abs
local math_huge = math.huge
local math_ceil = math.ceil
local string_format = string.format
local tostring = tostring
local tonumber = tonumber

NS.C = {
  base = "|cff3fc7eb",   -- bluish
  xp   = "|cff00ff00",   -- green
  val  = "|cffffff00",   -- yellow
  bad  = "|cffff4040",   -- red
  mid  = "|cffaaaaaa",   -- gray
  r    = "|r",
}

NS.UI = NS.UI or {}

-- Named RGBA color palette for frame painting.
NS.Colors = {
  -- Primary accent (signature DingTimer teal-blue)
  accent         = { 0.24, 0.78, 0.92 },
  accentActive   = { 0.34, 0.88, 1.0 },
  accentSoft     = { 0.17, 0.40, 0.52 },

  -- Frame chrome
  borderDefault  = { 0.2, 0.6, 0.8 },
  borderMuted    = { 0.3, 0.3, 0.3 },
  bgSolid        = { 0.05, 0.05, 0.05 },
  bgPanel        = { 0.04, 0.06, 0.08 },
  fillButton     = { 0.06, 0.08, 0.10 },
  fillBtnActive  = { 0.08, 0.13, 0.17 },
}

function NS.UI.ApplyTextStyle(fs, style)
  if not fs then
    return
  end

  local fontObject = "GameFontHighlightSmall"
  local shadowX, shadowY = 1, -1
  local shadowA = 0.65

  if style == "title" then
    fontObject = "GameFontHighlightLarge"
    shadowA = 0.85
  elseif style == "heading" then
    fontObject = "GameFontNormal"
    shadowA = 0.75
  elseif style == "label" then
    fontObject = "GameFontHighlightSmall"
    shadowA = 0.6
  elseif style == "value" then
    fontObject = "GameFontHighlight"
    shadowA = 0.85
  elseif style == "subtle" then
    fontObject = "GameFontDisableSmall"
    shadowA = 0.4
  elseif style == "body" then
    fontObject = "GameFontHighlightSmall"
    shadowA = 0.55
  elseif style == "eyebrow" then
    fontObject = "GameFontNormalSmall"
    shadowA = 0.5
  end

  if fs.SetFontObject then
    fs:SetFontObject(fontObject)
  end
  if fs.SetShadowOffset then
    fs:SetShadowOffset(shadowX, shadowY)
  end
  if fs.SetShadowColor then
    fs:SetShadowColor(0, 0, 0, shadowA)
  end
  if fs.SetJustifyH then
    fs:SetJustifyH("LEFT")
  end
end

function NS.UI.DecorateButton(btn)
  if not btn or btn._dingStyled then
    return btn
  end

  local fill = btn:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(btn)
  fill:SetColorTexture(NS.Colors.fillButton[1], NS.Colors.fillButton[2], NS.Colors.fillButton[3], 0.7)
  btn._dingFill = fill

  local accent = btn:CreateTexture(nil, "ARTWORK")
  accent:SetHeight(3)
  accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 6, 4)
  accent:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 4)
  accent:SetColorTexture(NS.Colors.accent[1], NS.Colors.accent[2], NS.Colors.accent[3], 0.65)
  btn._dingAccent = accent
  btn._dingStyled = true
  return btn
end

function NS.UI.SetButtonActive(btn, active)
  if not btn then
    return
  end
  if not btn._dingStyled then
    NS.UI.DecorateButton(btn)
  end

  if active then
    if btn._dingFill then
      btn._dingFill:SetColorTexture(NS.Colors.fillBtnActive[1], NS.Colors.fillBtnActive[2], NS.Colors.fillBtnActive[3], 0.96)
    end
    if btn._dingAccent then
      btn._dingAccent:SetColorTexture(NS.Colors.accentActive[1], NS.Colors.accentActive[2], NS.Colors.accentActive[3], 0.98)
    end
  else
    if btn._dingFill then
      btn._dingFill:SetColorTexture(NS.Colors.fillButton[1], NS.Colors.fillButton[2], NS.Colors.fillButton[3], 0.7)
    end
    if btn._dingAccent then
      btn._dingAccent:SetColorTexture(NS.Colors.accent[1], NS.Colors.accent[2], NS.Colors.accent[3], 0.45)
    end
  end
end

function NS.IsInvalidNumber(n)
  return n ~= n or n == math_huge or n == -math_huge
end

function NS.FormatNumber(num)
  if not num then return "0" end
  if NS.IsInvalidNumber(num) then return "0" end
  local n = math_floor(num)
  if n >= -999 and n <= 999 then
    return tostring(n)
  end
  local neg = ""
  if n < 0 then
    neg = "-"
    n = -n
  end
  -- ⚡ Build comma-separated string with integer math instead of reverse/gsub/reverse
  local parts = {}
  local count = 0
  while n >= 1000 do
    count = count + 1
    parts[count] = string_format("%03d", n % 1000)
    n = math_floor(n / 1000)
  end
  count = count + 1
  parts[count] = tostring(n)
  -- Reverse the parts array in-place
  local lo, hi = 1, count
  while lo < hi do
    parts[lo], parts[hi] = parts[hi], parts[lo]
    lo = lo + 1
    hi = hi - 1
  end
  return neg .. table.concat(parts, ",")
end

function NS.chat(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  else
    print(msg)
  end
end

function NS.fmtTime(seconds)
  -- 🛡️ Sentinel: Validate numeric inputs to prevent NaN/Infinity from crashing UI logic (DoS risk)
  if not seconds or NS.IsInvalidNumber(seconds) or seconds <= 0 then return "??" end
  local s = math_floor(seconds + 0.5)
  if s < 120 then
    return string_format("%ds", s)
  end
  local h = math_floor(s / 3600); s = s % 3600
  local m = math_floor(s / 60);   s = s % 60
  if h > 0 then return string_format("%dh %dm", h, m) end
  return string_format("%dm %ds", m, s)
end

function NS.fmtMoney(copper)
  if not copper or copper == 0 or NS.IsInvalidNumber(copper) then return "0|cffeda55fc|r" end
  local isNegative = copper < 0
  copper = math_abs(copper)

  local g = math_floor(copper / 10000)
  local s = math_floor((copper % 10000) / 100)
  local c = copper % 100

  -- ⚡ Bolt: Use direct string formatting instead of sequential concatenation
  -- and regex trimming (str:match). This results in a ~4x performance speedup.
  local str
  if g > 0 then
    str = string_format("%d|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", g, s, c)
  elseif s > 0 then
    str = string_format("%d|cffc7c7cfs|r %d|cffeda55fc|r", s, c)
  else
    str = string_format("%d|cffeda55fc|r", c)
  end
  
  if isNegative then
    return "|cffff4040-|r" .. str
  end
  return str
end

function NS.ttlColor(ttl, lastTTL)
  if not ttl or NS.IsInvalidNumber(ttl) or not lastTTL or NS.IsInvalidNumber(lastTTL) then return NS.C.val end

  -- If TTL went down => improved => green. Up => red.
  -- Use a small dead-zone to avoid flicker on tiny changes.
  local diff = ttl - lastTTL
  if math_abs(diff) < 2 then
    return NS.C.mid
  end
  return (diff < 0) and NS.C.xp or NS.C.bad
end

function NS.ttlDeltaText(ttl, lastTTL)
  if not ttl or NS.IsInvalidNumber(ttl) or not lastTTL or NS.IsInvalidNumber(lastTTL) then
    return ""
  end
  local diff = ttl - lastTTL
  if math_abs(diff) < 2 then return "" end

  local seconds = math_floor(math_abs(diff) + 0.5)
  if diff < 0 then
    -- ↓ (using character codes for reliability)
    return string_format(" (%s %s)", "\226\134\147", NS.fmtTime(seconds))
  else
    -- ↑
    return string_format(" (%s %s)", "\226\134\145", NS.fmtTime(seconds))
  end
end

function NS.Round(value)
  local n = tonumber(value) or 0
  if n >= 0 then
    return math_floor(n + 0.5)
  end
  return math_ceil(n - 0.5)
end

function NS.ApplyThemeToFrame(frame, isTransparent)
  frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  if isTransparent then
    frame:SetBackdropColor(0, 0, 0, 0.6)
    frame:SetBackdropBorderColor(NS.Colors.borderMuted[1], NS.Colors.borderMuted[2], NS.Colors.borderMuted[3], 0.8)
  else
    frame:SetBackdropColor(NS.Colors.bgSolid[1], NS.Colors.bgSolid[2], NS.Colors.bgSolid[3], 0.95)
    frame:SetBackdropBorderColor(NS.Colors.borderDefault[1], NS.Colors.borderDefault[2], NS.Colors.borderDefault[3], 1)
  end

  if not frame._dingInnerFill then
    local innerFill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    innerFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    innerFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame._dingInnerFill = innerFill
  end
  frame._dingInnerFill:SetColorTexture(
    NS.Colors.bgPanel[1],
    NS.Colors.bgPanel[2],
    NS.Colors.bgPanel[3],
    isTransparent and 0.32 or 0.72
  )

  if not frame._dingAccent then
    local accent = frame:CreateTexture(nil, "BORDER")
    accent:SetHeight(3)
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    accent:SetColorTexture(NS.Colors.accent[1], NS.Colors.accent[2], NS.Colors.accent[3], isTransparent and 0.4 or 0.85)
    frame._dingAccent = accent
  end

  if not frame._dingGlow then
    local glow = frame:CreateTexture(nil, "BORDER", nil, -6)
    glow:SetHeight(18)
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -9)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -9)
    frame._dingGlow = glow
  end
  frame._dingGlow:SetColorTexture(
    NS.Colors.accentSoft[1],
    NS.Colors.accentSoft[2],
    NS.Colors.accentSoft[3],
    isTransparent and 0.18 or 0.34
  )
end
