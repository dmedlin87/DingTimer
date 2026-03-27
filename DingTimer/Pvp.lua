local ADDON, NS = ...

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_huge = math.huge
local string_format = string.format

local PVP_PREFIX = (NS.C and NS.C.base or "") .. "[PVP]" .. (NS.C and NS.C.r or "")
local DEFAULT_RESUME_MAX_AGE = 900
local MATCH_GRACE_SECONDS = 15
local RECENT_LIMIT = 4

---@class DingTimerPvpMatch
---@field startedAt number
---@field zone string
---@field honorGained number
---@field hkGained number
---@field exitedAt number|nil
---@field graceEndsAt number|nil

---@class DingTimerPvpMatchSummary
---@field zone string
---@field startedAt number
---@field endedAt number
---@field durationSec number
---@field honorGained number
---@field hkGained number
---@field reason string
---@field avgHonorPerHour number
---@field avgHKPerHour number

---@class DingTimerPvpRuntime
---@field sessionStartTime number
---@field sessionHonor number
---@field sessionHKs number
---@field honorEvents table[]
---@field hkEvents table[]
---@field windowHonor number
---@field windowHK number
---@field baselineHonor number
---@field baselineHK number
---@field currentHonor number
---@field currentHK number
---@field lastHonor number|nil
---@field lastHK number|nil
---@field honorCap number
---@field apiAvailable boolean
---@field apiMessage string|nil
---@field enteredByAuto boolean
---@field activeMatch DingTimerPvpMatch|nil
---@field recentMatches DingTimerPvpMatchSummary[]
---@field noticeLog table[]
---@field queuedMessages string[]
---@field lastMilestone number|nil

---@class DingTimerPvpResume
---@field savedAt number|nil
---@field sessionStartTime number|nil
---@field sessionHonor number|nil
---@field sessionHKs number|nil
---@field honorEvents table[]|nil
---@field hkEvents table[]|nil
---@field windowHonor number|nil
---@field windowHK number|nil
---@field baselineHonor number|nil
---@field baselineHK number|nil
---@field currentHonor number|nil
---@field currentHK number|nil
---@field lastHonor number|nil
---@field lastHK number|nil
---@field honorCap number|nil
---@field apiAvailable boolean|nil
---@field apiMessage string|nil
---@field enteredByAuto boolean|nil
---@field activeMatch DingTimerPvpMatch|nil
---@field recentMatches DingTimerPvpMatchSummary[]|nil
---@field noticeLog table[]|nil
---@field queuedMessages string[]|nil
---@field lastMilestone number|nil

local REASON_LABELS = {
  AUTO_BG_ENTER = "Battleground entered",
  AUTO_BG_EXIT = "Battleground exit",
  LOGOUT = "Logout",
  MANUAL_RESET = "Reset",
  MANUAL_TOGGLE = "Manual toggle",
  MODE_SWITCH_TO_PVP = "Switched to PvP mode",
  MODE_SWITCH_TO_XP = "Switched to XP mode",
}

local function copyTable(source)
  if type(source) ~= "table" then
    return source
  end
  local out = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      out[key] = copyTable(value)
    else
      out[key] = value
    end
  end
  return out
end

local function safeString(value, fallback)
  return NS.safeString and NS.safeString(value, fallback) or fallback
end

local function normalizeKeep(n)
  if NS.NormalizeKeepSessions then
    return NS.NormalizeKeepSessions(n)
  end
  local value = math_floor(tonumber(n) or 30)
  if value < 5 then
    value = 5
  elseif value > 100 then
    value = 100
  end
  return value
end

local function currentProfileKey()
  if NS.GetProfileKey then
    return NS.GetProfileKey()
  end
  return "Unknown:Unknown:UNKNOWN"
end

local function getReasonLabel(reason)
  return REASON_LABELS[reason] or safeString(reason, "PvP session")
end

local function readWholeNumber(value)
  local numeric = tonumber(value)
  if numeric and not NS.IsInvalidNumber(numeric) then
    return math_floor(numeric + 0.5)
  end
  return nil
end

local function readCurrentHonor()
  if type(GetHonorCurrency) == "function" then
    return readWholeNumber(GetHonorCurrency())
  end
  return nil
end

local function readHonorCap()
  if type(GetMaxHonorCurrency) == "function" then
    local value = readWholeNumber(GetMaxHonorCurrency())
    if value and value > 0 then
      return value
    end
  end
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  return math_floor((settings and settings.honorCap) or 75000)
end

local function readLifetimeHKs()
  if type(GetPVPLifetimeStats) == "function" then
    local honorableKills = readWholeNumber(GetPVPLifetimeStats())
    if honorableKills then
      return honorableKills
    end
  end
  if type(GetLifetimeHonorableKills) == "function" then
    local honorableKills = readWholeNumber(GetLifetimeHonorableKills())
    if honorableKills then
      return honorableKills
    end
  end
  return nil
end

local function readPvpTotals()
  local honor = readCurrentHonor()
  local hks = readLifetimeHKs()
  if honor == nil then
    return nil, nil, nil, "Honor API unavailable"
  end
  if hks == nil then
    return nil, nil, nil, "HK API unavailable"
  end
  return honor, hks, readHonorCap(), nil
