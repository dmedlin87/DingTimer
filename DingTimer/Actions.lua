local ADDON, NS = ...

local function refreshCoachViews()
  if NS.RefreshStatsWindow then
    NS.RefreshStatsWindow()
  end
  if NS.RefreshSettingsPanel then
    NS.RefreshSettingsPanel()
  end
end

function NS.SetCoachGoal(goal)
  if not NS.EnsureCoachConfig then
    return false, "coach is unavailable."
  end
  if goal ~= "off" and goal ~= "ding" and goal ~= "30m" and goal ~= "60m" then
    return false, "Invalid goal. Use: off, ding, 30m, 60m"
  end

  local config = NS.EnsureCoachConfig()
  config.goal = goal
  refreshCoachViews()
  return true, goal
end

function NS.SetKeepSessions(count)
  local n = tonumber(count)
  if not n then
    return false, "Please provide a number (e.g., /ding insights keep 30)."
  end
  if n < 5 or n > 100 then
    return false, "insights keep must be between 5 and 100."
  end

  DingTimerDB.xp = DingTimerDB.xp or {}
  DingTimerDB.xp.keepSessions = math.floor(n)
  if NS.GetProfileStore and NS.TrimSessions then
    NS.TrimSessions(NS.GetProfileStore(true), DingTimerDB.xp.keepSessions)
  end
  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end
  if NS.RefreshSettingsPanel then
    NS.RefreshSettingsPanel()
  end
  return true, DingTimerDB.xp.keepSessions
end

function NS.ClearCurrentProfileHistory()
  if NS.ClearProfileSessions then
    NS.ClearProfileSessions()
  end
  if NS.RefreshSettingsPanel then
    NS.RefreshSettingsPanel()
  end
  return true
end

function NS.ResetSession(reason)
  if NS.IsPvpMode and NS.IsPvpMode() then
    if NS.ResetPvpSession then
      NS.ResetPvpSession(reason or "MANUAL_RESET")
    end
  else
    if NS.RecordSession then
      NS.RecordSession(reason or "MANUAL_RESET")
    end
    if NS.resetXPState then
      NS.resetXPState()
    end
  end
  refreshCoachViews()
  return true
end
