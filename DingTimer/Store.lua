local ADDON, NS = ...

-- CANONICAL SOURCE of coach default values.
-- Store.lua loads before SessionCoach.lua, so this table and the stubs below are
-- the authoritative definitions. SessionCoach.lua overrides the stubs with its full
-- implementations but reads defaults via NS.GetCoachDefaults() (defined below).
-- Do NOT duplicate these values in SessionCoach.lua.
local COACH_DEFAULTS = {
  goal = "ding",
  alertsEnabled = true,
  chatAlerts = true,
  idleSeconds = 90,
  paceDropPct = 15,
  alertCooldownSeconds = 90,
  alertHistoryLimit = 4,
}

local function copyCoachDefaults()
  local out = {}
  for key, value in pairs(COACH_DEFAULTS) do
    out[key] = value
  end
  return out
end

if not NS.GetCoachDefaults then
  function NS.GetCoachDefaults()
    return copyCoachDefaults()
  end
end

if not NS.EnsureCoachConfig then
  function NS.EnsureCoachConfig(db)
    db = db or DingTimerDB or {}
    db.coach = db.coach or {}

    for key, value in pairs(COACH_DEFAULTS) do
      if db.coach[key] == nil then
        db.coach[key] = value
      end
    end

    if db.coach.goal ~= "off" and db.coach.goal ~= "ding" and db.coach.goal ~= "30m" and db.coach.goal ~= "60m" then
      db.coach.goal = COACH_DEFAULTS.goal
    end

    local idleSeconds = math.floor(tonumber(db.coach.idleSeconds) or COACH_DEFAULTS.idleSeconds)
    if idleSeconds < 30 then idleSeconds = 30 end
    db.coach.idleSeconds = idleSeconds

    local paceDropPct = math.floor(tonumber(db.coach.paceDropPct) or COACH_DEFAULTS.paceDropPct)
    if paceDropPct < 5 then paceDropPct = 5 end
    if paceDropPct > 50 then paceDropPct = 50 end
    db.coach.paceDropPct = paceDropPct

    local alertCooldownSeconds = math.floor(tonumber(db.coach.alertCooldownSeconds) or COACH_DEFAULTS.alertCooldownSeconds)
    if alertCooldownSeconds < 30 then alertCooldownSeconds = 30 end
    db.coach.alertCooldownSeconds = alertCooldownSeconds

    local alertHistoryLimit = math.floor(tonumber(db.coach.alertHistoryLimit) or COACH_DEFAULTS.alertHistoryLimit)
    if alertHistoryLimit < 1 then alertHistoryLimit = 1 end
    if alertHistoryLimit > 8 then alertHistoryLimit = 8 end
    db.coach.alertHistoryLimit = alertHistoryLimit

    if db.coach.alertsEnabled == nil then db.coach.alertsEnabled = COACH_DEFAULTS.alertsEnabled end
    if db.coach.chatAlerts == nil then db.coach.chatAlerts = COACH_DEFAULTS.chatAlerts end

    return db.coach
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

function NS.InitStore()
  local defaults = {
    enabled = true,
    windowSeconds = 600,
    minXPDeltaToPrint = 1,
    mode = "full",
    float = false,
    floatLocked = true,
    graphWindowSeconds = 300,
    graphScaleMode = "visible",
    graphFixedMaxXPH = 100000,
    insightsWindowVisible = false,
    minimapHidden = false,
    mainWindowVisible = false,
    mainWindowPosition = nil,
    lastOpenTab = 1,
    schemaVersion = 8,
    meta = {
      addonVersion = "0.6.0",
      createdAt = GetTime(),
      lastSeenAt = GetTime(),
    },
    coach = copyCoachDefaults(),
    xp = {
      keepSessions = 30,
      profiles = {},
    },
  }

  if not DingTimerDB then
    DingTimerDB = defaults
  else
    -- 🛡️ Sentinel: Global bounds check for windowSeconds to prevent DoS from maliciously modified or corrupted SavedVariables
    if DingTimerDB.windowSeconds then
      -- Also explicitly check for NaN and Infinity to prevent validation bypass
      if NS.IsInvalidNumber(DingTimerDB.windowSeconds) then
        DingTimerDB.windowSeconds = 600
      elseif DingTimerDB.windowSeconds < 30 then
        DingTimerDB.windowSeconds = 30
      elseif DingTimerDB.windowSeconds > 86400 then
        DingTimerDB.windowSeconds = 86400
      end
    end

    if DingTimerDB.graphFixedMaxXPH ~= nil then
      if NS.ClampGraphFixedMax then
        DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH)
      end
    end

    if not DingTimerDB.schemaVersion or DingTimerDB.schemaVersion < 3 then
      DingTimerDB.schemaVersion = 3
      DingTimerDB.meta = defaults.meta
      DingTimerDB.xp = defaults.xp
      -- Preserve existing settings if they exist
      DingTimerDB.enabled = (DingTimerDB.enabled ~= nil) and DingTimerDB.enabled or defaults.enabled
      DingTimerDB.windowSeconds = DingTimerDB.windowSeconds or defaults.windowSeconds
      DingTimerDB.minXPDeltaToPrint = DingTimerDB.minXPDeltaToPrint or defaults.minXPDeltaToPrint
      DingTimerDB.mode = DingTimerDB.mode or defaults.mode
      DingTimerDB.float = (DingTimerDB.float ~= nil) and DingTimerDB.float or defaults.float
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
  end

  if DingTimerDB.graphWindowSeconds == nil then DingTimerDB.graphWindowSeconds = defaults.graphWindowSeconds end
  if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = defaults.graphScaleMode     end
  if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = defaults.graphFixedMaxXPH   end
  if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = defaults.insightsWindowVisible end
  if DingTimerDB.minimapHidden == nil then DingTimerDB.minimapHidden = defaults.minimapHidden end
  if DingTimerDB.mainWindowVisible == nil then DingTimerDB.mainWindowVisible = defaults.mainWindowVisible end
  if DingTimerDB.mainWindowPosition == nil then DingTimerDB.mainWindowPosition = defaults.mainWindowPosition end
  if DingTimerDB.lastOpenTab == nil then DingTimerDB.lastOpenTab = defaults.lastOpenTab end
  if DingTimerDB.coach == nil then DingTimerDB.coach = copyCoachDefaults() end
  if not DingTimerDB.meta then DingTimerDB.meta = defaults.meta end
  cleanupObsoleteWindowState()
  DingTimerDB.graphScaleMode = normalizeScaleMode(DingTimerDB.graphScaleMode, DingTimerDB.graphFixedMaxXPH)
  DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax and NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH) or DingTimerDB.graphFixedMaxXPH
  DingTimerDB.meta.addonVersion = defaults.meta.addonVersion
  ensureCoachConfig()

  local _, profile = ensureProfileTables()
  DingTimerDB.xp.sessions = nil
  if NS.TrimSessions then
    NS.TrimSessions(profile, DingTimerDB.xp.keepSessions)
  end
  for _, existingProfile in pairs(DingTimerDB.xp.profiles or {}) do
    local sessions = existingProfile.sessions or {}
    for i = 1, #sessions do
      sessions[i].segments = sessions[i].segments or {}
    end
  end

  DingTimerDB.meta.lastSeenAt = GetTime()
end
