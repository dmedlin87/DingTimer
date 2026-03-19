local ADDON, NS = ...

local ROOT_COMMANDS = {}

local function parseWords(msg)
  local trimmed = (msg or ""):lower()
  local cmd, arg = trimmed:match("^(%S+)%s*(.*)$")
  return cmd or "", arg or ""
end

local function parseSubCommand(arg)
  local sub, rest = (arg or ""):match("^(%S*)%s*(.*)$")
  return sub or "", rest or ""
end

local function chat(text)
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " " .. text)
end

local function showHelp()
  NS.chat(NS.C.base .. "=== DingTimer Commands (/ding or /dt) ===" .. NS.C.r)
  NS.chat("  " .. NS.C.val .. "/ding live|ui" .. NS.C.r .. " - Toggle the Live tab")
  NS.chat("  " .. NS.C.val .. "/ding analysis|graph" .. NS.C.r .. " - Open the Analysis tab")
  NS.chat("  " .. NS.C.val .. "/ding history|insights" .. NS.C.r .. " - Open the History tab")
  NS.chat("  " .. NS.C.val .. "/ding settings" .. NS.C.r .. " - Open the Settings tab")
  NS.chat("  " .. NS.C.val .. "/ding goal <off|ding|30m|60m>" .. NS.C.r .. " - Set the coach goal")
  NS.chat("  " .. NS.C.val .. "/ding split" .. NS.C.r .. " - Record a manual checkpoint")
  NS.chat("  " .. NS.C.val .. "/ding recap" .. NS.C.r .. " - Print the latest coach recap")
  NS.chat("  " .. NS.C.val .. "/ding window <seconds>" .. NS.C.r .. " - Set the rolling window")
  NS.chat("  " .. NS.C.val .. "/ding mode full|ttl" .. NS.C.r .. " - Change chat output")
  NS.chat("  " .. NS.C.val .. "/ding float on|off|lock|unlock" .. NS.C.r .. " - Manage the HUD")
  NS.chat("  " .. NS.C.val .. "/ding graph zoom|scale|fit|max" .. NS.C.r .. " - Graph controls")
  NS.chat("  " .. NS.C.val .. "/ding pvp [on|off|goal|auto|recap]" .. NS.C.r .. " - Manage PvP mode")
  NS.chat("  " .. NS.C.val .. "/ding reset" .. NS.C.r .. " - Reset the current session")
end

local function withWindow(tabId, toggle)
  if toggle then
    if NS.ToggleMainWindow then
      NS.ToggleMainWindow(tabId)
    end
  elseif NS.ShowMainWindow then
    NS.ShowMainWindow(tabId)
  end
end

ROOT_COMMANDS[""] = function()
  showHelp()
end

ROOT_COMMANDS.help = showHelp

ROOT_COMMANDS.ui = function()
  withWindow(1, true)
end

ROOT_COMMANDS.live = ROOT_COMMANDS.ui
ROOT_COMMANDS.stats = ROOT_COMMANDS.ui

ROOT_COMMANDS.settings = function()
  withWindow(4, true)
end

ROOT_COMMANDS.on = function()
  DingTimerDB.enabled = true
  chat("chat output enabled.")
end

ROOT_COMMANDS.off = function()
  DingTimerDB.enabled = false
  chat("chat output disabled. (UI still tracks)")
end

ROOT_COMMANDS.reset = function()
  if NS.ResetSession then
    NS.ResetSession("MANUAL_RESET")
  end
  chat("session reset.")
end

ROOT_COMMANDS.goal = function(arg)
  local goal = arg or ""
  if goal == "" then
    local active = (DingTimerDB.coach and DingTimerDB.coach.goal) or "ding"
    chat("coach goal = " .. active)
    return
  end
  if not NS.EnsureCoachConfig then
    chat("coach is unavailable.")
    return
  end
  if NS.SetCoachGoal then
    local ok, result = NS.SetCoachGoal(goal)
    if not ok then
      chat(result)
      return
    end
    chat("coach goal = " .. result)
  end
