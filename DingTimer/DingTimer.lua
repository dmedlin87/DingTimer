local ADDON, NS = ...

-- Core Frame for Event Handling
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(self, event, ...)
  local arg1 = ...
  if event == "ADDON_LOADED" and arg1 == ADDON then
    NS.InitStore()
    NS.ensureFloat()
  elseif event == "PLAYER_LOGIN" then
    NS.resetXPState()
    if not InCombatLockdown() then
      NS.setFloatVisible(DingTimerDB.float)
    end
    if DingTimerDB.mainWindowVisible then
      if NS.ShowMainWindow then
        NS.ShowMainWindow(DingTimerDB.lastOpenTab or 1)
      end
    end
    if NS.InitMinimapButton then
      NS.InitMinimapButton()
    end
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " tracking started. (/ding help)")
    if DingTimerDB.enabled then
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output enabled.")
    else
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output disabled. (UI still tracks)")
    end
  elseif event == "PLAYER_XP_UPDATE" then
    if arg1 == "player" then NS.onXPUpdate() end
  elseif event == "PLAYER_LEVEL_UP" then
    local level = arg1 or "??"
    local now = GetTime()
    local timeTaken = now - (NS.state.sessionStartTime or now)
    local moneyNet = NS.state.sessionMoney or 0
    
    local timeStr = NS.fmtTime(timeTaken)
    local moneyStr = NS.fmtMoney(moneyNet)
    if moneyNet > 0 then
      moneyStr = "|cff00ff00+|r" .. moneyStr
    end
    
    local header = string.format("%s[DING]%s %s★ LEVEL UP! ★%s %s(Level %s)%s", NS.C.base, NS.C.r, NS.C.val, NS.C.r, NS.C.base, tostring(level), NS.C.r)
    local stats = string.format("  %s↳%s %sTime in level:%s %s%s%s  |  %sNet Money:%s %s", 
      NS.C.mid, NS.C.r, 
      NS.C.mid, NS.C.r, NS.C.val, timeStr, NS.C.r, 
      NS.C.mid, NS.C.r, moneyStr)
    
    NS.chat(header)
    NS.chat(stats)

    if NS.RecordSession then
      NS.RecordSession("LEVEL_UP")
    end
    NS.resetXPState()
  elseif event == "PLAYER_MONEY" then
    NS.onMoneyUpdate()
  elseif event == "PLAYER_LOGOUT" then
    if NS.RecordSession then
      NS.RecordSession("LOGOUT")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Catch up on visibility if it was toggled during combat
    NS.setFloatVisible(DingTimerDB.float)
  end
end)

