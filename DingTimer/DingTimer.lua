local ADDON, NS = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
frame:RegisterEvent("HONOR_XP_UPDATE")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local function showStartupMessages()
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " tracking started. (/ding help)")
  if DingTimerDB.enabled then
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output enabled.")
  else
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output disabled. (UI still tracks)")
  end
end

local function onPlayerLogin()
  NS.resetXPState()
  NS.StartCoachTicker()
  if NS.RestorePvpResumeIfAvailable then
    NS.RestorePvpResumeIfAvailable(GetTime())
  end

  if not InCombatLockdown() then
    NS.setFloatVisible(DingTimerDB.float)
  end

  if DingTimerDB.mainWindowVisible and NS.ShowMainWindow then
    NS.ShowMainWindow(DingTimerDB.lastOpenTab or 1)
  end

  if NS.InitMinimapButton then
    NS.InitMinimapButton()
  end

  showStartupMessages()
  if NS.DeliverPendingCoachSummary then
    NS.DeliverPendingCoachSummary()
  end
end

local function onLevelUp(level)
  if NS.IsPvpMode and NS.IsPvpMode() then
    return
  end

  local now = GetTime()
  local timeTaken = now - (NS.state.sessionStartTime or now)
  local moneyNet = NS.state.sessionMoney or 0

  local timeStr = NS.fmtTime(timeTaken)
  local moneyStr = NS.fmtMoney(moneyNet)
  if moneyNet > 0 then
    moneyStr = "|cff00ff00+|r" .. moneyStr
  end

  local header = string.format(
    "%s[DING]%s %sLEVEL UP%s %s(Level %s)%s",
    NS.C.base,
    NS.C.r,
    NS.C.val,
    NS.C.r,
    NS.C.base,
    tostring(level or "??"),
    NS.C.r
  )
  local stats = string.format(
    "  %sTime in level:%s %s%s%s  |  %sNet Money:%s %s",
    NS.C.mid,
    NS.C.r,
    NS.C.val,
    timeStr,
    NS.C.r,
    NS.C.mid,
    NS.C.r,
    moneyStr
  )

  NS.chat(header)
  NS.chat(stats)
  if NS.RecordSession then
    NS.RecordSession("LEVEL_UP")
  end
  NS.resetXPState()
end

frame:SetScript("OnEvent", function(_, event, ...)
  local arg1 = ...
  local ok, err = pcall(function()
    if event == "ADDON_LOADED" and arg1 == ADDON then
      NS.InitStore()
      NS.ensureFloat()
      return
    end

    if event == "PLAYER_LOGIN" then
      onPlayerLogin()
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      if NS.HandlePvpWorldStateChange then
        NS.HandlePvpWorldStateChange(GetTime())
      end
      return
    end

    if event == "PLAYER_XP_UPDATE" then
      if arg1 == "player" then
        NS.onXPUpdate()
      end
      return
    end

    if event == "PLAYER_LEVEL_UP" then
      onLevelUp(arg1)
      return
    end

    if event == "PLAYER_MONEY" then
      NS.onMoneyUpdate()
      return
    end

    if event == "PLAYER_LOGOUT" then
      if NS.IsPvpMode and NS.IsPvpMode() then
        if NS.PersistPvpResume then
          NS.PersistPvpResume(GetTime())
        end
      elseif NS.RecordSession then
        NS.RecordSession("LOGOUT")
      end
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      NS.setFloatVisible(DingTimerDB.float)
      if NS.FlushPvpNotifications then
        NS.FlushPvpNotifications(GetTime())
      end
      return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
      if (not (NS.IsPvpMode and NS.IsPvpMode())) and NS.HandleZoneChange then
        NS.HandleZoneChange(GetZoneText and GetZoneText() or "Unknown", GetTime())
      end
      if NS.HandlePvpWorldStateChange then
        NS.HandlePvpWorldStateChange(GetTime())
      end
      if NS.RefreshStatsWindow then
        NS.RefreshStatsWindow()
      end
      if NS.RefreshInsightsWindow then
        NS.RefreshInsightsWindow()
      end
      return
    end

    if event == "CURRENCY_DISPLAY_UPDATE" then
      if NS.HandlePvpEvent
        and (not NS.IsRelevantPvpCurrencyEvent or NS.IsRelevantPvpCurrencyEvent(arg1)) then
        NS.HandlePvpEvent(event, GetTime())
      end
      return
    end

    if event == "PLAYER_PVP_KILLS_CHANGED"
      or event == "HONOR_XP_UPDATE"
      or event == "UPDATE_BATTLEFIELD_SCORE"
      or event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
      if NS.HandlePvpEvent then
        NS.HandlePvpEvent(event, GetTime())
      end
    end
  end)
  if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4040[DingTimer] Error:|r " .. tostring(err))
  end
end)

SLASH_DINGTIMER1 = "/ding"
SLASH_DINGTIMER2 = "/dt"
SlashCmdList.DINGTIMER = function(msg)
  if NS.ExecuteSlashCommand then
    NS.ExecuteSlashCommand(msg)
  end
end
