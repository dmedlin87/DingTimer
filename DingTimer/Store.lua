local _, NS = ...

local ADDON_VERSION = "1.1.2"

-- CANONICAL SOURCE of coach default values.
-- Store.lua loads before SessionCoach.lua, so this table and the stubs below are
-- the authoritative definitions. SessionCoach.lua reads them and defines the
-- runtime coach state/segment logic.
-- Do NOT duplicate these values in SessionCoach.lua.
local COACH_DEFAULTS = {
  goal = "ding",
  alertsEnabled = true,
  chatAlerts = true,
  idleSeconds = 90,
  paceDropPct = 15,
  alertCooldownSeconds = 90,
  alertHistoryLimit = 4,
  stabilizeEarlyPace = true,
}

local PVP_DEFAULTS = {
  autoSwitchBattlegrounds = false,
  goalMode = "cap",
  customGoalHonor = nil,
  honorCap = 15000,
  milestoneAnnouncements = false,
  milestoneStep = 5000,
  matchRecap = false,
  keepSessions = 30,
  historyView = "xp",
}

local function copyCoachDefaults()
  local out = {}
  for key, value in pairs(COACH_DEFAULTS) do
    out[key] = value
  end
  return out
end

local function copyPvpDefaults()
  local out = {}
  for key, value in pairs(PVP_DEFAULTS) do
    out[key] = value
  end
  return out
end

if not NS.GetCoachDefaults then
  function NS.GetCoachDefaults()
    return copyCoachDefaults()
  end
end

if not NS.GetPvpDefaults then
  function NS.GetPvpDefaults()
    return copyPvpDefaults()
  end
end

-- Single authoritative validation for coach config fields.
-- Both the fallback EnsureCoachConfig (below) and the SessionCoach runtime path
-- rely on this so clamp ranges and goal whitelist are defined exactly once.
function NS.ValidateCoachConfig(coach)
  for key, value in pairs(COACH_DEFAULTS) do
    if coach[key] == nil then
      coach[key] = value
    end
  end

  if coach.goal ~= "off" and coach.goal ~= "ding" and coach.goal ~= "30m" and coach.goal ~= "60m" then
    coach.goal = COACH_DEFAULTS.goal
  end

  coach.idleSeconds = math.max(30, math.floor(tonumber(coach.idleSeconds) or COACH_DEFAULTS.idleSeconds))
  coach.paceDropPct = math.max(5, math.min(50, math.floor(tonumber(coach.paceDropPct) or COACH_DEFAULTS.paceDropPct)))
  coach.alertCooldownSeconds = math.max(30, math.floor(tonumber(coach.alertCooldownSeconds) or COACH_DEFAULTS.alertCooldownSeconds))
  coach.alertHistoryLimit = math.max(1, math.min(8, math.floor(tonumber(coach.alertHistoryLimit) or COACH_DEFAULTS.alertHistoryLimit)))

  return coach
end

function NS.ValidatePvpConfig(settings)
  settings = settings or {}
  for key, value in pairs(PVP_DEFAULTS) do
    if settings[key] == nil then
      settings[key] = value
    end
  end

  if settings.goalMode ~= "off" and settings.goalMode ~= "cap" and settings.goalMode ~= "custom" then
    settings.goalMode = PVP_DEFAULTS.goalMode
  end

  local customGoalHonor = tonumber(settings.customGoalHonor)
  if customGoalHonor and not NS.IsInvalidNumber(customGoalHonor) then
    settings.customGoalHonor = math.max(0, math.floor(customGoalHonor))
  else
    settings.customGoalHonor = nil
  end

  settings.honorCap = math.max(1, math.floor(tonumber(settings.honorCap) or PVP_DEFAULTS.honorCap))
  settings.milestoneStep = math.max(100, math.floor(tonumber(settings.milestoneStep) or PVP_DEFAULTS.milestoneStep))
  do
    local keep = math.floor(tonumber(settings.keepSessions) or PVP_DEFAULTS.keepSessions)
    if keep < 5 then
      keep = 5
    elseif keep > 100 then
      keep = 100
    end
    settings.keepSessions = keep
  end
  settings.autoSwitchBattlegrounds = settings.autoSwitchBattlegrounds == true
  settings.milestoneAnnouncements = settings.milestoneAnnouncements == true
  settings.matchRecap = settings.matchRecap == true
  settings.historyView = (settings.historyView == "pvp") and "pvp" or "xp"

  if settings.goalMode ~= "custom" then
    settings.customGoalHonor = nil
  end

  return settings
