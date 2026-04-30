local _, NS = ...

local ADDON_VERSION = "1.1.2"

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

local DEFAULTS = {
  enabled = true,
  dingSoundEnabled = true,
  windowSeconds = 600,
  minXPDeltaToPrint = 1,
  mode = "full",
  hudProfile = "full",
  hudTrackingMode = "auto",
  float = true,
  floatShowInCombat = false,
  floatLocked = true,
  floatPosition = nil,
  schemaVersion = 11,
  meta = {
    addonVersion = ADDON_VERSION,
  },
}

local function readClampedWhole(value, defaultValue, minValue, maxValue)
  local numeric = tonumber(value)
  if not numeric or (NS.IsInvalidNumber and NS.IsInvalidNumber(numeric)) then
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
  return readClampedWhole(value, DEFAULTS.windowSeconds, 30, 86400)
end

local function normalizeMinXPDeltaToPrint(value)
  return readClampedWhole(value, DEFAULTS.minXPDeltaToPrint, 1, nil)
end

local function normalizeOutputMode(mode)
  if mode == "ttl" then
    return "ttl"
  end
  return "full"
end

local VALID_HUD_PROFILES = {
  full = true,
  compact = true,
  bar_ttl = true,
  graph = true,
}

local VALID_HUD_TRACKING_MODES = {
  auto = true,
  xp = true,
  gold = true,
}

local function normalizeHUDProfile(profile)
  if VALID_HUD_PROFILES[profile] then
    return profile
  end
  return DEFAULTS.hudProfile
end

local function normalizeHUDTrackingMode(mode)
  if VALID_HUD_TRACKING_MODES[mode] then
    return mode
  end
  return DEFAULTS.hudTrackingMode
end

local VALID_ANCHOR_POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

local function normalizeFloatPosition(position)
  if type(position) ~= "table" then
    return nil
  end

  local point = position.point
  local relativePoint = position.relativePoint or point
  if not VALID_ANCHOR_POINTS[point] or not VALID_ANCHOR_POINTS[relativePoint] then
    return nil
  end

  local xOfs = tonumber(position.xOfs) or 0
  local yOfs = tonumber(position.yOfs) or 0
  if (NS.IsInvalidNumber and (NS.IsInvalidNumber(xOfs) or NS.IsInvalidNumber(yOfs))) then
    return nil
  end

  return {
    point = point,
    relativePoint = relativePoint,
    xOfs = xOfs,
    yOfs = yOfs,
  }
end

local function clearDeadSurfaceState(db)
  db.activeMode = nil
  db.graphVisible = nil
  db.graphPosition = nil
  db.graphLocked = nil
  db.graphWindowSize = nil
  db.graphWindowSeconds = nil
  db.graphScaleMode = nil
  db.graphFixedMaxXPH = nil
  db.insightsWindowVisible = nil
  db.insightsWindowPosition = nil
  db.settingsWindowPosition = nil
  db.mainWindowVisible = nil
  db.mainWindowPosition = nil
  db.mainWindowSize = nil
  db.lastOpenTab = nil
  db.minimapHidden = nil
  db.minimapAngle = nil
end

local function normalizeActiveSettings(db)
  if db.enabled == nil then
    db.enabled = DEFAULTS.enabled
  else
    db.enabled = db.enabled == true
  end
  if db.dingSoundEnabled == nil then
    db.dingSoundEnabled = DEFAULTS.dingSoundEnabled
  else
    db.dingSoundEnabled = db.dingSoundEnabled == true
  end

  db.windowSeconds = normalizeWindowSeconds(db.windowSeconds)
  db.minXPDeltaToPrint = normalizeMinXPDeltaToPrint(db.minXPDeltaToPrint)
  db.mode = normalizeOutputMode(db.mode)
  db.hudProfile = normalizeHUDProfile(db.hudProfile)
  db.hudTrackingMode = normalizeHUDTrackingMode(db.hudTrackingMode)
  if db.float == nil then
    db.float = DEFAULTS.float
  else
    db.float = db.float == true
  end
  if db.floatShowInCombat == nil then
    db.floatShowInCombat = DEFAULTS.floatShowInCombat
  else
    db.floatShowInCombat = db.floatShowInCombat == true
  end
  if db.floatLocked == nil then
    db.floatLocked = DEFAULTS.floatLocked
  else
    db.floatLocked = db.floatLocked == true
  end
  db.floatPosition = normalizeFloatPosition(db.floatPosition)
end

local function updateMetadata(db)
  if type(db.meta) ~= "table" then
    db.meta = {}
  end
  db.meta.addonVersion = ADDON_VERSION
  db.meta.createdAt = nil
  db.meta.lastSeenAt = nil
end

local function migrateToCurrentSchema(db)
  clearDeadSurfaceState(db)
  db.schemaVersion = DEFAULTS.schemaVersion
end

local function migrateStore(db)
  local schemaVersion = tonumber(db.schemaVersion) or 0
  if schemaVersion <= DEFAULTS.schemaVersion then
    migrateToCurrentSchema(db)
  else
    db.schemaVersion = DEFAULTS.schemaVersion
  end
end

function NS.InitStore()
  local db = DingTimerDB

  if type(db) ~= "table" then
    db = copyTable(DEFAULTS)
    DingTimerDB = db
  end

  normalizeActiveSettings(db)
  updateMetadata(db)
  migrateStore(db)
end
