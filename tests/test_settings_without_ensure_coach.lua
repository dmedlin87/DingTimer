dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.EnsureCoachConfig = nil
DingTimerDB.coach = {
  goal = "30m",
  alertsEnabled = false,
  chatAlerts = true,
  stabilizeEarlyPace = false,
  idleSeconds = 45,
  paceDropPct = 20,
  alertCooldownSeconds = 33,
}

local ok, err = pcall(function()
  NS.InitMainWindow()
  NS.ShowMainWindow(4)
end)

assert_true(ok, "settings should open even when NS.EnsureCoachConfig is missing")
assert_true(DingTimerSettingsPanel ~= nil and DingTimerSettingsPanel:IsShown(), "settings panel should still be shown")
assert_eq(DingTimerSettingsPanel.controls.goalValue:GetText(), "Goal: 30m", "settings should render the raw goal value without the helper")
assert_eq(
  DingTimerSettingsPanel.controls.coachInfo:GetText(),
  "Idle after 45s  |  Pace drop threshold 20%  |  Alert cooldown 33s",
  "settings should reflect the raw coach timing values without the helper"
)
assert_false(DingTimerSettingsPanel.controls.alertsEnabled:GetChecked(), "alerts should respect the raw DB value without the helper")
assert_true(DingTimerSettingsPanel.controls.chatAlerts:GetChecked(), "chat alerts should respect the raw DB value without the helper")
assert_false(DingTimerSettingsPanel.controls.stabilizeEarlyPace:GetChecked(), "stabilized pace should respect the raw DB value without the helper")
assert_true(err == nil, "settings should not throw when EnsureCoachConfig is missing")

print("Settings without EnsureCoachConfig test passed!")