end

if not NS.EnsureCoachConfig then
  function NS.EnsureCoachConfig(db)
    db = db or DingTimerDB or {}
    db.coach = db.coach or {}
    NS.ValidateCoachConfig(db.coach)
    return db.coach
  end
end

if not NS.EnsurePvpConfig then
  function NS.EnsurePvpConfig(db)
    db = db or DingTimerDB or {}
    db.pvp = db.pvp or {}
    db.pvp.settings = db.pvp.settings or {}
    NS.ValidatePvpConfig(db.pvp.settings)
    return db.pvp.settings
  end
end

if not NS.InvalidateCoachConfig then
  function NS.InvalidateCoachConfig()
    -- Config is validated directly on demand; no cache remains to invalidate.
  end
end

local function normalizeKeep(n)
  if NS.NormalizeKeepSessions then
    return NS.NormalizeKeepSessions(n)
  end

  local v = math.floor(tonumber(n) or 30)
  if v < 5 then
    v = 5
  elseif v > 100 then
    v = 100
  end
  return v
end

local function currentProfileKey()
  if NS.GetProfileKey then
    return NS.GetProfileKey()
  end
  return "Unknown:Unknown:UNKNOWN"
end

local function normalizeScaleMode(mode, fixedMax)
  local normalized = NS.NormalizeGraphScaleMode and NS.NormalizeGraphScaleMode(mode) or mode
  if normalized == "fixed" and (fixedMax == nil or fixedMax == 100000) then
    return "visible"
  end
  return normalized or "visible"
end

local function readClampedWhole(value, defaultValue, minValue, maxValue)
  local numeric = tonumber(value)
  if not numeric or NS.IsInvalidNumber(numeric) then
    numeric = defaultValue
  end

  numeric = math.floor(numeric)
  if minValue ~= nil and numeric < minValue then
    numeric = minValue
  end
  if maxValue ~= nil and numeric > maxValue then
    numeric = maxValue
  end
  return numeric
end

local function normalizeWindowSeconds(value)
  return readClampedWhole(value, 600, 30, 86400)
end

local function normalizeMinXPDeltaToPrint(value)
  return readClampedWhole(value, 1, 1, nil)
end

local function normalizeGraphWindowSeconds(value)
  return readClampedWhole(value, 300, 180, 3600)
end

local function normalizeOutputMode(mode)
  if mode == "ttl" then
    return "ttl"
  end
  return "full"
end

local function ensureCoachConfig()
  -- NS.EnsureCoachConfig handles all default-filling and clamping internally.
  NS.EnsureCoachConfig(DingTimerDB)
end

local function cleanupObsoleteWindowState()
  DingTimerDB.graphVisible = nil
  DingTimerDB.graphPosition = nil
  DingTimerDB.graphLocked = nil
  DingTimerDB.graphWindowSize = nil
  DingTimerDB.insightsWindowPosition = nil
  DingTimerDB.settingsWindowPosition = nil
end

local function ensureProfileTables()
  DingTimerDB.xp = DingTimerDB.xp or {}
  DingTimerDB.xp.keepSessions = normalizeKeep(DingTimerDB.xp.keepSessions)
  DingTimerDB.xp.profiles = DingTimerDB.xp.profiles or {}

  local key = currentProfileKey()
  local profile = DingTimerDB.xp.profiles[key]
  if not profile then
    profile = { sessions = {} }
    DingTimerDB.xp.profiles[key] = profile
  end
  profile.sessions = profile.sessions or {}

  return key, profile
end

local function ensurePvpTables()
  DingTimerDB.pvp = DingTimerDB.pvp or {}
  DingTimerDB.pvp.settings = DingTimerDB.pvp.settings or copyPvpDefaults()
  NS.ValidatePvpConfig(DingTimerDB.pvp.settings)
  DingTimerDB.pvp.profiles = DingTimerDB.pvp.profiles or {}
  DingTimerDB.pvp.lastRecap = DingTimerDB.pvp.lastRecap or nil

  local key = currentProfileKey()
  local profile = DingTimerDB.pvp.profiles[key]
  if not profile then
    profile = { sessions = {} }
    DingTimerDB.pvp.profiles[key] = profile
  end
  profile.sessions = profile.sessions or {}

  return key, profile