end

local function isBattlegroundInstance()
  if type(IsInInstance) ~= "function" then
    return false
  end
  local inInstance, instanceType = IsInInstance()
  return inInstance == true and instanceType == "pvp"
end

local function getZone()
  if GetZoneText then
    return safeString(GetZoneText(), "Unknown")
  end
  return "Unknown"
end

local function refreshPvpViews()
  if NS.RefreshMainWindowSubtitle then
    NS.RefreshMainWindowSubtitle()
  end
  if NS.RefreshStatsWindow then
    NS.RefreshStatsWindow()
  end
  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end
  if NS.RefreshSettingsPanel then
    NS.RefreshSettingsPanel()
  end
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD()
  end
end

---@return DingTimerPvpRuntime
local function getRuntime(now)
  NS.state = NS.state or {}
  NS.state.pvp = NS.state.pvp or {
    sessionStartTime = now or GetTime(),
    sessionHonor = 0,
    sessionHKs = 0,
    honorEvents = {},
    hkEvents = {},
    windowHonor = 0,
    windowHK = 0,
    baselineHonor = 0,
    baselineHK = 0,
    currentHonor = 0,
    currentHK = 0,
    lastHonor = nil,
    lastHK = nil,
    honorCap = 75000,
    apiAvailable = false,
    apiMessage = "Honor API unavailable",
    enteredByAuto = false,
    activeMatch = nil,
    recentMatches = {},
    noticeLog = {},
    queuedMessages = {},
    lastMilestone = nil,
  }
  return NS.state.pvp
end

---@return DingTimerPvpRuntime
local function clearRuntime(now)
  local state = getRuntime(now)
  state.sessionStartTime = now or GetTime()
  state.sessionHonor = 0
  state.sessionHKs = 0
  state.honorEvents = {}
  state.hkEvents = {}
  state.windowHonor = 0
  state.windowHK = 0
  state.baselineHonor = 0
  state.baselineHK = 0
  state.currentHonor = 0
  state.currentHK = 0
  state.lastHonor = nil
  state.lastHK = nil
  state.honorCap = readHonorCap()
  state.apiAvailable = false
  state.apiMessage = "Honor API unavailable"
  state.enteredByAuto = false
  state.activeMatch = nil
  state.recentMatches = {}
  state.noticeLog = {}
  state.queuedMessages = {}
  state.lastMilestone = nil
  return state
end

local function ensurePvpStore(createIfMissing)
  if not DingTimerDB then
    return nil
  end

  DingTimerDB.pvp = DingTimerDB.pvp or {}
  DingTimerDB.pvp.settings = DingTimerDB.pvp.settings or {}
  if NS.ValidatePvpConfig then
    NS.ValidatePvpConfig(DingTimerDB.pvp.settings)
  end
  DingTimerDB.pvp.profiles = DingTimerDB.pvp.profiles or {}

  local key = currentProfileKey()
  local profile = DingTimerDB.pvp.profiles[key]
  if not profile and createIfMissing then
    profile = { sessions = {} }
    DingTimerDB.pvp.profiles[key] = profile
  end
  if profile then
    profile.sessions = profile.sessions or {}
  end
  return profile
end

