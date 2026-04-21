local _, NS = ...

local function refreshSurfaces()
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD()
  end
  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
end

function NS.SetChatOutputEnabled(enabled)
  DingTimerDB.enabled = enabled == true
  refreshSurfaces()
  return DingTimerDB.enabled
end

function NS.SetOutputMode(mode)
  if mode ~= "full" and mode ~= "ttl" then
    return false, "Unknown mode. Use 'full' or 'ttl'."
  end
  DingTimerDB.mode = mode
  refreshSurfaces()
  return true, mode
end

function NS.SetFloatEnabled(enabled)
  DingTimerDB.float = enabled == true
  if NS.setFloatVisible then
    NS.setFloatVisible(DingTimerDB.float)
  end
  refreshSurfaces()
  return DingTimerDB.float
end

function NS.SetFloatLocked(locked)
  DingTimerDB.floatLocked = locked == true
  refreshSurfaces()
  return DingTimerDB.floatLocked
end

function NS.SetFloatShowInCombat(showInCombat)
  DingTimerDB.floatShowInCombat = showInCombat == true
  if DingTimerDB.float and NS.setFloatVisible then
    NS.setFloatVisible(true)
  end
  refreshSurfaces()
  return DingTimerDB.floatShowInCombat
end

function NS.ResetFloatHUD()
  DingTimerDB.float = true
  if NS.ResetFloatPosition then
    NS.ResetFloatPosition()
  end
  if NS.setFloatVisible then
    NS.setFloatVisible(true)
  end
  refreshSurfaces()
  return true
end

function NS.OpenSettingsPopup()
  if NS.ShowHUDPopup then
    return NS.ShowHUDPopup()
  end
  return false
end

function NS.ToggleSettingsPopup(anchorFrame)
  if NS.ToggleHUDPopup then
    return NS.ToggleHUDPopup(anchorFrame)
  end
  return false
end

function NS.ResetSession(reason)
  if NS.resetXPState then
    NS.resetXPState(reason or "MANUAL_RESET")
  end
  if NS.chat then
    NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " session reset.")
  end
  refreshSurfaces()
  return true
end