end

function NS.InitStore()
  local defaults = {
    enabled = true,
    activeMode = "xp",
    windowSeconds = 600,
    minXPDeltaToPrint = 1,
    mode = "full",
    float = false,
    floatShowInCombat = false,
    floatLocked = true,
    graphWindowSeconds = 300,
    graphScaleMode = "visible",
    graphFixedMaxXPH = 100000,
    insightsWindowVisible = false,
    minimapHidden = false,
    mainWindowVisible = false,
    mainWindowPosition = nil,
    lastOpenTab = 1,
    schemaVersion = 9,
    meta = {
      addonVersion = ADDON_VERSION,
      createdAt = GetTime(),
      lastSeenAt = GetTime(),
    },
    coach = copyCoachDefaults(),
    pvp = {
      settings = copyPvpDefaults(),
      profiles = {},
      resume = nil,
      lastRecap = nil,
    },
    xp = {
      keepSessions = 30,
      profiles = {},
    },
  }

  if not DingTimerDB then
    DingTimerDB = defaults
  else
    DingTimerDB.windowSeconds = normalizeWindowSeconds(DingTimerDB.windowSeconds)
    DingTimerDB.minXPDeltaToPrint = normalizeMinXPDeltaToPrint(DingTimerDB.minXPDeltaToPrint)
    DingTimerDB.graphWindowSeconds = normalizeGraphWindowSeconds(DingTimerDB.graphWindowSeconds)

    if DingTimerDB.graphFixedMaxXPH ~= nil then
      if NS.ClampGraphFixedMax then
        DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH)
      end
    end

    if not DingTimerDB.schemaVersion or DingTimerDB.schemaVersion < 3 then
      DingTimerDB.schemaVersion = 3
      DingTimerDB.meta = defaults.meta
      DingTimerDB.xp = defaults.xp
      DingTimerDB.pvp = defaults.pvp
      -- Preserve existing settings if they exist
      DingTimerDB.enabled = (DingTimerDB.enabled ~= nil) and DingTimerDB.enabled or defaults.enabled
      DingTimerDB.activeMode = DingTimerDB.activeMode or defaults.activeMode
      DingTimerDB.windowSeconds = DingTimerDB.windowSeconds or defaults.windowSeconds
      DingTimerDB.minXPDeltaToPrint = DingTimerDB.minXPDeltaToPrint or defaults.minXPDeltaToPrint
      DingTimerDB.mode = DingTimerDB.mode or defaults.mode
      DingTimerDB.float = (DingTimerDB.float ~= nil) and DingTimerDB.float or defaults.float
      DingTimerDB.floatShowInCombat = (DingTimerDB.floatShowInCombat ~= nil) and DingTimerDB.floatShowInCombat or defaults.floatShowInCombat
      DingTimerDB.floatLocked = (DingTimerDB.floatLocked ~= nil) and DingTimerDB.floatLocked or defaults.floatLocked
      
      -- Remove cpc data if it exists
      DingTimerDB.cpc = nil
    end

    if DingTimerDB.schemaVersion < 4 then
      DingTimerDB.schemaVersion = 4
      if DingTimerDB.graphWindowSeconds == nil then DingTimerDB.graphWindowSeconds = 300 end
      if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = "visible" end
      if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = 100000    end
    end

    if DingTimerDB.schemaVersion < 5 then
      local legacySessions = nil
      if DingTimerDB.xp and type(DingTimerDB.xp.sessions) == "table" then
        legacySessions = DingTimerDB.xp.sessions
      end

      DingTimerDB.schemaVersion = 5
      if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = false end

      local _, profile = ensureProfileTables()
      if legacySessions and #legacySessions > 0 and #profile.sessions == 0 then
        for i = 1, #legacySessions do
          profile.sessions[#profile.sessions + 1] = legacySessions[i]
        end
      end
    end

    if DingTimerDB.schemaVersion < 6 then
      DingTimerDB.schemaVersion = 6
      DingTimerDB.graphScaleMode = normalizeScaleMode(DingTimerDB.graphScaleMode, DingTimerDB.graphFixedMaxXPH)
    end

    if DingTimerDB.schemaVersion < 7 then
      DingTimerDB.schemaVersion = 7
      cleanupObsoleteWindowState()
    end

    if DingTimerDB.schemaVersion < 8 then
      -- v8: No data transformation needed. This version bump was reserved to
      -- allow coach.lastRecap and coach.pendingRecap to be recognised as valid
      -- fields by EnsureCoachConfig without being wiped on first load.
      DingTimerDB.schemaVersion = 8
      DingTimerDB.coach = DingTimerDB.coach or {}
    end

    if DingTimerDB.schemaVersion < 9 then
      DingTimerDB.schemaVersion = 9
      DingTimerDB.activeMode = (DingTimerDB.activeMode == "pvp") and "pvp" or "xp"
      DingTimerDB.pvp = DingTimerDB.pvp or {}
      DingTimerDB.pvp.settings = DingTimerDB.pvp.settings or copyPvpDefaults()
      DingTimerDB.pvp.profiles = DingTimerDB.pvp.profiles or {}
      DingTimerDB.pvp.resume = DingTimerDB.pvp.resume or nil
      DingTimerDB.pvp.lastRecap = DingTimerDB.pvp.lastRecap or nil
    end
  end

  if DingTimerDB.activeMode == nil then DingTimerDB.activeMode = defaults.activeMode end
  if DingTimerDB.graphWindowSeconds == nil then DingTimerDB.graphWindowSeconds = defaults.graphWindowSeconds end
  if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = defaults.graphScaleMode     end
  if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = defaults.graphFixedMaxXPH   end
  if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = defaults.insightsWindowVisible end
  if DingTimerDB.minimapHidden == nil then DingTimerDB.minimapHidden = defaults.minimapHidden end
  if DingTimerDB.mainWindowVisible == nil then DingTimerDB.mainWindowVisible = defaults.mainWindowVisible end
  if DingTimerDB.mainWindowPosition == nil then DingTimerDB.mainWindowPosition = defaults.mainWindowPosition end
  if DingTimerDB.lastOpenTab == nil then DingTimerDB.lastOpenTab = defaults.lastOpenTab end
  if DingTimerDB.floatShowInCombat == nil then DingTimerDB.floatShowInCombat = defaults.floatShowInCombat end
  if DingTimerDB.coach == nil then DingTimerDB.coach = copyCoachDefaults() end
  if DingTimerDB.pvp == nil then DingTimerDB.pvp = defaults.pvp end
  if not DingTimerDB.meta then DingTimerDB.meta = defaults.meta end
  cleanupObsoleteWindowState()
  DingTimerDB.windowSeconds = normalizeWindowSeconds(DingTimerDB.windowSeconds)
  DingTimerDB.minXPDeltaToPrint = normalizeMinXPDeltaToPrint(DingTimerDB.minXPDeltaToPrint)
  DingTimerDB.graphWindowSeconds = normalizeGraphWindowSeconds(DingTimerDB.graphWindowSeconds)
  DingTimerDB.mode = normalizeOutputMode(DingTimerDB.mode)
  DingTimerDB.graphScaleMode = normalizeScaleMode(DingTimerDB.graphScaleMode, DingTimerDB.graphFixedMaxXPH)
  DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax and NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH) or DingTimerDB.graphFixedMaxXPH
  DingTimerDB.meta.addonVersion = defaults.meta.addonVersion
  ensureCoachConfig()

  local _, profile = ensureProfileTables()
  local _, pvpProfile = ensurePvpTables()
  DingTimerDB.xp.sessions = nil
  if NS.TrimSessions then
    NS.TrimSessions(profile, DingTimerDB.xp.keepSessions)
  end
  if NS.TrimPvpSessions then
    NS.TrimPvpSessions(pvpProfile, DingTimerDB.pvp.settings.keepSessions)
  end
  for _, existingProfile in pairs(DingTimerDB.xp.profiles or {}) do
    local sessions = existingProfile.sessions or {}
    for i = 1, #sessions do
      sessions[i].segments = sessions[i].segments or {}
    end
  end

  DingTimerDB.meta.lastSeenAt = GetTime()
end
