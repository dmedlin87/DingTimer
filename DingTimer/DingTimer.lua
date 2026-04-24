local ADDON, NS = ...

local frame = CreateFrame("Frame")

local REQUIRED_EVENTS = {
  "ADDON_LOADED",
  "PLAYER_LOGIN",
  "PLAYER_XP_UPDATE",
  "PLAYER_LEVEL_UP",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_MONEY",
}

local function registerRequiredEvent(targetFrame, eventName)
  local ok, err = pcall(targetFrame.RegisterEvent, targetFrame, eventName)
  if not ok then
    error("Failed to register required event " .. tostring(eventName) .. ": " .. tostring(err), 0)
  end
end

for i = 1, #REQUIRED_EVENTS do
  registerRequiredEvent(frame, REQUIRED_EVENTS[i])
end

local function showStartupMessages()
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " tracking started. (/ding help)")
  if DingTimerDB.enabled then
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output enabled.")
  else
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " chat output disabled.")
  end
end

local function syncFloatVisibility()
  if NS.setFloatVisible then
    NS.setFloatVisible(DingTimerDB.float)
  end
end

function NS.PlayDingSoundPreview()
  if PlaySound then
    PlaySound(12891, "Master")
    return true
  end
  return false
end

local function onPlayerLogin()
  NS.resetXPState()
  syncFloatVisibility()
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
  if DingTimerDB.dingSoundEnabled == true and NS.PlayDingSoundPreview then
    NS.PlayDingSoundPreview()
  end
  NS.resetXPState()
  NS.state.skipNextXPDropAfterLevelUp = true
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

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
      syncFloatVisibility()
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