-- Slash commands
SLASH_DINGTIMER1 = "/ding"
SLASH_DINGTIMER2 = "/dt"
SlashCmdList.DINGTIMER = function(msg)
  msg = (msg or "")
  local lower = msg:lower()

  local cmd, arg = lower:match("^(%S+)%s*(.*)$")
  cmd = cmd or ""

  if cmd == "help" or cmd == "" then
    if arg == "mode" then
      NS.chat(NS.C.base .. "=== DingTimer Help: mode ===" .. NS.C.r)
      NS.chat("  " .. NS.C.val .. "full" .. NS.C.r .. " - Displays XP gained, current XP/hr, and Time to Level (TTL).")
      NS.chat("  " .. NS.C.val .. "ttl" .. NS.C.r .. " - Displays only the Time to Level (TTL).")
      NS.chat("  Example: " .. NS.C.val .. "/ding mode ttl" .. NS.C.r)
    elseif arg == "window" then
      NS.chat(NS.C.base .. "=== DingTimer Help: window ===" .. NS.C.r)
      NS.chat("  Sets the rolling time window (in seconds) used to calculate your XP/hr.")
      NS.chat("  A smaller window reacts faster; a larger window provides a smoother average.")
      NS.chat("  Updating the window no longer resets your current session.")
      NS.chat("  Example: " .. NS.C.val .. "/ding window 600" .. NS.C.r .. " (for a 10-minute average)")
    elseif arg == "float" then
      NS.chat(NS.C.base .. "=== DingTimer Help: float ===" .. NS.C.r)
      NS.chat("  " .. NS.C.val .. "on | off" .. NS.C.r .. " - Toggles the floating UI frame on the screen.")
      NS.chat("  " .. NS.C.val .. "lock | unlock" .. NS.C.r .. " - Locks or unlocks the frame so you can drag it.")
      NS.chat("  Example: " .. NS.C.val .. "/ding float unlock" .. NS.C.r)
    elseif arg == "graph" then
      NS.chat(NS.C.base .. "=== DingTimer Help: graph ===" .. NS.C.r)
      NS.chat("  " .. NS.C.val .. "on | off" .. NS.C.r .. " - Open or close the Graph tab in the main window.")
      NS.chat("  " .. NS.C.val .. "zoom 3m|5m|15m|30m|60m" .. NS.C.r .. " - Set the rolling time window.")
      NS.chat("  " .. NS.C.val .. "scale visible|session|fixed" .. NS.C.r .. " - Fit to visible bars, fit to retained history, or use a fixed cap.")
      NS.chat("  " .. NS.C.val .. "fit" .. NS.C.r .. " - Shortcut for visible scale.")
      NS.chat("  " .. NS.C.val .. "max <xp/hr>" .. NS.C.r .. " - Set the fixed Y-axis cap.")
    elseif arg == "insights" then
      NS.chat(NS.C.base .. "=== DingTimer Help: insights ===" .. NS.C.r)
      NS.chat("  " .. NS.C.val .. "/ding insights" .. NS.C.r .. " - Toggle the Session Insights window.")
      NS.chat("  " .. NS.C.val .. "/ding insights clear" .. NS.C.r .. " - Clear history for this character profile.")
      NS.chat("  " .. NS.C.val .. "/ding insights keep <n>" .. NS.C.r .. " - Keep between 5 and 100 sessions (default 30).")
      NS.chat("  Example: " .. NS.C.val .. "/ding insights keep 30" .. NS.C.r)
    else
      NS.chat(NS.C.base .. "=== DingTimer Commands (/ding or /dt) ===" .. NS.C.r)
      NS.chat("  " .. NS.C.val .. "/ding ui" .. NS.C.r .. " - Toggle the Dashboard tab")
      NS.chat("  " .. NS.C.val .. "/ding settings" .. NS.C.r .. " - Toggle the Settings tab")
      NS.chat("  " .. NS.C.val .. "/ding on | off" .. NS.C.r .. " - Enable or disable chat output")
      NS.chat("  " .. NS.C.val .. "/ding reset" .. NS.C.r .. " - Reset the current session data")
      NS.chat("  " .. NS.C.val .. "/ding insights" .. NS.C.r .. " - Open Session Insights")
      NS.chat("  " .. NS.C.val .. "/ding window <seconds>" .. NS.C.r .. " - Set the time window for tracking calculation (e.g., 600)")
      NS.chat("  " .. NS.C.val .. "/ding mode full | ttl" .. NS.C.r .. " - Change chat output style")
      NS.chat("  " .. NS.C.val .. "/ding float on | off" .. NS.C.r .. " - Toggle the floating UI frame")
      NS.chat("  " .. NS.C.val .. "/ding float lock | unlock" .. NS.C.r .. " - Lock or unlock floating frame dragging")
      NS.chat("  " .. NS.C.val .. "/ding graph" .. NS.C.r .. " - Toggle the Graph tab")
      NS.chat("  " .. NS.C.val .. "/ding graph on | off" .. NS.C.r .. " - Open or close the Graph tab")
      NS.chat("  " .. NS.C.val .. "/ding graph zoom <level>" .. NS.C.r .. " - Set graph time window (3m, 5m, 15m, 30m, 60m)")
      NS.chat("  " .. NS.C.val .. "/ding graph scale <mode>" .. NS.C.r .. " - Set Y-axis scale (visible, session, fixed)")
      NS.chat("  " .. NS.C.val .. "/ding graph max <xp/hr>" .. NS.C.r .. " - Set the fixed graph cap")
      NS.chat("  Type " .. NS.C.val .. "/ding help <command>" .. NS.C.r .. " for more details (e.g., /ding help mode)")
    end
    return
  end

  if cmd == "ui" or cmd == "stats" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(1) end
    return
  end

  if cmd == "settings" then
    if NS.ToggleMainWindow then NS.ToggleMainWindow(4) end
    return
  end

  if cmd == "off" then
    DingTimerDB.enabled = false
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output disabled. (UI still tracks)")
    return
  end

  if cmd == "on" then
    DingTimerDB.enabled = true
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output enabled.")
    return
  end

  if cmd == "reset" then
    if NS.RecordSession then
      NS.RecordSession("MANUAL_RESET")
    end
    NS.resetXPState()
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
    return
  end

  if cmd == "insights" then
    local sub, subarg = (arg or ""):match("^(%S*)%s*(.*)$")
    sub = sub or ""
    subarg = subarg or ""

    if sub == "" then
      if NS.ToggleMainWindow then NS.ToggleMainWindow(3) end
      return
    end

    if sub == "clear" then
      if NS.ClearProfileSessions then
        NS.ClearProfileSessions()
      end
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights history cleared for this character.")
      return
    end

    if sub == "keep" then
      if subarg == "" then
        local keep = (DingTimerDB.xp and DingTimerDB.xp.keepSessions) or 30
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights keep = " .. tostring(keep))
        return
      end

      local n = tonumber(subarg)
      if not n then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Please provide a number (e.g., /ding insights keep 30).")
        return
      end

      if n < 5 or n > 100 then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights keep must be between 5 and 100.")
        return
      end

      DingTimerDB.xp = DingTimerDB.xp or {}
      DingTimerDB.xp.keepSessions = math.floor(n)
      if NS.GetProfileStore and NS.TrimSessions then
        local profile = NS.GetProfileStore(true)
        NS.TrimSessions(profile, DingTimerDB.xp.keepSessions)
      end
      if NS.RefreshInsightsWindow then
        NS.RefreshInsightsWindow()
      end
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " insights keep = " .. tostring(DingTimerDB.xp.keepSessions))
      return
    end

    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Unknown insights command. Use: clear, keep")
    return
  end

  if cmd == "window" then
    local n = tonumber(arg)
    if n then
      if NS.SetRollingWindowSeconds and NS.SetRollingWindowSeconds(n) then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " windowSeconds = " .. n)
      else
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " window must be between 30 and 86400 seconds (24h).")
      end
    else
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Please provide a number (e.g., /ding window 600).")
    end
    return
  end

  if cmd == "mode" then
    if arg == "full" or arg == "ttl" then
      DingTimerDB.mode = arg
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " mode = " .. arg)
    else
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Unknown mode. Use 'full' or 'ttl'.")
    end
    return
  end

  if cmd == "float" then
    if arg == "on" or arg == "off" then
      DingTimerDB.float = (arg == "on")
      NS.setFloatVisible(DingTimerDB.float)
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " float = " .. arg)
    elseif arg == "lock" or arg == "unlock" then
      DingTimerDB.floatLocked = (arg == "lock")
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " floatLocked = " .. arg)
    else
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Unknown float command. Use 'on', 'off', 'lock', or 'unlock'.")
    end
    return
  end

  if cmd == "graph" then
    local sub, subarg = (arg or ""):match("^(%S*)%s*(.*)$")
    sub = sub or ""

    if sub == "" then
      if NS.ToggleMainWindow then NS.ToggleMainWindow(2) end
    elseif sub == "on" then
      if NS.ShowMainWindow then NS.ShowMainWindow(2) end
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph shown.")
    elseif sub == "off" then
      if NS.IsMainWindowShown and NS.IsMainWindowShown() and (DingTimerDB.lastOpenTab or 1) == 2 then
        if NS.HideMainWindow then
          NS.HideMainWindow()
        end
      end
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph hidden.")
    elseif sub == "zoom" then
      if subarg == "" then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Current zoom: " .. NS.fmtTime(DingTimerDB.graphWindowSeconds or 300))
        NS.chat("  Options: " .. NS.C.val .. "3m, 5m, 15m, 30m, 60m" .. NS.C.r)
      elseif NS.SetGraphZoom and NS.SetGraphZoom(subarg) then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph zoom = " .. subarg)
      else
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Invalid zoom. Use: 3m, 5m, 15m, 30m, 60m")
      end
    elseif sub == "scale" then
      if subarg == "" then
        local mode = NS.NormalizeGraphScaleMode and NS.NormalizeGraphScaleMode(DingTimerDB.graphScaleMode) or (DingTimerDB.graphScaleMode or "visible")
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Current scale: " .. mode)
        NS.chat("  Fixed max: " .. NS.C.val .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000) .. NS.C.r)
      elseif NS.SetGraphScale and NS.SetGraphScale(subarg) then
        local mode = NS.NormalizeGraphScaleMode and NS.NormalizeGraphScaleMode(subarg) or subarg
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph scale = " .. mode)
      else
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Invalid scale. Use: visible, session, fixed")
      end
    elseif sub == "fit" then
      if NS.SetGraphScale then
        NS.SetGraphScale("visible")
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph scale = visible")
      end
    elseif sub == "max" then
      if subarg == "" then
        NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph fixed max = " .. NS.FormatNumber(DingTimerDB.graphFixedMaxXPH or 100000))
      else
        local maxValue = tonumber(subarg)
        if not maxValue then
          NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Please provide a number (e.g., /ding graph max 250000).")
        elseif NS.SetGraphFixedMax then
          local applied = NS.SetGraphFixedMax(maxValue)
          if NS.SetGraphScale then
            NS.SetGraphScale("fixed")
          end
          NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " graph fixed max = " .. NS.FormatNumber(applied))
        end
      end
    else
      NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " Unknown graph command. Use: on, off, zoom, scale, fit, max")
    end
    return
  end

  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " unknown command. Try /ding help")
end
