local _, NS = ...

local math_huge = math.huge
local string_format = string.format

function NS.onXPUpdate()
  local now = GetTime()
  local xp = UnitXP("player") or 0
  local maxXP = UnitXPMax("player") or 0

  local delta = xp - (NS.state.lastXP or 0)
  if delta < 0 then
    delta = (NS.state.lastMax or 0) - (NS.state.lastXP or 0) + xp
  end

  NS.state.lastXP = xp
  NS.state.lastMax = maxXP

  local windowSeconds = NS.GetRollingWindowSeconds()
  NS.PruneRollingEvents(NS.state.events, now, windowSeconds, NS.state, "windowXP", "xp")

  if delta > 0 then
    local events = NS.state.events
    NS.state.sessionXP = (NS.state.sessionXP or 0) + delta
    NS.state.lastXPGain = delta
    NS.state.lastXPAt = now
    events[#events + 1] = { t = now, xp = delta }
    NS.state.windowXP = (NS.state.windowXP or 0) + delta
    if NS.TriggerFloatGainPulse then
      NS.TriggerFloatGainPulse((maxXP > 0) and (xp / maxXP) or 0)
    end
  end

  NS.InvalidateTickCache()

  local snapshot = NS.GetSessionSnapshot(now)
  if not snapshot then
    NS.RunHeartbeat(now)
    return
  end
  if DingTimerDB.enabled and delta >= NS.GetMinXPDeltaToPrint() then
    local header = NS.C.base .. "[DING]" .. NS.C.r .. " "
    local ttl = snapshot.ttl or math_huge
    local trendColor = NS.ttlColor and NS.ttlColor(ttl, NS.state.lastTTL) or ""
    local trendText = NS.ttlDeltaText and NS.ttlDeltaText(ttl, NS.state.lastTTL) or ""

    if (DingTimerDB.mode or "full") == "ttl" then
      NS.chat(header .. NS.C.base .. NS.fmtTime(ttl) .. NS.C.r .. " to level" .. trendColor .. trendText .. NS.C.r)
    else
      NS.chat(
        header
          .. "+"
          .. NS.C.base
          .. delta
          .. NS.C.r
          .. " XP  "
          .. NS.C.base
          .. string_format("%.0f", snapshot.currentXph or 0)
          .. NS.C.r
          .. " XP/hr  TTL "
          .. NS.C.base
          .. NS.fmtTime(ttl)
          .. NS.C.r
          .. trendColor
          .. trendText
          .. NS.C.r
      )
    end
  end

  NS.state.lastTTL = snapshot.ttl or NS.state.lastTTL
  NS.RunHeartbeat(now)
end

function NS.onMoneyUpdate()
  local now = GetTime()
  local currentMoney = GetMoney() or 0
  local delta = currentMoney - (NS.state.lastMoney or 0)
  NS.state.lastMoney = currentMoney

  if delta ~= 0 then
    NS.state.sessionMoney = (NS.state.sessionMoney or 0) + delta
  end

  local windowSeconds = NS.GetRollingWindowSeconds()
  NS.PruneRollingEvents(NS.state.moneyEvents, now, windowSeconds, NS.state, "windowMoney", "money")

  if delta > 0 then
    local moneyEvents = NS.state.moneyEvents
    moneyEvents[#moneyEvents + 1] = { t = now, money = delta }
    NS.state.windowMoney = (NS.state.windowMoney or 0) + delta
  end

  NS.InvalidateTickCache()
end