end

ROOT_COMMANDS.split = function()
  if NS.SplitSession then
    NS.SplitSession("MANUAL_SPLIT")
  end
  chat("manual split recorded.")
  if NS.RefreshStatsWindow then
    NS.RefreshStatsWindow()
  end
end

ROOT_COMMANDS.recap = function()
  if NS.IsPvpMode and NS.IsPvpMode() then
    if NS.ShowPvpRecap then
      NS.ShowPvpRecap()
    else
      chat("No PvP recap is available yet.")
    end
  elseif NS.ShowCoachRecap then
    NS.ShowCoachRecap()
  else
    chat("No recap is available yet.")
  end
end

ROOT_COMMANDS.window = function(arg)
  local n = tonumber(arg)
  if not n then
    chat("Please provide a number (e.g., /ding window 600).")
    return
  end
  if NS.SetRollingWindowSeconds and NS.SetRollingWindowSeconds(n) then
    chat("windowSeconds = " .. math.floor(n))
  else
    chat("window must be between 30 and 86400 seconds (24h).")
  end
end

ROOT_COMMANDS.mode = function(arg)
  if arg == "full" or arg == "ttl" then
    DingTimerDB.mode = arg
    chat("mode = " .. arg)
    return
  end
  chat("Unknown mode. Use 'full' or 'ttl'.")
end

ROOT_COMMANDS.float = function(arg)
  if arg == "on" or arg == "off" then
    DingTimerDB.float = (arg == "on")
    if NS.setFloatVisible then
      NS.setFloatVisible(DingTimerDB.float)
    end
    chat("float = " .. arg)
    return
  end
  if arg == "lock" or arg == "unlock" then
    DingTimerDB.floatLocked = (arg == "lock")
    chat("floatLocked = " .. arg)
    return
  end
  chat("Unknown float command. Use 'on', 'off', 'lock', or 'unlock'.")
end

ROOT_COMMANDS.history = function()
  withWindow(3, true)
end

ROOT_COMMANDS.insights = function(arg)
  local sub, rest = parseSubCommand(arg)
  if sub == "" then
    withWindow(3, true)
    return
  end
  if sub == "clear" then
    if NS.ClearCurrentProfileHistory then
      NS.ClearCurrentProfileHistory()
    end
    chat("history cleared for this character.")
    return
  end
  if sub == "keep" then
    if rest == "" then
      local keep = (DingTimerDB.xp and DingTimerDB.xp.keepSessions) or 30
      chat("insights keep = " .. tostring(keep))
      return
    end
    if NS.SetKeepSessions then
      local ok, result = NS.SetKeepSessions(rest)
      if not ok then
        chat(result)
        return
      end
      chat("insights keep = " .. tostring(result))
    end
    return
  end
  chat("Unknown history command. Use: clear, keep")
end

ROOT_COMMANDS.analysis = function(arg)
  ROOT_COMMANDS.graph(arg)
end

