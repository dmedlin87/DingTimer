dofile("tests/mocks.lua")

local setFloatVisibleCalls = {}

local NS = {
  UI = {},
  setFloatVisible = function(on)
    setFloatVisibleCalls[#setFloatVisibleCalls + 1] = on
  end,
}

NS.UI.CreateScrollFrame = function(parent)
  local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollFrame.child = scrollChild
  return scrollFrame, scrollChild
end
NS.UI.CreateSectionTitle = function() end
NS.UI.CreateValueLabel = function(parent)
  return parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
end
NS.CreateConfirmButton = function(parent)
  return CreateFrame("Button", nil, parent)
end
NS.fmtTime = function(seconds)
  return tostring(seconds) .. "s"
end
NS.NormalizeGraphScaleMode = function(mode)
  return mode or "visible"
end
NS.GetGraphScaleModeLabel = function(mode)
  return tostring(mode)
end
NS.FormatNumber = function(n)
  return tostring(n)
end
NS.EnsureCoachConfig = function()
  DingTimerDB.coach = DingTimerDB.coach or {
    goal = "ding",
    alertsEnabled = true,
    chatAlerts = true,
    idleSeconds = 90,
    paceDropPct = 15,
    alertCooldownSeconds = 90,
  }
  return DingTimerDB.coach
end

DingTimerDB = {
  enabled = true,
  mode = "full",
  windowSeconds = 600,
  float = true,
  floatLocked = true,
  floatShowInCombat = false,
  minimapHidden = false,
  graphScaleMode = "visible",
  graphFixedMaxXPH = 100000,
  graphWindowSeconds = 300,
  coach = {
    goal = "ding",
    alertsEnabled = true,
    chatAlerts = true,
    idleSeconds = 90,
    paceDropPct = 15,
    alertCooldownSeconds = 90,
  },
  xp = {
    keepSessions = 30,
  },
}

LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

local panel = NS.InitSettingsPanel(UIParent)
panel:Refresh()

assert_true(panel.controls.floatShowInCombat ~= nil, "settings should expose a show-in-combat toggle")
assert_eq(panel.controls.floatShowInCombat:GetChecked(), false, "toggle should reflect the saved setting")

panel.controls.floatShowInCombat:SetChecked(true)
panel.controls.floatShowInCombat:GetScript("OnClick")(panel.controls.floatShowInCombat)

assert_eq(DingTimerDB.floatShowInCombat, true, "clicking the toggle should update the saved setting")
assert_eq(setFloatVisibleCalls[#setFloatVisibleCalls], true, "changing the toggle should reapply HUD visibility when the HUD is enabled")

print("Settings show-in-combat toggle test passed!")
