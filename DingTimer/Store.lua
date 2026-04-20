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
  windowSeconds = 600,
  minXPDeltaToPrint = 1,
  mode = "full",
  float = true,
  floatShowInCombat = false,
  floatLocked = true,
  floatPosition = nil,
  schemaVersion = 10,
  meta = {
    addonVersion = ADDON_VERSION,
    createdAt = 0,
    lastSeenAt = 0,
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

function NS.InitStore()
  local now = GetTime and GetTime() or 0
  local db = DingTimerDB

  if type(db) ~= "table" then
    db = copyTable(DEFAULTS)
    DingTimerDB = db
  end

  if db.enabled == nil then
    db.enabled = DEFAULTS.enabled
  else
    db.enabled = db.enabled == true
  end

  db.windowSeconds = normalizeWindowSeconds(db.windowSeconds)
  db.minXPDeltaToPrint = normalizeMinXPDeltaToPrint(db.minXPDeltaToPrint)
  db.mode = normalizeOutputMode(db.mode)
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
  if type(db.floatPosition) ~= "table" then
    db.floatPosition = nil
  end

  db.meta = db.meta or {}
  db.meta.addonVersion = ADDON_VERSION
  db.meta.createdAt = db.meta.createdAt or now
  db.meta.lastSeenAt = now

  clearDeadSurfaceState(db)
  db.schemaVersion = DEFAULTS.schemaVersion
end