ROOT_COMMANDS.graph = function(arg)
  local sub, rest = parseSubCommand(arg)
  if sub == "" then
    withWindow(2, true)
    return
  end
  if sub == "on" then
    withWindow(2, false)
    chat("analysis shown.")
    return
  end
  if sub == "off" then
    if NS.IsMainWindowShown and NS.IsMainWindowShown() and (DingTimerDB.lastOpenTab or 1) == 2 then
      if NS.HideMainWindow then
        NS.HideMainWindow()
      end
    end
    chat("analysis hidden.")
    return
  end
  if sub == "zoom" then
    if rest == "" then
      chat("Current zoom: " .. NS.fmtTime(DingTimerDB.graphWindowSeconds or 300))
      NS.chat("  Options: " .. NS.C.val .. "3m, 5m, 15m, 30m, 60m" .. NS.C.r)
      return
    end
    if NS.SetGraphZoom and NS.SetGraphZoom(rest) then
      chat("graph zoom = " .. rest)
    else
      chat("Invalid zoom. Use: 3m, 5m, 15m, 30m, 60m")
    end
    return
  end
  if sub == "scale" then
    if rest == "" then
      local mode = NS.NormalizeGraphScaleMode and NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode) or (DingTimerDB.graphScaleMode or "visible")
      chat("Current scale: " .. mode)
      NS.chat("  Fixed max: " .. NS.C.val .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000) .. NS.C.r)
      return
    end
    if NS.SetGraphScale and NS.SetGraphScale(rest) then
      local mode = NS.NormalizeGraphScaleMode and NS.NormalizeGraphScaleMode(rest) or rest
      chat("graph scale = " .. mode)
    else
      chat("Invalid scale. Use: visible, session, fixed")
    end
    return
  end
  if sub == "fit" then
    if NS.SetGraphScale then
      NS.SetGraphScale("visible")
    end
    chat("graph scale = visible")
    return
  end
  if sub == "max" then
    if rest == "" then
      chat("graph fixed max = " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))
      return
    end
    local maxValue = tonumber(rest)
    if not maxValue then
      chat("Please provide a number (e.g., /ding graph max 250000).")
      return
    end
    if NS.SetGraphFixedMax then
      local applied = NS.SetGraphFixedMax(maxValue)
      if NS.SetGraphScale then
        NS.SetGraphScale("fixed")
      end
      chat("graph fixed max = " .. NS.FormatNumber(applied))
    end
    return
  end
  chat("Unknown graph command. Use: on, off, zoom, scale, fit, max")
end

ROOT_COMMANDS.pvp = function(arg)
  local sub, rest = parseSubCommand(arg)
  if sub == "" then
    if NS.TogglePvpMode then
      NS.TogglePvpMode(GetTime and GetTime() or nil)
      chat("pvp mode = " .. ((NS.IsPvpMode and NS.IsPvpMode()) and "on" or "off"))
    else
      chat("pvp mode is unavailable.")
    end
    return
  end

  if sub == "on" then
    if NS.EnterPvpMode then
      NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, GetTime and GetTime() or nil)
      chat("pvp mode = on")
    end
    return
  end

  if sub == "off" then
    if NS.ExitPvpMode then
      NS.ExitPvpMode("MODE_SWITCH_TO_XP", GetTime and GetTime() or nil)
      chat("pvp mode = off")
    end
    return
  end

  if sub == "goal" then
    if rest == "" then
      chat("pvp goal = " .. ((NS.GetPvpGoalLabel and NS.GetPvpGoalLabel()) or "Unavailable"))
      return
    end
    if NS.SetPvpGoal then
      local ok, result = NS.SetPvpGoal(rest)
      if not ok then
        chat(result)
        return
      end
      chat("pvp goal = " .. ((result == "custom") and rest or result))
    end
    return
  end

  if sub == "auto" then
    if rest == "" then
      local enabled = DingTimerDB and DingTimerDB.pvp and DingTimerDB.pvp.settings and DingTimerDB.pvp.settings.autoSwitchBattlegrounds
      chat("pvp auto = " .. (enabled and "on" or "off"))
      return
    end
    if rest == "on" or rest == "off" then
      if NS.SetPvpAutoSwitch then
        NS.SetPvpAutoSwitch(rest == "on")
      end
      chat("pvp auto = " .. rest)
      return
    end
    chat("Use '/ding pvp auto on' or '/ding pvp auto off'.")
    return
  end

  if sub == "recap" then
    if NS.ShowPvpRecap then
      NS.ShowPvpRecap()
    else
      chat("No PvP recap is available yet.")
    end
    return
  end

  chat("Unknown pvp command. Use: on, off, goal, auto, recap")
end

function NS.ExecuteSlashCommand(msg)
  local cmd, arg = parseWords(msg)
  local handler = ROOT_COMMANDS[cmd]
  if handler then
    handler(arg)
    return
  end
  chat("unknown command. Try /ding help")
end
