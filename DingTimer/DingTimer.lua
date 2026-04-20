local ADDON, NS = ...

local frame = CreateFrame("Frame")

local function safeRegisterEvent(targetFrame, eventName)
  local ok = pcall(targetFrame.RegisterEvent, targetFrame, eventName)
  return ok
end

safeRegisterEvent(frame, "ADDON_LOADED")
safeRegisterEvent(frame, "PLAYER_LOGIN")
safeRegisterEvent(frame, "PLAYER_XP_UPDATE")
safeRegisterEvent(frame, "PLAYER_LEVEL_UP")
safeRegisterEvent(frame, "PLAYER_REGEN_ENABLED")
safeRegisterEvent(frame, "PLAYER_MONEY")
safeRegisterEvent(frame, "PLAYER_LOGOUT")

local function showStartupMessages()
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " tracking started. (/ding help)")
  if DingTimerDB.enabled then
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output enabled.")
  else
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output disabled.")
  end
end

local function onPlayerLogin()
  NS.resetXPState()
  NS.StartHeartbeatTicker()
  if not InCombatLockdown() then
    NS.setFloatVisible(DingTimerDB.float)
  end
  showStartupMessages()
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

  NS.chat(
    string.format(
      "%s[DING]%s %sLEVEL UP%s %s(Level %s)%s",
      NS.C.base,
      NS.C.r,
      NS.C.val,
      NS.C.r,
      NS.C.base,
      tostring(level or "??"),
      NS.C.r
    )
  )
  NS.chat(
    string.format(
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
  )
  if PlaySound and DingTimerDB.dingSoundEnabled ~= false then
    PlaySound(12891, "Master")
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

    if event == "PLAYER_REGEN_ENABLED" then
      NS.setFloatVisible(DingTimerDB.float)
      return
    end

    if event == "PLAYER_LOGOUT" then
      return
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
