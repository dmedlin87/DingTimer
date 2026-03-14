local ADDON, NS = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_LOGOUT")
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

frame:SetScript("OnEvent", function(self, event, ...)
  local arg1 = ...
  if event == "ADDON_LOADED" and arg1 == ADDON then
    NS.InitStore()
    NS.ensureFloat()
    return
  end

  if event == "PLAYER_LOGIN" then
    onPlayerLogin()
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
    if NS.RecordSession then
      NS.RecordSession("LOGOUT")
    end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    NS.setFloatVisible(DingTimerDB.float)
    return
  end

  if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
    if NS.HandleZoneChange then
      NS.HandleZoneChange(GetZoneText and GetZoneText() or "Unknown", GetTime())
    end
    if NS.RefreshStatsWindow then
      NS.RefreshStatsWindow()
    end
    if NS.RefreshInsightsWindow then
      NS.RefreshInsightsWindow()
    end
  end
end)

SLASH_DINGTIMER1 = "/ding"
SLASH_DINGTIMER2 = "/dt"
SlashCmdList.DINGTIMER = function(msg)
  if NS.ExecuteSlashCommand then
    NS.ExecuteSlashCommand(msg)
  end
end
