dofile("tests/mocks.lua")

SetProfileIdentity("Integrator", "Azeroth", "PALADIN", 42, "Paladin")

local eventFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not eventFrame then
    eventFrame = frame
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

CreateFrame = baseCreateFrame

DingTimerDB = nil
SetTime(10)
SetXP(0, 1000)
SetMoney(0)
SetZone("Elwynn")

assert_true(eventFrame ~= nil, "event frame should be created by DingTimer.lua")
---@type table<string, any>?
local eventFrameRef = eventFrame
if not eventFrameRef then
  error("event frame should be created by DingTimer.lua")
end

local onEvent = eventFrameRef._scripts and eventFrameRef._scripts["OnEvent"] or nil
assert_true(onEvent ~= nil, "event frame should have an OnEvent handler")
if not onEvent then
  error("event frame should have an OnEvent handler")
end

onEvent(eventFrameRef, "ADDON_LOADED", "DingTimer")
assert_true(DingTimerDB ~= nil, "ADDON_LOADED should initialize the store")

onEvent(eventFrameRef, "PLAYER_LOGIN")
assert_eq(10, NS.state.sessionStartTime, "PLAYER_LOGIN should reset session state")

SetTime(70)
SetXP(150, 1000)
onEvent(eventFrameRef, "PLAYER_XP_UPDATE", "player")
assert_eq(150, NS.state.sessionXP, "PLAYER_XP_UPDATE should route through core XP handling")

SetTime(90)
onEvent(eventFrameRef, "PLAYER_LOGOUT")
local profile = NS.GetProfileStore(true)
assert_eq(1, #profile.sessions, "PLAYER_LOGOUT should record the current session")
assert_eq("LOGOUT", profile.sessions[1].reason, "logout record should carry the LOGOUT reason")

for i = 2, 25 do
  profile.sessions[i] = {
    id = "seed-" .. i,
    avgXph = 1000 + i,
    durationSec = 60 + i,
    levelStart = 42,
    levelEnd = 42,
    moneyNetCopper = i,
    zone = "Zone" .. i,
    reason = "MANUAL_RESET",
  }
end

NS.InitMainWindow()
NS.ShowMainWindow(4)

local settingsPanel = DingTimerSettingsPanel
assert_true(settingsPanel ~= nil and settingsPanel:IsShown(), "settings panel should be visible")

settingsPanel.controls.cycleGoalButton:GetScript("OnClick")(settingsPanel.controls.cycleGoalButton)
assert_eq("30m", DingTimerDB.coach.goal, "settings goal button should route through shared goal action")

settingsPanel.controls.keep10Button:GetScript("OnClick")(settingsPanel.controls.keep10Button)
assert_eq(10, DingTimerDB.xp.keepSessions, "settings keep button should update retention through shared action")
assert_eq(10, #profile.sessions, "settings keep button should trim current profile sessions")

print("Event + settings integration test passed!")
