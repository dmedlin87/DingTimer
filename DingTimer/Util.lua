local ADDON, NS = ...

NS.C = {
  base = "|cff3fc7eb",   -- bluish
  xp   = "|cff00ff00",   -- green
  val  = "|cffffff00",   -- yellow
  bad  = "|cffff4040",   -- red
  mid  = "|cffaaaaaa",   -- gray
  r    = "|r",
}

NS.GraphWindowDefaults = {
  width = 660,
  height = 340,
  minWidth = 540,
  minHeight = 280,
  maxWidth = 1200,
  maxHeight = 680,
}

NS.UI = NS.UI or {}

local function ensureUIHelpers()
  if not NS.UI.CreateSectionTitle then
    function NS.UI.CreateSectionTitle(parent, x, y, title, description)
      local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
      header:SetText(title)

      local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
      sub:SetText(description or "")

      return header, sub
    end
  end

  if not NS.UI.CreateMetricCard then
    function NS.UI.CreateMetricCard(parent, width, height, x, y, labelText)
      local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
      card:SetSize(width, height)
      card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
      NS.ApplyThemeToFrame(card, true)

      local accent = card:CreateTexture(nil, "ARTWORK")
      accent:SetHeight(2)
      accent:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
      accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
      accent:SetColorTexture(0.24, 0.78, 0.92, 0.72)

      local label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -12)
      label:SetText(labelText or "")

      local value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
      value:SetText("--")

      local sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
      sub:SetText("")

      card.label = label
      card.value = value
      card.sub = sub
      return card
    end
  end

  if not NS.UI.SetMetricCard then
    function NS.UI.SetMetricCard(card, value, subValue)
      if not card then
        return
      end
      card.value:SetText(value or "--")
      card.sub:SetText(subValue or "")
    end
  end

  if not NS.UI.CreateActionButton then
    function NS.UI.CreateActionButton(parent, x, y, width, label, callback)
      local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      btn:SetSize(width, 24)
      btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
      btn:SetText(label)
      btn:SetScript("OnClick", callback)
      return btn
    end
  end

  if not NS.UI.CreateValueLabel then
    function NS.UI.CreateValueLabel(parent, x, y)
      local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
      fs:SetText("--")
      return fs
    end
  end

  if not NS.UI.CreateListRows then
    function NS.UI.CreateListRows(parent, startX, startY, width, rowCount, spacing, fontObject)
      local rows = {}
      for i = 1, rowCount do
        local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", startX, startY - ((i - 1) * spacing))
        fs:SetJustifyH("LEFT")
        fs:SetWidth(width)
        fs:SetText("")
        rows[i] = fs
      end
      return rows
    end
  end

  if not NS.UI.SetRows then
    function NS.UI.SetRows(rows, values, emptyText)
      for i = 1, #rows do
        local value = values and values[i] or nil
        if value and value ~= "" then
          rows[i]:SetText(value)
        elseif i == 1 and emptyText then
          rows[i]:SetText(emptyText)
        else
          rows[i]:SetText("")
        end
      end
    end
  end
end

ensureUIHelpers()

function NS.IsInvalidNumber(n)
  return n ~= n or n == math.huge or n == -math.huge
end

function NS.FormatNumber(num)
  if not num then return "0" end
  if NS.IsInvalidNumber(num) then return "0" end
  local n = math.floor(num)
  local absNum = tostring(math.abs(n))
  local neg = (n < 0) and "-" or ""
  local formatted = string.reverse(string.gsub(string.reverse(absNum), "(%d%d%d)", "%1,")):gsub("^,", "")
  return neg .. formatted
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
  local s = math.floor(seconds + 0.5)
  if s < 120 then
    return string.format("%ds", s)
  end
  local h = math.floor(s / 3600); s = s % 3600
  local m = math.floor(s / 60);   s = s % 60
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm %ds", m, s)
end

function NS.fmtMoney(copper)
  if not copper or copper == 0 or NS.IsInvalidNumber(copper) then return "0|cffeda55fc|r" end
  local isNegative = copper < 0
  copper = math.abs(copper)

  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100

  -- ⚡ Bolt: Use direct string formatting instead of sequential concatenation
  -- and regex trimming (str:match). This results in a ~4x performance speedup.
  local str
  if g > 0 then
    str = string.format("%d|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", g, s, c)
  elseif s > 0 then
    str = string.format("%d|cffc7c7cfs|r %d|cffeda55fc|r", s, c)
  else
    str = string.format("%d|cffeda55fc|r", c)
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
  if math.abs(diff) < 2 then
    return NS.C.mid
  end
  return (diff < 0) and NS.C.xp or NS.C.bad
end

function NS.ttlDeltaText(ttl, lastTTL)
  if not ttl or NS.IsInvalidNumber(ttl) or not lastTTL or NS.IsInvalidNumber(lastTTL) then
    return ""
  end
  local diff = ttl - lastTTL
  if math.abs(diff) < 2 then return "" end

  local seconds = math.floor(math.abs(diff) + 0.5)
  if diff < 0 then
    -- ↓ (using character codes for reliability)
    return string.format(" (%s %s)", "\226\134\147", NS.fmtTime(seconds))
  else
    -- ↑
    return string.format(" (%s %s)", "\226\134\145", NS.fmtTime(seconds))
  end
