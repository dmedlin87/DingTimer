local ADDON, NS = ...

function NS.InitStore()
  local defaults = {
    enabled = true,
    windowSeconds = 600,
    minXPDeltaToPrint = 1,
    mode = "full",
    float = false,
    floatLocked = true,
    schemaVersion = 3,
    meta = {
      addonVersion = "0.3.0",
      createdAt = GetTime(),
      lastSeenAt = GetTime(),
    },
    xp = {
      keepSessions = 10,
      sessions = {},
    },
  }

  if not DingTimerDB then
    DingTimerDB = defaults
  else
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
  end
  
  DingTimerDB.meta.lastSeenAt = GetTime()
end