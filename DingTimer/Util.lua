local ADDON, NS = ...

NS.C = {
  base = "|cff3fc7eb",   -- bluish
  xp   = "|cff00ff00",   -- green
  val  = "|cffffff00",   -- yellow
  bad  = "|cffff4040",   -- red
  mid  = "|cffaaaaaa",   -- gray
  r    = "|r",
}

function NS.FormatNumber(num)
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

function NS.chat(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  else
    print(msg)
  end
end

function NS.fmtTime(seconds)
  if not seconds or seconds <= 0 or seconds == math.huge then return "??" end
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
  if not copper or copper == 0 then return "0|cffeda55fc|r" end
  local isNegative = copper < 0
  copper = math.abs(copper)

  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local str = ""
  if g > 0 then str = str .. g .. "|cffffd700g|r " end
  if s > 0 or g > 0 then str = str .. s .. "|cffc7c7cfs|r " end
  str = str .. c .. "|cffeda55fc|r"
  str = str:match("^%s*(.-)%s*$")
  
  if isNegative then
    return "|cffff4040-|r" .. str
  end
  return str
end

function NS.ttlColor(ttl, lastTTL)
  if not lastTTL or lastTTL == math.huge then return NS.C.val end

  -- If TTL went down => improved => green. Up => red.
  -- Use a small dead-zone to avoid flicker on tiny changes.
  local diff = ttl - lastTTL
  if math.abs(diff) < 2 then
    return NS.C.mid
  end
  return (diff < 0) and NS.C.xp or NS.C.bad
end

function NS.ttlDeltaText(ttl, lastTTL)
  if not ttl or ttl == math.huge or not lastTTL or lastTTL == math.huge then
    return ""
  end
  local diff = math.floor((ttl - lastTTL) + 0.5)
  if math.abs(diff) < 2 then return "" end
  if diff < 0 then
    -- ↓ (using character codes for reliability)
    return string.format(" (%s %s)", "\226\134\147", NS.fmtTime(-diff))
  else
    -- ↑
    return string.format(" (%s %s)", "\226\134\145", NS.fmtTime(diff))
  end
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
end