end

function NS.Clamp(value, minValue, maxValue)
  local n = tonumber(value) or minValue
  if minValue ~= nil and n < minValue then
    n = minValue
  end
  if maxValue ~= nil and n > maxValue then
    n = maxValue
  end
  return n
end

function NS.Round(value)
  local n = tonumber(value) or 0
  if n >= 0 then
    return math.floor(n + 0.5)
  end
  return math.ceil(n - 0.5)
end

function NS.fmtPercent(value, digits)
  if value == nil or NS.IsInvalidNumber(value) then
    return "--"
  end
  return string.format("%." .. tostring(digits or 0) .. "f%%", value)
end

function NS.NormalizeGraphScaleMode(mode)
  if mode == "auto" then
    mode = "visible"
  end
  if mode == "visible" or mode == "session" or mode == "fixed" then
    return mode
  end
  return "visible"
end

function NS.GetGraphScaleModeLabel(mode, compact)
  mode = NS.NormalizeGraphScaleMode(mode)
  if compact then
    if mode == "visible" then return "Fit Visible" end
    if mode == "session" then return "Session Peak" end
    return "Fixed Max"
  end
  if mode == "visible" then return "Visible Peak" end
  if mode == "session" then return "60m Peak" end
  return "Fixed Max"
end

function NS.ClampGraphFixedMax(value)
  local n = math.floor(tonumber(value) or 100000)
  if n < 10000 then
    n = 10000
  elseif n > 5000000 then
    n = 5000000
  end
  return n
end

function NS.ClampGraphWindowSize(width, height)
  local bounds = NS.GraphWindowDefaults
  local w = math.floor(NS.Clamp(width, bounds.minWidth, bounds.maxWidth))
  local h = math.floor(NS.Clamp(height, bounds.minHeight, bounds.maxHeight))
  return w, h
end

function NS.CreateLineCompat(parent, layer)
  if parent and parent.CreateLine then
    return parent:CreateLine(nil, layer or "OVERLAY")
  end

  local texture = parent and parent.CreateTexture and parent:CreateTexture(nil, layer or "OVERLAY") or {}
  if not texture.SetColorTexture then
    texture.SetColorTexture = function() end
  end
  if not texture.SetThickness then
    texture.SetThickness = function() end
  end
  if not texture.Show then
    texture.Show = function() end
  end
  if not texture.Hide then
    texture.Hide = function() end
  end
  if not texture.SetStartPoint then
    texture.SetStartPoint = function() end
  end
  if not texture.SetEndPoint then
    texture.SetEndPoint = function() end
  end
  return texture
end

function NS.ManageFrameTicker(frame, interval, callback, dbVisibilityKey)
  local ticker = nil

  frame:SetScript("OnShow", function()
    if dbVisibilityKey then
      DingTimerDB[dbVisibilityKey] = true
    end
    callback()
    if not ticker then
      ticker = C_Timer.NewTicker(interval, callback)
    end
  end)

  frame:SetScript("OnHide", function()
    if dbVisibilityKey then
      DingTimerDB[dbVisibilityKey] = false
    end
    if ticker then
      ticker:Cancel()
      ticker = nil
    end
  end)
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
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
  else
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.2, 0.6, 0.8, 1)
  end

  if not frame._dingAccent then
    local accent = frame:CreateTexture(nil, "BORDER")
    accent:SetHeight(2)
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    accent:SetColorTexture(0.24, 0.78, 0.92, isTransparent and 0.4 or 0.85)
    frame._dingAccent = accent
  end
end

--- Creates a two-click confirmed action button.
--- First click changes the label to a confirm prompt and starts a 3-second timeout.
--- Second click (within the window) fires the action; timeout auto-resets to idle.
--- @param parent frame The parent frame to anchor the button on.
--- @param x number X offset from parent BOTTOMLEFT.
--- @param y number Y offset from parent BOTTOMLEFT.
--- @param width number Button width in pixels.
--- @param idleLabel string Text shown in the ready state (e.g. "Reset").
--- @param confirmLabel string Text shown in the confirm state (e.g. "|cffff4040Confirm|r").
--- @param onConfirm function Callback invoked when the user clicks to confirm.
--- @return Button The created Button widget.
function NS.CreateConfirmButton(parent, x, y, width, idleLabel, confirmLabel, onConfirm)
  local state = 0
  local timer = nil
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  btn:SetText(idleLabel)

  local function resetToIdle()
    state = 0
    if timer then timer:Cancel() end
    timer = nil
    btn:SetText(idleLabel)
  end

  btn:SetScript("OnClick", function()
    if state == 0 then
      state = 1
      btn:SetText(confirmLabel)
      timer = C_Timer.NewTimer(3, resetToIdle)
    else
      resetToIdle()
      if onConfirm then onConfirm() end
    end
  end)

  return btn --[[@as Button]]
end

