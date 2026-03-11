local ADDON, NS = ...

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
    schemaVersion = 7,
    meta = {
      addonVersion = "0.5.0",
      createdAt = GetTime(),
      lastSeenAt = GetTime(),
    },
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
      if DingTimerDB.windowSeconds ~= DingTimerDB.windowSeconds or DingTimerDB.windowSeconds == math.huge or DingTimerDB.windowSeconds == -math.huge then
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
  end

  if DingTimerDB.graphWindowSeconds == nil then DingTimerDB.graphWindowSeconds = defaults.graphWindowSeconds end
  if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = defaults.graphScaleMode     end
  if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = defaults.graphFixedMaxXPH   end
  if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = defaults.insightsWindowVisible end
  if DingTimerDB.minimapHidden == nil then DingTimerDB.minimapHidden = defaults.minimapHidden end
  if DingTimerDB.mainWindowVisible == nil then DingTimerDB.mainWindowVisible = defaults.mainWindowVisible end
  if DingTimerDB.mainWindowPosition == nil then DingTimerDB.mainWindowPosition = defaults.mainWindowPosition end
  if DingTimerDB.lastOpenTab == nil then DingTimerDB.lastOpenTab = defaults.lastOpenTab end
  if not DingTimerDB.meta then DingTimerDB.meta = defaults.meta end
  cleanupObsoleteWindowState()
  DingTimerDB.graphScaleMode = normalizeScaleMode(DingTimerDB.graphScaleMode, DingTimerDB.graphFixedMaxXPH)
  DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax and NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH) or DingTimerDB.graphFixedMaxXPH
  DingTimerDB.meta.addonVersion = defaults.meta.addonVersion

  local _, profile = ensureProfileTables()
  DingTimerDB.xp.sessions = nil
  if NS.TrimSessions then
    NS.TrimSessions(profile, DingTimerDB.xp.keepSessions)
  end

  DingTimerDB.meta.lastSeenAt = GetTime()
end
