local ADDON, NS = ...

function NS.InitStore()
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
    graphScaleMode = "fixed",
    graphFixedMaxXPH = 100000,
    graphLocked = true,
    schemaVersion = 4,
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
    -- 🛡️ Sentinel: Global bounds check for windowSeconds to prevent DoS from maliciously modified or corrupted SavedVariables
    if DingTimerDB.windowSeconds then
      if DingTimerDB.windowSeconds < 30 then
        DingTimerDB.windowSeconds = 30
      elseif DingTimerDB.windowSeconds > 86400 then
        DingTimerDB.windowSeconds = 86400
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
      if DingTimerDB.graphScaleMode == nil     then DingTimerDB.graphScaleMode     = "fixed"   end
      if DingTimerDB.graphFixedMaxXPH == nil   then DingTimerDB.graphFixedMaxXPH   = 100000    end
      if DingTimerDB.graphLocked == nil        then DingTimerDB.graphLocked        = true      end
    end
  end
  
  DingTimerDB.meta.lastSeenAt = GetTime()
end