local function pushRecent(list, entry)
  if not entry then
    return
  end
  list[#list + 1] = entry
  local overflow = #list - RECENT_LIMIT
  if overflow <= 0 then
    return
  end
  for i = 1, RECENT_LIMIT do
    list[i] = list[i + overflow]
  end
  for i = #list, RECENT_LIMIT + 1, -1 do
    list[i] = nil
  end
end

local function logNotice(text, now)
  if not text or text == "" then
    return
  end
  local state = getRuntime(now)
  pushRecent(state.noticeLog, {
    at = now or GetTime(),
    text = text,
  })
end

local function deliverMessage(text, now)
  if not text or text == "" then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    local state = getRuntime(now)
    pushRecent(state.queuedMessages, text)
    return
  end
  NS.chat(PVP_PREFIX .. " " .. text)
  logNotice(text, now)
end

function NS.FlushPvpNotifications(now)
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  local state = getRuntime(now)
  if #state.queuedMessages == 0 then
    return false
  end
  for i = 1, #state.queuedMessages do
    local text = state.queuedMessages[i]
    NS.chat(PVP_PREFIX .. " " .. text)
    logNotice(text, now)
  end
  state.queuedMessages = {}
  return true
end

local function beginMatch(now, zone)
  local state = getRuntime(now)
  state.activeMatch = {
    startedAt = now,
    zone = zone or getZone(),
    honorGained = 0,
    hkGained = 0,
    exitedAt = nil,
    graceEndsAt = nil,
  }
end

local function finalizeMatch(now, forcedReason)
  local state = getRuntime(now)
  local match = state.activeMatch
  if not match then
    return nil
  end

  local endedAt = match.exitedAt or now or GetTime()
  local durationSec = math_max(1, endedAt - (match.startedAt or endedAt))
  local summary = {
    zone = safeString(match.zone, "Unknown"),
    startedAt = match.startedAt,
    endedAt = endedAt,
    durationSec = durationSec,
    honorGained = match.honorGained or 0,
    hkGained = match.hkGained or 0,
    reason = forcedReason or "MATCH_COMPLETE",
    avgHonorPerHour = ((match.honorGained or 0) / durationSec) * 3600,
    avgHKPerHour = ((match.hkGained or 0) / durationSec) * 3600,
  }

  state.activeMatch = nil
  pushRecent(state.recentMatches, summary)

  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if settings and settings.matchRecap then
    deliverMessage(string_format(
      "%s recap: %s Honor, %s HKs, %s Honor/hr over %s.",
      summary.zone,
      NS.FormatNumber(summary.honorGained or 0),
      NS.FormatNumber(summary.hkGained or 0),
      NS.FormatNumber(NS.Round(summary.avgHonorPerHour or 0)),
      NS.fmtTime(summary.durationSec or 0)
    ), now)
  end

  return summary
end

local function updateMatchState(now)
  local state = getRuntime(now)
  local inBattleground = isBattlegroundInstance()
  local zone = getZone()
  local activeMatch = state.activeMatch

  if inBattleground then
    if not activeMatch then
      beginMatch(now, zone)
    else
      activeMatch.zone = zone
      activeMatch.exitedAt = nil
      activeMatch.graceEndsAt = nil
    end
    return
  end

  if activeMatch and not activeMatch.exitedAt then
    activeMatch.exitedAt = now
    activeMatch.graceEndsAt = now + MATCH_GRACE_SECONDS
  end
end

local function maybeFinalizeGraceMatch(now)
  local state = getRuntime(now)
  local match = state.activeMatch
  if match and match.graceEndsAt and now >= match.graceEndsAt then
    finalizeMatch(now, "MATCH_EXIT")
    return true
  end
  return false
end

local function maybeAnnounceMilestone(previousHonor, currentHonor, now)
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings or not settings.milestoneAnnouncements then
    return
  end
  local step = math_max(100, tonumber(settings.milestoneStep) or 5000)
  local previousStep = math_floor((previousHonor or 0) / step)
  local currentStep = math_floor((currentHonor or 0) / step)
  if currentStep <= previousStep then
    return
  end
  deliverMessage("Honor milestone reached: " .. NS.FormatNumber(currentStep * step) .. ".", now)
  local state = getRuntime(now)
  state.lastMilestone = currentStep * step
end

local function startFreshSession(now, enteredByAuto)
  local state = clearRuntime(now)
  state.enteredByAuto = enteredByAuto == true
  state.honorCap = readHonorCap()
  local honor, hks, honorCap, err = readPvpTotals()
  if honor ~= nil and hks ~= nil then
    state.apiAvailable = true
    state.apiMessage = nil
    state.baselineHonor = honor
    state.baselineHK = hks
    state.currentHonor = honor
    state.currentHK = hks
    state.lastHonor = honor
    state.lastHK = hks
    state.honorCap = honorCap or state.honorCap
  else
    state.apiAvailable = false
    state.apiMessage = err or "Honor API unavailable"
  end
  if isBattlegroundInstance() then
    beginMatch(now, getZone())
  end
  return state
end

local function setActiveMode(mode)
  DingTimerDB.activeMode = (mode == "pvp") and "pvp" or "xp"
end

function NS.GetActiveMode()
  if DingTimerDB and DingTimerDB.activeMode == "pvp" then
    return "pvp"
  end
  return "xp"
end

function NS.IsPvpMode()
  return NS.GetActiveMode() == "pvp"
end

function NS.GetPvpProfileStore(createIfMissing)
  return ensurePvpStore(createIfMissing)
end

function NS.TrimPvpSessions(profile, keepN)
  if not profile or type(profile.sessions) ~= "table" then
    return
  end
  local keep = normalizeKeep(keepN or (DingTimerDB and DingTimerDB.pvp and DingTimerDB.pvp.settings and DingTimerDB.pvp.settings.keepSessions) or 30)
  local sessions = profile.sessions
  local overflow = #sessions - keep
  if overflow <= 0 then
    return
  end
  local len = #sessions
  for i = 1, keep do
    sessions[i] = sessions[i + overflow]
  end
  for i = len, keep + 1, -1 do
    sessions[i] = nil
  end
end

function NS.ClearCurrentPvpHistory()
  local profile = ensurePvpStore(true)
  if not profile then
    return false
  end
  profile.sessions = {}
  refreshPvpViews()
  return true
end

function NS.SetPvpKeepSessions(count)
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings then
    return false, "PvP settings are unavailable."
  end
  settings.keepSessions = normalizeKeep(count)
  local profile = ensurePvpStore(true)
  NS.TrimPvpSessions(profile, settings.keepSessions)
  refreshPvpViews()
  return true, settings.keepSessions
end

function NS.SetPvpHistoryView(view)
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings then
    return false
  end
  settings.historyView = (view == "pvp") and "pvp" or "xp"
  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end
  return true
end

function NS.GetPvpHistoryView()
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  return (settings and settings.historyView == "pvp") and "pvp" or "xp"
end

function NS.SetPvpGoal(value)
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings then
    return false, "PvP settings are unavailable."
  end

  local lower = type(value) == "string" and value:lower() or value
  if lower == "off" then
    settings.goalMode = "off"
    settings.customGoalHonor = nil
  elseif lower == "cap" then
    settings.goalMode = "cap"
    settings.customGoalHonor = nil
  else
    local numeric = tonumber(value)
    if not numeric or NS.IsInvalidNumber(numeric) or numeric < 0 then
      return false, "Use '/ding pvp goal off', '/ding pvp goal cap', or a positive honor value."
    end
    settings.goalMode = "custom"
    settings.customGoalHonor = math_floor(numeric)
  end

  refreshPvpViews()
  return true, settings.goalMode
end

function NS.GetPvpGoalLabel()
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings then
    return "Unavailable"
  end
  if settings.goalMode == "off" then
    return "Off"
  end
  if settings.goalMode == "cap" then
    return "Cap"
  end
  return NS.FormatNumber(settings.customGoalHonor or 0)
end

function NS.SetPvpAutoSwitch(enabled)
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  if not settings then
    return false, "PvP settings are unavailable."
  end
  settings.autoSwitchBattlegrounds = enabled == true
  refreshPvpViews()
  return true, settings.autoSwitchBattlegrounds
end

function NS.BuildPvpSummary(record)
  if not record then
    return nil
  end
  local goalLine = "Goal was disabled."
  if record.goalMode == "cap" then
    goalLine = "Goal was Honor cap."
  elseif record.goalMode == "custom" then
    goalLine = "Goal target: " .. NS.FormatNumber(record.goalTarget or 0) .. " Honor."
  end

  return {
    headline = string_format(
      "%s Honor and %s HKs in %s at %s Honor/hr.",
      NS.FormatNumber(record.honorGained or 0),
      NS.FormatNumber(record.hkGained or 0),
      NS.fmtTime(record.durationSec or 0),
      NS.FormatNumber(NS.Round(record.avgHonorPerHour or 0))
    ),
    detail = string_format(
      "Ended by %s in %s. HK pace: %s / hr.",
      getReasonLabel(record.reason),
      safeString(record.zone, "Unknown"),
      NS.FormatNumber(NS.Round(record.avgHKPerHour or 0))
    ),
    segmentLine = string_format(
      "Honor %s -> %s.",
      NS.FormatNumber(record.startHonor or 0),
      NS.FormatNumber(record.endHonor or 0)
    ),
    goalLine = goalLine,
    recordedAt = record.endedAt or GetTime(),
  }
end

local function storePvpSummary(summary)
  if not summary or not DingTimerDB or not DingTimerDB.pvp then
    return
  end
  DingTimerDB.pvp.lastRecap = copyTable(summary)
end

function NS.ShowPvpRecap(now)
  local summary = nil
  local snapshot = NS.GetPvpSnapshot and NS.GetPvpSnapshot(now or GetTime()) or nil
  if snapshot and snapshot.sessionHonor > 0 then
    summary = NS.BuildPvpSummary({
      startedAt = snapshot.sessionStartTime,
      endedAt = now or GetTime(),
      durationSec = snapshot.sessionElapsed,
      honorGained = snapshot.sessionHonor,
      hkGained = snapshot.sessionHKs,
      avgHonorPerHour = snapshot.sessionHonorPerHour,
      avgHKPerHour = snapshot.sessionHKPerHour,
      zone = snapshot.zone,
      reason = "MANUAL_TOGGLE",
      startHonor = snapshot.startHonor,
      endHonor = snapshot.currentHonor,
      goalMode = snapshot.goalMode,
      goalTarget = snapshot.targetHonor,
    })
  end
  if not summary and DingTimerDB and DingTimerDB.pvp then
    summary = DingTimerDB.pvp.lastRecap
  end
  if not summary then
    NS.chat(PVP_PREFIX .. " No PvP recap is available yet.")
    return false
  end
  NS.chat(PVP_PREFIX .. " " .. safeString(summary.headline, ""))
  NS.chat("  " .. safeString(summary.detail, ""))
  NS.chat("  " .. safeString(summary.segmentLine, ""))
  NS.chat("  " .. safeString(summary.goalLine, ""))
  return true
end

function NS.RecordPvpSession(reason, now)
  if not DingTimerDB then
    return nil
  end
  local at = now or GetTime()
  local state = getRuntime(at)
  local durationSec = math_max(1, at - (state.sessionStartTime or at))
  if (state.sessionHonor or 0) <= 0 and (state.sessionHKs or 0) <= 0 then
    return nil
  end

  local snapshot = NS.GetPvpSnapshot and NS.GetPvpSnapshot(at) or nil
  local profile = ensurePvpStore(true)
  if not profile then
    return nil
  end

  local record = {
    id = string_format("%d-%d", math_floor(at + 0.5), #profile.sessions + 1),
    startedAt = state.sessionStartTime or at,
    endedAt = at,
    durationSec = durationSec,
    honorGained = state.sessionHonor or 0,
    hkGained = state.sessionHKs or 0,
    avgHonorPerHour = ((state.sessionHonor or 0) / durationSec) * 3600,
    avgHKPerHour = ((state.sessionHKs or 0) / durationSec) * 3600,
    zone = snapshot and snapshot.zone or getZone(),
    reason = reason or "MANUAL_RESET",
    startHonor = snapshot and snapshot.startHonor or state.baselineHonor or 0,
    endHonor = snapshot and snapshot.currentHonor or state.currentHonor or 0,
    goalMode = snapshot and snapshot.goalMode or "cap",
    goalTarget = snapshot and snapshot.targetHonor or nil,
  }

  profile.sessions[#profile.sessions + 1] = record
  NS.TrimPvpSessions(profile)

  local summary = NS.BuildPvpSummary(record)
  record.summary = summary
  storePvpSummary(summary)
  if NS.RefreshInsightsWindow then
    NS.RefreshInsightsWindow()
  end
  return record
end

function NS.EnterPvpMode(reason, enteredByAuto, now)
  local at = now or GetTime()
  if NS.IsPvpMode() then
    local state = getRuntime(at)
    state.enteredByAuto = enteredByAuto == true
    updateMatchState(at)
    refreshPvpViews()
    return true
  end

  setActiveMode("pvp")
  if NS.RecordSession then
    NS.RecordSession(reason or "MODE_SWITCH_TO_PVP")
  end
  if NS.resetXPState then
    NS.resetXPState()
  end
  startFreshSession(at, enteredByAuto)
  if NS.InvalidateTickCache then
    NS.InvalidateTickCache()
  end
  refreshPvpViews()
  return true
end

function NS.ExitPvpMode(reason, now)
  local at = now or GetTime()
  if not NS.IsPvpMode() then
    return true
  end

  finalizeMatch(at, "MODE_SWITCH_TO_XP")
  NS.RecordPvpSession(reason or "MODE_SWITCH_TO_XP", at)
  setActiveMode("xp")
  if DingTimerDB and DingTimerDB.pvp then
    DingTimerDB.pvp.resume = nil
  end
  clearRuntime(at)
  if NS.resetXPState then
    NS.resetXPState()
  end
  if NS.InvalidateTickCache then
    NS.InvalidateTickCache()
  end
  refreshPvpViews()
  return true
end

function NS.TogglePvpMode(now)
  if NS.IsPvpMode() then
    return NS.ExitPvpMode("MODE_SWITCH_TO_XP", now)
  end
  return NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, now)
end

function NS.ResetPvpSession(reason, now)
  local at = now or GetTime()
  finalizeMatch(at, "MANUAL_RESET")
  NS.RecordPvpSession(reason or "MANUAL_RESET", at)
  startFreshSession(at, false)
  if NS.GraphReset then
    NS.GraphReset()
  end
  refreshPvpViews()
  return true
end

function NS.RefreshPvpSnapshot(now, source)
  local at = now or GetTime()
  local state = getRuntime(at)
  updateMatchState(at)

  local honor, hks, honorCap, err = readPvpTotals()
  if honor == nil or hks == nil then
    state.apiAvailable = false
    state.apiMessage = err or "Honor API unavailable"
    maybeFinalizeGraceMatch(at)
    return false, state.apiMessage
  end

  state.apiAvailable = true
  state.apiMessage = nil
  state.honorCap = honorCap or state.honorCap or readHonorCap()
  state.currentHonor = honor
  state.currentHK = hks

  if state.lastHonor == nil or state.lastHK == nil then
    state.baselineHonor = honor
    state.baselineHK = hks
    state.lastHonor = honor
    state.lastHK = hks
    maybeFinalizeGraceMatch(at)
    return true
  end

  local previousHonor = state.lastHonor or honor
  local previousHK = state.lastHK or hks
  local honorDelta = honor - previousHonor
  local hkDelta = hks - previousHK
  local windowSeconds = (DingTimerDB and DingTimerDB.windowSeconds) or 600

  if NS.PruneRollingEvents then
    NS.PruneRollingEvents(state.honorEvents, at, windowSeconds, state, "windowHonor", "honor")
    NS.PruneRollingEvents(state.hkEvents, at, windowSeconds, state, "windowHK", "hk")
  end

  if honorDelta > 0 then
    state.sessionHonor = (state.sessionHonor or 0) + honorDelta
    state.honorEvents[#state.honorEvents + 1] = { t = at, honor = honorDelta }
    state.windowHonor = (state.windowHonor or 0) + honorDelta
    local activeMatch = state.activeMatch
    if activeMatch then
      activeMatch.honorGained = (activeMatch.honorGained or 0) + honorDelta
    end
    if NS.GraphFeedXP then
      NS.GraphFeedXP(honorDelta, at)
    end
    maybeAnnounceMilestone(previousHonor, honor, at)
  end

  if hkDelta > 0 then
    state.sessionHKs = (state.sessionHKs or 0) + hkDelta
    state.hkEvents[#state.hkEvents + 1] = { t = at, hk = hkDelta }
    state.windowHK = (state.windowHK or 0) + hkDelta
    local activeMatch = state.activeMatch
    if activeMatch then
      activeMatch.hkGained = (activeMatch.hkGained or 0) + hkDelta
    end
  end

  state.lastHonor = honor
  state.lastHK = hks

  maybeFinalizeGraceMatch(at)
  return true
end

function NS.HandlePvpWorldStateChange(now)
  local at = now or GetTime()
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  updateMatchState(at)

  if settings and settings.autoSwitchBattlegrounds and not NS.IsPvpMode() and isBattlegroundInstance() then
    NS.EnterPvpMode("AUTO_BG_ENTER", true, at)
    NS.RefreshPvpSnapshot(at, "AUTO_BG_ENTER")
    return true
  end

  return false
end

function NS.HandlePvpEvent(source, now)
  local at = now or GetTime()
  if NS.IsPvpMode() then
    return NS.RefreshPvpSnapshot(at, source)
  end
  return false
end

function NS.RunPvpHeartbeat(now)
  local at = now or GetTime()
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or nil
  updateMatchState(at)
  local finalized = maybeFinalizeGraceMatch(at)
  NS.FlushPvpNotifications(at)

  if NS.IsPvpMode()
    and settings and settings.autoSwitchBattlegrounds
    and not isBattlegroundInstance()
    and finalized
    and not getRuntime(at).activeMatch
    and getRuntime(at).enteredByAuto then
    NS.ExitPvpMode("AUTO_BG_EXIT", at)
  end
end

function NS.PersistPvpResume(now)
  if not DingTimerDB or not DingTimerDB.pvp or not NS.IsPvpMode() then
    return false
  end
  local at = now or GetTime()
  local state = getRuntime(at)
  DingTimerDB.pvp.resume = {
    savedAt = at,
    sessionStartTime = state.sessionStartTime,
    sessionHonor = state.sessionHonor,
    sessionHKs = state.sessionHKs,
    honorEvents = copyTable(state.honorEvents),
    hkEvents = copyTable(state.hkEvents),
    windowHonor = state.windowHonor,
    windowHK = state.windowHK,
    baselineHonor = state.baselineHonor,
    baselineHK = state.baselineHK,
    currentHonor = state.currentHonor,
    currentHK = state.currentHK,
    lastHonor = state.lastHonor,
    lastHK = state.lastHK,
    honorCap = state.honorCap,
    apiAvailable = state.apiAvailable,
    apiMessage = state.apiMessage,
    enteredByAuto = state.enteredByAuto,
    activeMatch = copyTable(state.activeMatch),
    recentMatches = copyTable(state.recentMatches),
    noticeLog = copyTable(state.noticeLog),
    queuedMessages = copyTable(state.queuedMessages),
    lastMilestone = state.lastMilestone,
  }
  return true
end

function NS.RestorePvpResumeIfAvailable(now)
  local pvpStore = DingTimerDB and DingTimerDB.pvp
  local resume = pvpStore and pvpStore.resume
  if not pvpStore or not resume then
    setActiveMode("xp")
    return false
  end

  local at = now or GetTime()
  ---@cast resume DingTimerPvpResume
  if not resume.savedAt or (at - resume.savedAt) > DEFAULT_RESUME_MAX_AGE then
    pvpStore.resume = nil
    setActiveMode("xp")
    return false
  end

  local state = clearRuntime(at)
  state.sessionStartTime = tonumber(resume.sessionStartTime) or at
  state.sessionHonor = tonumber(resume.sessionHonor) or 0
  state.sessionHKs = tonumber(resume.sessionHKs) or 0
  state.honorEvents = copyTable(resume.honorEvents or {})
  state.hkEvents = copyTable(resume.hkEvents or {})
  state.windowHonor = tonumber(resume.windowHonor) or 0
  state.windowHK = tonumber(resume.windowHK) or 0
  state.baselineHonor = tonumber(resume.baselineHonor) or 0
  state.baselineHK = tonumber(resume.baselineHK) or 0
  state.currentHonor = tonumber(resume.currentHonor) or 0
  state.currentHK = tonumber(resume.currentHK) or 0
  state.lastHonor = tonumber(resume.lastHonor)
  state.lastHK = tonumber(resume.lastHK)
  state.honorCap = tonumber(resume.honorCap) or readHonorCap()
  state.apiAvailable = resume.apiAvailable == true
  state.apiMessage = resume.apiMessage
  state.enteredByAuto = resume.enteredByAuto == true
  ---@type DingTimerPvpMatch|nil
  local restoredMatch = copyTable(resume.activeMatch)
  state.activeMatch = restoredMatch
  ---@type DingTimerPvpMatchSummary[]
  local recentMatches = copyTable(resume.recentMatches or {})
  state.recentMatches = recentMatches
  state.noticeLog = copyTable(resume.noticeLog or {})
  state.queuedMessages = copyTable(resume.queuedMessages or {})
  state.lastMilestone = tonumber(resume.lastMilestone)
  setActiveMode("pvp")
  pvpStore.resume = nil
  NS.RefreshPvpSnapshot(at, "RESTORE")
  refreshPvpViews()
  return true
end

function NS.GetPvpSnapshot(now)
  local at = now or GetTime()
  local state = getRuntime(at)
  local window = (DingTimerDB and DingTimerDB.windowSeconds) or 600
  local honorRate = NS.ComputeRollingRateDetails and NS.ComputeRollingRateDetails(
    state.honorEvents, at, state.sessionStartTime, window, "honor", state, "windowHonor"
  ) or { rawXph = 0 }
  local hkRate = NS.ComputeRollingRateDetails and NS.ComputeRollingRateDetails(
    state.hkEvents, at, state.sessionStartTime, window, "hk", state, "windowHK"
  ) or { rawXph = 0 }
  local sessionElapsed = math_max(1, at - (state.sessionStartTime or at))
  local sessionHonorPerHour = ((state.sessionHonor or 0) / sessionElapsed) * 3600
  local sessionHKPerHour = ((state.sessionHKs or 0) / sessionElapsed) * 3600
  local settings = NS.EnsurePvpConfig and NS.EnsurePvpConfig(DingTimerDB) or {}
  local goalMode = settings.goalMode or "cap"
  local targetHonor = nil
  local goalLabel = "Goal Off"
  local goalHeadline = "to goal"
  local ttg = nil
  local ttgText = "Set a goal"
  local goalStatus = "Set a PvP goal."

  if goalMode == "cap" then
    targetHonor = state.honorCap or settings.honorCap or 75000
    goalLabel = "Honor Cap"
    goalHeadline = "to cap"
  elseif goalMode == "custom" then
    targetHonor = settings.customGoalHonor
    goalLabel = "Custom Goal"
    goalHeadline = "to goal"
  end

  if not state.apiAvailable then
    ttgText = "Unavailable"
    goalStatus = state.apiMessage or "Honor tracking unavailable."
  elseif targetHonor then
    local remainingHonor = math_max(0, (targetHonor or 0) - (state.currentHonor or 0))
    if remainingHonor <= 0 then
      if goalMode == "cap" then
        ttgText = "Capped"
        goalStatus = "Honor cap reached."
      else
        ttgText = "Goal Reached"
        goalStatus = "Custom Honor goal reached."
      end
      ttg = 0
    elseif honorRate.rawXph and honorRate.rawXph > 0 then
      ttg = (remainingHonor / honorRate.rawXph) * 3600
      ttgText = NS.fmtTime(ttg)
      goalStatus = string_format(
        "%s Honor remaining toward %s.",
        NS.FormatNumber(remainingHonor),
        NS.FormatNumber(targetHonor or 0)
      )
    else
      ttg = math_huge
      ttgText = "No Pace"
      goalStatus = "Earn Honor to estimate time to goal."
    end
  end

  local match = state.activeMatch
  local matchStatus = "No active battleground match."
  if match then
    if match.graceEndsAt then
      matchStatus = string_format(
        "Post-match grace window in %s.",
        NS.fmtTime(math_max(1, match.graceEndsAt - at))
      )
    else
      matchStatus = string_format(
        "Active match: %s  |  %s Honor  |  %s HKs",
        safeString(match.zone, "Unknown"),
        NS.FormatNumber(match.honorGained or 0),
        NS.FormatNumber(match.hkGained or 0)
      )
    end
  end

  return {
    now = at,
    sessionStartTime = state.sessionStartTime or at,
    sessionElapsed = sessionElapsed,
    sessionHonor = state.sessionHonor or 0,
    sessionHKs = state.sessionHKs or 0,
    currentHonor = state.currentHonor or 0,
    currentHK = state.currentHK or 0,
    startHonor = state.baselineHonor or 0,
    startHK = state.baselineHK or 0,
    currentHonorPerHour = honorRate.rawXph or 0,
    sessionHonorPerHour = sessionHonorPerHour,
    currentHKPerHour = hkRate.rawXph or 0,
    sessionHKPerHour = sessionHKPerHour,
    rollingWindow = window,
    goalMode = goalMode,
    goalLabel = goalLabel,
    goalHeadline = goalHeadline,
    targetHonor = targetHonor,
    ttg = ttg,
    ttgText = ttgText,
    goalStatus = goalStatus,
    progress = (targetHonor and targetHonor > 0) and math_min(1, (state.currentHonor or 0) / targetHonor) or 0,
    zone = (match and match.zone) or getZone(),
    matchStatus = matchStatus,
    hasActiveMatch = match ~= nil and match.graceEndsAt == nil,
    apiAvailable = state.apiAvailable,
    apiMessage = state.apiMessage,
  }
end

function NS.GetPvpRecentNotices(limit)
  local state = getRuntime(GetTime())
  local notices = state.noticeLog or {}
  local count = math_min(#notices, math_max(1, math_floor(limit or #notices)))
  local result = {}
  local idx = 0
  for i = #notices, math_max(1, #notices - count + 1), -1 do
    idx = idx + 1
    result[idx] = notices[i]
  end
  return result
end

function NS.GetRecentPvpMatches(limit)
  local state = getRuntime(GetTime())
  local matches = state.recentMatches or {}
  local count = math_min(#matches, math_max(1, math_floor(limit or #matches)))
  local result = {}
  local idx = 0
  for i = #matches, math_max(1, #matches - count + 1), -1 do
    idx = idx + 1
    result[idx] = matches[i]
  end
  return result
end

local function average(values)
  local count = #values
  if count == 0 then
    return 0
  end
  local sum = 0
  for i = 1, count do
    sum = sum + values[i]
  end
  return sum / count
end

local function median(values)
  local count = #values
  if count == 0 then
    return 0
  end
  local sorted = {}
  for i = 1, count do
    sorted[i] = values[i]
  end
  table.sort(sorted)
  if count % 2 == 1 then
    return sorted[(count + 1) / 2]
  end
  return (sorted[count / 2] + sorted[(count / 2) + 1]) / 2
end

local function calculateTrendPct(chartWindow, count, sessions, key)
  local trendPct = 0
  if chartWindow >= 4 then
    local pairCount = math_floor(chartWindow / 2)
    local windowStart = count - (pairCount * 2) + 1
    local prevTotal = 0
    local newTotal = 0

    for i = windowStart, windowStart + pairCount - 1 do
      prevTotal = prevTotal + (tonumber(sessions[i][key]) or 0)
    end
    for i = windowStart + pairCount, windowStart + (pairCount * 2) - 1 do
      newTotal = newTotal + (tonumber(sessions[i][key]) or 0)
    end

    local prevAvg = prevTotal / pairCount
    local newAvg = newTotal / pairCount
    if prevAvg > 0 then
      trendPct = ((newAvg - prevAvg) / prevAvg) * 100
    end
  end
  return trendPct
end

function NS.GetPvpInsightsSummary(limit)
  local limitNum = tonumber(limit) or 10
  if NS.IsInvalidNumber(limitNum) then
    limitNum = 10
  end
  local rowLimit = math_max(1, math_floor(limitNum))
  local profile = ensurePvpStore(false)
  local sessions = (profile and profile.sessions) or {}
  local count = #sessions

  local rows = {}
  local firstIdx = math_max(1, count - rowLimit + 1)
  local rowCount = 0
  for i = count, firstIdx, -1 do
    rowCount = rowCount + 1
    rows[rowCount] = sessions[i]
  end

  local honorRates = {}
  local hkRates = {}
  local durations = {}
  local bestHonorPerHour = 0
  local bestSession = nil
  local lastSession = sessions[count]
  local zoneStats = {}

  for i = 1, count do
    local s = sessions[i]
    honorRates[#honorRates + 1] = tonumber(s.avgHonorPerHour) or 0
    hkRates[#hkRates + 1] = tonumber(s.avgHKPerHour) or 0
    durations[#durations + 1] = tonumber(s.durationSec) or 0
    if (tonumber(s.avgHonorPerHour) or 0) > bestHonorPerHour then
      bestHonorPerHour = tonumber(s.avgHonorPerHour) or 0
      bestSession = s
    end

    local zoneKey = safeString(s.zone, "Unknown")
    local zoneEntry = zoneStats[zoneKey]
    if not zoneEntry then
      zoneEntry = { zone = zoneKey, totalHonorPerHour = 0, sessions = 0 }
      zoneStats[zoneKey] = zoneEntry
    end
    zoneEntry.totalHonorPerHour = zoneEntry.totalHonorPerHour + (tonumber(s.avgHonorPerHour) or 0)
    zoneEntry.sessions = zoneEntry.sessions + 1
  end

  local chartValues = {}
  local chartWindow = math_min(20, count)
  if chartWindow > 0 then
    local start = count - chartWindow + 1
    for i = start, count do
      chartValues[#chartValues + 1] = tonumber(sessions[i].avgHonorPerHour) or 0
    end
  end

  local zoneLeaders = {}
  for _, stat in pairs(zoneStats) do
    zoneLeaders[#zoneLeaders + 1] = {
      zone = stat.zone,
      avgXph = (stat.sessions > 0) and (stat.totalHonorPerHour / stat.sessions) or 0,
      sessions = stat.sessions,
    }
  end
  table.sort(zoneLeaders, function(a, b)
    if a.avgXph == b.avgXph then
      return a.zone < b.zone
    end
    return a.avgXph > b.avgXph
  end)
  while #zoneLeaders > 3 do
    table.remove(zoneLeaders)
  end

  return {
    totalSessions = count,
    rows = rows,
    chartValues = chartValues,
    medianHonorPerHour = median(honorRates),
    medianHKPerHour = median(hkRates),
    bestHonorPerHour = bestHonorPerHour,
    avgSessionTime = average(durations),
    trendPct = calculateTrendPct(chartWindow, count, sessions, "avgHonorPerHour"),
    bestSession = bestSession,
    lastSession = lastSession,
    zoneLeaders = zoneLeaders,
    lastRecap = DingTimerDB and DingTimerDB.pvp and DingTimerDB.pvp.lastRecap or nil,
  }
end
