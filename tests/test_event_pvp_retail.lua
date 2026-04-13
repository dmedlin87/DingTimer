dofile("tests/mocks.lua")

SetProfileIdentity("RetailPVPer", "Azeroth", "MONK", 80, "Monk")
SetHonorApiFlavor("retail")

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
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Pvp.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

CreateFrame = baseCreateFrame

DingTimerDB = nil
SetTime(100)
SetXP(0, 1000)
SetMoney(0)
SetHonor(1000, 15000)
SetLifetimeHKs(10)
SetZone("Warsong Gulch")
SetInstanceState(true, "pvp")

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
onEvent(eventFrameRef, "PLAYER_LOGIN")

NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)

SetTime(110)
SetHonor(1250, 15000)
onEvent(eventFrameRef, "CURRENCY_DISPLAY_UPDATE", 1792)

local snapshot = NS.GetPvpSnapshot(110)
assert_eq(250, snapshot.sessionHonor, "retail currency updates should increase session honor")
assert_eq(1250, snapshot.currentHonor, "retail currency updates should refresh the current honor total")

SetTime(120)
SetHonor(1600, 15000)
onEvent(eventFrameRef, "CURRENCY_DISPLAY_UPDATE", 999)

snapshot = NS.GetPvpSnapshot(120)
assert_eq(250, snapshot.sessionHonor, "non-honor currency updates should be ignored")
assert_eq(1250, snapshot.currentHonor, "ignored currency updates should leave the cached honor total unchanged")

SetHonorApiFlavor("legacy")

print("Retail PvP event integration test passed!")
