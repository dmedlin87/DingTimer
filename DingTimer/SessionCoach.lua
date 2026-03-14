local ADDON, NS = ...

local DEFAULTS = {
  goal = "ding",
  alertsEnabled = true,
  chatAlerts = true,
  idleSeconds = 90,
  paceDropPct = 15,
  alertCooldownSeconds = 90,
  alertHistoryLimit = 4,
}

local GOAL_MINUTES = {
  ["30m"] = 30,
  ["60m"] = 60,
}

local REASON_LABELS = {
  SESSION_START = "Session start",
  MANUAL_SPLIT = "Manual split",
  MANUAL_RESET = "Reset",
  ZONE_CHANGED = "Zone change",
  LEVEL_UP = "Level up",
  LOGOUT = "Logout",
}

local function copyTable(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      out[key] = copyTable(value)
    else
      out[key] = value
    end
  end
  return out
end

local function safeNumber(value, fallback)
  local n = tonumber(value)
  if not n or n ~= n or n == math.huge or n == -math.huge then
    return fallback
  end
  return n
end

local function safeString(value, fallback)
  if type(value) == "string" and value ~= "" then
    return value
  end
  if value ~= nil then
    local str = tostring(value)
    if str ~= "" then
      return str
    end
  end
  return fallback
end

local function normalizeGoal(goal)
  if goal == "off" or goal == "ding" or goal == "30m" or goal == "60m" then
    return goal
  end
  return DEFAULTS.goal
end

local function getCoachRuntime(now)
  NS.state = NS.state or {}
  NS.state.coach = NS.state.coach or {
    lastXPAt = now or GetTime(),
    lastAlertAt = {},
    alerts = {},
    segments = {},
    bestSegmentXph = 0,
    currentZone = "Unknown",
    currentSegment = nil,
  }
  return NS.state.coach
end

local function getZone()
  if GetZoneText then
    return safeString(GetZoneText(), "Unknown")
  end
  return "Unknown"
end

local function getReasonLabel(reason)
  return REASON_LABELS[reason] or safeString(reason, "Checkpoint")
end

local function beginSegment(now, reason, zone)
  local coach = getCoachRuntime(now)
  coach.currentSegment = {
    startedAt = now,
    reason = reason or "SESSION_START",
    zone = zone or coach.currentZone or getZone(),
    xpGained = 0,
    moneyNetCopper = 0,
  }
end

local function recentAlerts()
  local coach = getCoachRuntime(GetTime())
  return coach.alerts or {}
end

local function finalizeSegment(now, reason, keepEmpty)
  local coach = getCoachRuntime(now)
  local segment = coach.currentSegment
  if not segment then
    return nil
  end

  local durationSec = math.max(1, (now or GetTime()) - (segment.startedAt or (now or GetTime())))
  local xpGained = segment.xpGained or 0
  local moneyNetCopper = segment.moneyNetCopper or 0
  if not keepEmpty and xpGained <= 0 and moneyNetCopper == 0 then
    coach.currentSegment = nil
    return nil
  end

  local record = {
    id = string.format("%d-%d", math.floor((now or GetTime()) + 0.5), (#coach.segments or 0) + 1),
    startedAt = segment.startedAt,
    endedAt = now,
    durationSec = durationSec,
    zone = segment.zone or coach.currentZone or getZone(),
    reason = reason or segment.reason or "SESSION_START",
    xpGained = xpGained,
    moneyNetCopper = moneyNetCopper,
    avgXph = (xpGained / durationSec) * 3600,
    avgMoneyPh = (moneyNetCopper / durationSec) * 3600,
  }

  coach.segments[#coach.segments + 1] = record
  coach.currentSegment = nil

  if record.xpGained > 0 and record.avgXph > (coach.bestSegmentXph or 0) then
    coach.bestSegmentXph = record.avgXph
    if NS.PushCoachAlert then
      NS.PushCoachAlert(
        "best_segment",
        string.format(
          "New best segment: %s XP/hr in %s.",
          NS.FormatNumber(NS.Round(record.avgXph)),
          safeString(record.zone, "Unknown")
        ),
        now
      )
    end
  end

  return record
end

local function buildCurrentSegment(now)
  local coach = getCoachRuntime(now)
  local current = coach.currentSegment
  if not current then
    return nil
  end

  local durationSec = math.max(1, (now or GetTime()) - (current.startedAt or (now or GetTime())))
  local xpGained = current.xpGained or 0
  local moneyNetCopper = current.moneyNetCopper or 0
  return {
    id = "current",
    startedAt = current.startedAt,
    endedAt = now,
    durationSec = durationSec,
    zone = current.zone or coach.currentZone or getZone(),
    reason = current.reason or "SESSION_START",
    xpGained = xpGained,
    moneyNetCopper = moneyNetCopper,
    avgXph = (xpGained / durationSec) * 3600,
    avgMoneyPh = (moneyNetCopper / durationSec) * 3600,
    isCurrent = true,
  }
end

function NS.GetCoachDefaults()
  return copyTable(DEFAULTS)
end

function NS.EnsureCoachConfig(db)
  db = db or DingTimerDB or {}
  db.coach = db.coach or {}
  for key, value in pairs(DEFAULTS) do
    if db.coach[key] == nil then
      db.coach[key] = value
    end
  end
  db.coach.goal = normalizeGoal(db.coach.goal)
  db.coach.idleSeconds = math.max(30, math.floor(safeNumber(db.coach.idleSeconds, DEFAULTS.idleSeconds)))
  db.coach.paceDropPct = math.max(5, math.min(50, math.floor(safeNumber(db.coach.paceDropPct, DEFAULTS.paceDropPct))))
  db.coach.alertCooldownSeconds = math.max(30, math.floor(safeNumber(db.coach.alertCooldownSeconds, DEFAULTS.alertCooldownSeconds)))
  db.coach.alertHistoryLimit = math.max(1, math.min(8, math.floor(safeNumber(db.coach.alertHistoryLimit, DEFAULTS.alertHistoryLimit))))
  return db.coach
end

function NS.InitCoachState(now)
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  coach.lastXPAt = at
  coach.lastAlertAt = {}
  coach.alerts = {}
  coach.segments = {}
  coach.bestSegmentXph = 0
  coach.currentZone = getZone()
  coach.currentSegment = nil
  beginSegment(at, "SESSION_START", coach.currentZone)
end

function NS.NoteCoachXP(delta, now)
  if not delta or delta <= 0 then
    return
  end
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  if not coach.currentSegment then
    beginSegment(at, "SESSION_START", coach.currentZone or getZone())
  end
  coach.currentSegment.xpGained = (coach.currentSegment.xpGained or 0) + delta
  coach.lastXPAt = at
end

function NS.NoteCoachMoney(delta, now)
  if not delta then
    return
  end
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  if not coach.currentSegment then
    beginSegment(at, "SESSION_START", coach.currentZone or getZone())
  end
  coach.currentSegment.moneyNetCopper = (coach.currentSegment.moneyNetCopper or 0) + delta
end

function NS.PushCoachAlert(kind, message, now)
  if not message or message == "" then
    return false
  end
  local at = now or GetTime()
  local config = NS.EnsureCoachConfig()
  if not config.alertsEnabled then
    return false
  end

  local coach = getCoachRuntime(at)
  local lastAt = coach.lastAlertAt[kind]
  if lastAt and (at - lastAt) < config.alertCooldownSeconds then
    return false
  end

  coach.lastAlertAt[kind] = at
  local entry = {
    kind = kind,
    at = at,
    text = message,
  }
  local alerts = coach.alerts
  alerts[#alerts + 1] = entry

  while #alerts > config.alertHistoryLimit do
    table.remove(alerts, 1)
  end

  if config.chatAlerts and NS.chat then
    NS.chat(NS.C.base .. "[COACH]" .. NS.C.r .. " " .. message)
  end
  return true
end

function NS.GetCoachAlerts(limit)
  local alerts = recentAlerts()
  local count = math.min(#alerts, math.max(1, math.floor(limit or #alerts)))
  local result = {}
  local index = 0
  for i = #alerts, math.max(1, #alerts - count + 1), -1 do
    index = index + 1
    result[index] = alerts[i]
  end
  return result
end

function NS.SplitSession(reason, now)
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  finalizeSegment(at, reason or "MANUAL_SPLIT", reason == "MANUAL_SPLIT")
  beginSegment(at, reason or "MANUAL_SPLIT", coach.currentZone or getZone())
end

function NS.HandleZoneChange(zone, now)
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  local newZone = safeString(zone, getZone())
  if coach.currentZone == newZone then
    return false
  end
  finalizeSegment(at, "ZONE_CHANGED", false)
  coach.currentZone = newZone
  beginSegment(at, "ZONE_CHANGED", newZone)
  return true
end

function NS.FinalizeSessionSegments(reason, now)
  local at = now or GetTime()
  local coach = getCoachRuntime(at)
  local finalized = {}
  for i = 1, #coach.segments do
    finalized[i] = copyTable(coach.segments[i])
  end
  local current = finalizeSegment(at, reason or "MANUAL_RESET", false)
  if current then
    finalized[#finalized + 1] = copyTable(current)
  end
  return finalized
end

function NS.GetCoachGoalStatus(snapshot)
  if not snapshot then
    return {
      goal = DEFAULTS.goal,
      goalLabel = "Ding this level",
      targetXph = nil,
      status = "Waiting for a session snapshot.",
    }
  end

  local config = NS.EnsureCoachConfig()
  local goal = normalizeGoal(config.goal)
  if goal == "off" then
    return {
      goal = goal,
      goalLabel = "Coach disabled",
      shortLabel = "Goal",
      targetXph = nil,
      benchmarkXph = snapshot.sessionXph,
      status = "Session pace remains available for comparison.",
      deltaXph = 0,
    }
  end

  if goal == "ding" then
    local benchmark = (snapshot.sessionPeakXph and snapshot.sessionPeakXph > 0) and snapshot.sessionPeakXph or nil
    local delta = benchmark and (snapshot.currentXph - benchmark) or 0
    local status
    if benchmark and benchmark > 0 then
      if math.abs(delta) < 0.5 then
        status = "Current pace is matching your session high."
      elseif delta > 0 then
        status = string.format(
          "Ahead of session high by %s XP/hr.",
          NS.FormatNumber(NS.Round(delta))
        )
      else
        status = string.format(
          "Behind session high by %s XP/hr.",
          NS.FormatNumber(NS.Round(math.abs(delta)))
        )
      end
    else
      status = (snapshot.ttl and snapshot.ttl < math.huge)
        and ("Current ETA: " .. NS.fmtTime(snapshot.ttl))
        or "Need XP to estimate time-to-ding."
    end

    return {
      goal = goal,
      goalLabel = "Session high pace",
      shortLabel = "High",
      targetXph = benchmark,
      benchmarkXph = benchmark,
      status = status,
      deltaXph = delta,
    }
  end

  local goalMinutes = GOAL_MINUTES[goal] or 30
  local goalSeconds = goalMinutes * 60
  local requiredXph = 0
  if snapshot.remainingXP > 0 then
    requiredXph = (snapshot.remainingXP / goalSeconds) * 3600
  end
  local delta = snapshot.currentXph - requiredXph
  local status
  if delta >= 0 then
    status = string.format(
      "Ahead by %s XP/hr toward a %dm ding.",
      NS.FormatNumber(NS.Round(delta)),
      goalMinutes
    )
  else
    status = string.format(
      "Behind by %s XP/hr for a %dm ding.",
      NS.FormatNumber(NS.Round(math.abs(delta))),
      goalMinutes
    )
  end

  return {
    goal = goal,
    goalLabel = string.format("Ding in %dm", goalMinutes),
    shortLabel = "Goal",
    targetXph = requiredXph,
    benchmarkXph = requiredXph,
    status = status,
    deltaXph = delta,
  }
end

function NS.GetCoachSegments(includeCurrent, now)
  local coach = getCoachRuntime(now or GetTime())
  local result = {}
  for i = 1, #coach.segments do
    result[#result + 1] = copyTable(coach.segments[i])
  end
  if includeCurrent then
    local current = buildCurrentSegment(now or GetTime())
    if current then
      result[#result + 1] = current
    end
  end
  return result
end

function NS.GetCoachStatus(now)
  local at = now or GetTime()
  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(at) or nil
  local goal = NS.GetCoachGoalStatus(snapshot)
  local segments = NS.GetCoachSegments(true, at)
  local bestSegment = nil
  for i = 1, #segments do
    local segment = segments[i]
    if segment.xpGained and segment.xpGained > 0 then
      if not bestSegment or (segment.avgXph or 0) > (bestSegment.avgXph or 0) then
        bestSegment = segment
      end
    end
  end

  local currentSegment = segments[#segments]
  if currentSegment and not currentSegment.isCurrent then
    currentSegment = nil
  end

  local recent = {}
  for i = #segments, math.max(1, #segments - 4), -1 do
    recent[#recent + 1] = segments[i]
  end

  return {
    snapshot = snapshot,
    goal = goal,
    alerts = NS.GetCoachAlerts(4),
    bestSegment = bestSegment,
    currentSegment = currentSegment,
    recentSegments = recent,
    lastRecap = DingTimerDB and DingTimerDB.coach and DingTimerDB.coach.lastRecap or nil,
  }
end

function NS.MaybeRunCoach(now)
  local at = now or GetTime()
  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(at) or nil
  if not snapshot or snapshot.sessionXP <= 0 then
    return
  end

  local coach = getCoachRuntime(at)
  local config = NS.EnsureCoachConfig()
  if (at - (coach.lastXPAt or at)) >= config.idleSeconds then
    NS.PushCoachAlert(
      "idle",
      string.format("No XP for %s. Route change or break?", NS.fmtTime(at - (coach.lastXPAt or at))),
      at
    )
  end

  local goal = NS.GetCoachGoalStatus(snapshot)
  local benchmark = goal.benchmarkXph or ((snapshot.sessionXph and snapshot.sessionXph > 0) and snapshot.sessionXph or nil)
  if benchmark and benchmark > 0 and snapshot.currentXph > 0 then
    local threshold = benchmark * (1 - (config.paceDropPct / 100))
    if snapshot.currentXph < threshold then
      NS.PushCoachAlert(
        "pace_drop",
        string.format(
          "Pace dropped to %s XP/hr against a %s XP/hr benchmark.",
          NS.FormatNumber(NS.Round(snapshot.currentXph)),
          NS.FormatNumber(NS.Round(benchmark))
        ),
        at
      )
    end
  end
end

function NS.BuildCoachSummary(record)
  if not record then
    return nil
  end

  local bestSegment = nil
  local segments = record.segments or {}
  for i = 1, #segments do
    local segment = segments[i]
    if segment.xpGained and segment.xpGained > 0 then
      if not bestSegment or (segment.avgXph or 0) > (bestSegment.avgXph or 0) then
        bestSegment = segment
      end
    end
  end

  local goal = normalizeGoal((DingTimerDB and DingTimerDB.coach and DingTimerDB.coach.goal) or DEFAULTS.goal)
  local headline = string.format(
    "%s XP in %s at %s XP/hr.",
    NS.FormatNumber(record.xpGained or 0),
    NS.fmtTime(record.durationSec or 0),
    NS.FormatNumber(NS.Round(record.avgXph or 0))
  )

  local detail = string.format(
    "Ended by %s with %s net and %d segment%s.",
    getReasonLabel(record.reason),
    NS.fmtMoney(record.moneyNetCopper or 0),
    #segments,
    (#segments == 1) and "" or "s"
  )

  local segmentLine = bestSegment and string.format(
    "Best segment: %s at %s XP/hr.",
    safeString(bestSegment.zone, "Unknown"),
    NS.FormatNumber(NS.Round(bestSegment.avgXph or 0))
  ) or "No completed coach segments yet."

  local goalLine
  if goal == "off" then
    goalLine = "Coach goal was disabled."
  elseif goal == "ding" then
    goalLine = "Goal was to keep pushing toward the next ding."
  else
    goalLine = "Goal preset: " .. goal .. "."
  end

  return {
    headline = headline,
    detail = detail,
    segmentLine = segmentLine,
    goalLine = goalLine,
    goal = goal,
    recordedAt = record.endedAt or GetTime(),
  }
end

function NS.StoreCoachSummary(summary, isPending)
  if not summary then
    return
  end
  local config = NS.EnsureCoachConfig()
  DingTimerDB.coach.lastRecap = copyTable(summary)
  if isPending then
    DingTimerDB.coach.pendingRecap = copyTable(summary)
    DingTimerDB.coach.pendingRecap.profileKey = NS.GetProfileKey and NS.GetProfileKey() or nil
  else
    DingTimerDB.coach.pendingRecap = nil
  end
end

function NS.DeliverCoachSummary(summary)
  if not summary then
    NS.chat(NS.C.base .. "[COACH]" .. NS.C.r .. " No recap is available yet.")
    return false
  end
  NS.chat(NS.C.base .. "[COACH]" .. NS.C.r .. " " .. safeString(summary.headline, ""))
  NS.chat("  " .. safeString(summary.detail, ""))
  NS.chat("  " .. safeString(summary.segmentLine, ""))
  NS.chat("  " .. safeString(summary.goalLine, ""))
  return true
end

function NS.DeliverPendingCoachSummary()
  local coach = DingTimerDB and DingTimerDB.coach or nil
  local pending = coach and coach.pendingRecap or nil
  if not pending then
    return false
  end
  local expectedProfile = pending.profileKey
  if expectedProfile and NS.GetProfileKey and expectedProfile ~= NS.GetProfileKey() then
    return false
  end
  coach.pendingRecap = nil
  return NS.DeliverCoachSummary(pending)
end

function NS.ShowCoachRecap(now)
  local summary = nil
  local snapshot = NS.GetSessionSnapshot and NS.GetSessionSnapshot(now or GetTime()) or nil
  if snapshot and snapshot.sessionXP > 0 then
    local preview = {
      durationSec = snapshot.sessionElapsed,
      xpGained = snapshot.sessionXP,
      avgXph = snapshot.sessionXph,
      moneyNetCopper = snapshot.sessionMoney,
      reason = "MANUAL_SPLIT",
      endedAt = now or GetTime(),
      segments = NS.GetCoachSegments(true, now or GetTime()),
    }
    summary = NS.BuildCoachSummary(preview)
  end
  if not summary and DingTimerDB and DingTimerDB.coach then
    summary = DingTimerDB.coach.lastRecap
  end
  return NS.DeliverCoachSummary(summary)
end
