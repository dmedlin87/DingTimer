local _, NS = ...

local math_abs = math.abs
local string_format = string.format

local HUD_SUB_TEXT_MAX_CHARS = 64
local HUD_IDLE_LABEL_SECONDS = 30

local function formatHUDNumber(value, compact)
  local n = tonumber(value) or 0
  if not compact or math_abs(n) < 100000 then
    return NS.FormatNumber(n)
  end

  local sign = ""
  if n < 0 then
    sign = "-"
    n = math_abs(n)
  end

  if n >= 1000000000 then
    return sign .. string_format("%.1fB", n / 1000000000)
  end
  if n >= 1000000 then
    return sign .. string_format("%.1fM", n / 1000000)
  end
  return sign .. string_format("%.0fK", n / 1000)
end

local function buildHUDPaceText(snapshot, compact)
  local paceParts = {}

  if snapshot.currentXph and snapshot.currentXph > 0 then
    paceParts[#paceParts + 1] = formatHUDNumber(NS.Round(snapshot.currentXph), compact) .. " XP/hr"
  else
    paceParts[#paceParts + 1] = "No XP in " .. NS.fmtTime(snapshot.rollingWindow or 0)
  end

  if snapshot.lastXPGain and snapshot.lastXPGain > 0 then
    local lastGainText = "Last +" .. formatHUDNumber(snapshot.lastXPGain, compact)
    if snapshot.gainsToLevel ~= nil then
      lastGainText = lastGainText .. " (" .. formatHUDNumber(snapshot.gainsToLevel, compact) .. ")"
    end
    paceParts[#paceParts + 1] = lastGainText
  end

  paceParts[#paceParts + 1] = "Need " .. formatHUDNumber(snapshot.remainingXP or 0, compact)
  return table.concat(paceParts, "  |  ")
end

local function buildHUDIdleTitleSuffix(snapshot)
  if snapshot.currentXph
    and snapshot.currentXph > 0
    and snapshot.secondsSinceLastXP
    and snapshot.secondsSinceLastXP >= HUD_IDLE_LABEL_SECONDS
  then
    return " (idle " .. NS.fmtTime(snapshot.secondsSinceLastXP) .. ")"
  end
  return ""
end

function NS.BuildHUDText(snapshot)
  local title = NS.fmtTime(snapshot.ttl) .. " to level" .. buildHUDIdleTitleSuffix(snapshot)
  local sub = buildHUDPaceText(snapshot, false)
  if string.len(sub) > HUD_SUB_TEXT_MAX_CHARS then
    sub = buildHUDPaceText(snapshot, true)
  end
  return title, sub
end
