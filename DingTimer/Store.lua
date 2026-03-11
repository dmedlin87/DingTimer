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

local function normalizeGraphSize(size)
  if type(size) ~= "table" then
    size = {}
  end

  local defaultSize = NS.GraphWindowDefaults or { width = 660, height = 340 }
  local clamp = NS.ClampGraphWindowSize
  local width, height
  if clamp then
    width, height = clamp(size.width or defaultSize.width, size.height or defaultSize.height)
  else
    width = size.width or defaultSize.width
    height = size.height or defaultSize.height
  end

  return {
    width = width,
    height = height,
  }
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
  local graphDefaults = NS.GraphWindowDefaults or { width = 660, height = 340 }
  local defaults = {
    enabled = true,
    windowSeconds = 600,
    minXPDeltaToPrint = 1,
    mode = "full",
    float = false,
    floatLocked = true,
    graphVisible = false,
    graphPosition = nil,
    graphWindowSeconds = 300,
    graphScaleMode = "visible",
    graphFixedMaxXPH = 100000,
    graphLocked = true,
    graphWindowSize = {
      width = graphDefaults.width,
      height = graphDefaults.height,
    },
    insightsWindowVisible = false,
    insightsWindowPosition = nil,
    settingsWindowPosition = nil,
    schemaVersion = 6,
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
      if DingTimerDB.graphVisible == nil       then DingTimerDB.graphVisible       = false     end
      if DingTimerDB.graphWindowSeconds == nil  then DingTimerDB.graphWindowSeconds = 300       end
      if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = "visible" end
      if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = 100000    end
      if DingTimerDB.graphLocked == nil        then DingTimerDB.graphLocked        = true      end
    end

    if DingTimerDB.schemaVersion < 5 then
      local legacySessions = nil
      if DingTimerDB.xp and type(DingTimerDB.xp.sessions) == "table" then
        legacySessions = DingTimerDB.xp.sessions
      end

      DingTimerDB.schemaVersion = 5
      if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = false end
      if DingTimerDB.insightsWindowPosition == nil then DingTimerDB.insightsWindowPosition = nil end

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
      DingTimerDB.graphWindowSize = normalizeGraphSize(DingTimerDB.graphWindowSize)
    end
  end

  if DingTimerDB.graphVisible == nil       then DingTimerDB.graphVisible       = defaults.graphVisible       end
  if DingTimerDB.graphWindowSeconds == nil then DingTimerDB.graphWindowSeconds = defaults.graphWindowSeconds end
  if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = defaults.graphScaleMode     end
  if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = defaults.graphFixedMaxXPH   end
  if DingTimerDB.graphLocked == nil        then DingTimerDB.graphLocked        = defaults.graphLocked        end
  if DingTimerDB.graphWindowSize == nil    then DingTimerDB.graphWindowSize    = defaults.graphWindowSize    end
  if DingTimerDB.insightsWindowVisible == nil then DingTimerDB.insightsWindowVisible = defaults.insightsWindowVisible end
  if DingTimerDB.insightsWindowPosition == nil then DingTimerDB.insightsWindowPosition = defaults.insightsWindowPosition end
  if DingTimerDB.settingsWindowPosition == nil then DingTimerDB.settingsWindowPosition = defaults.settingsWindowPosition end
  if not DingTimerDB.meta then DingTimerDB.meta = defaults.meta end
  DingTimerDB.graphScaleMode = normalizeScaleMode(DingTimerDB.graphScaleMode, DingTimerDB.graphFixedMaxXPH)
  DingTimerDB.graphFixedMaxXPH = NS.ClampGraphFixedMax and NS.ClampGraphFixedMax(DingTimerDB.graphFixedMaxXPH) or DingTimerDB.graphFixedMaxXPH
  DingTimerDB.graphWindowSize = normalizeGraphSize(DingTimerDB.graphWindowSize)
  DingTimerDB.meta.addonVersion = defaults.meta.addonVersion

  local _, profile = ensureProfileTables()
  DingTimerDB.xp.sessions = nil
  if NS.TrimSessions then
    NS.TrimSessions(profile, DingTimerDB.xp.keepSessions)
  end

  DingTimerDB.meta.lastSeenAt = GetTime()
end
