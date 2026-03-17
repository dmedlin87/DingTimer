dofile("tests/mocks.lua")

SetProfileIdentity("Leveler", "Azeroth", "HUNTER", 12, "Hunter")

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
LoadAddonFile("DingTimer/DingTimer.lua", NS)

CreateFrame = baseCreateFrame

DingTimerDB = nil
SetTime(100)
SetXP(0, 1000)
SetMoney(0)
SetZone("Elwynn")
SetLevel(12)
ClearChatLog()

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

SetTime(130)
SetXP(300, 1000)
onEvent(eventFrameRef, "PLAYER_XP_UPDATE", "player")
SetMoney(250)
onEvent(eventFrameRef, "PLAYER_MONEY")

SetZone("Westfall")
SetTime(160)
onEvent(eventFrameRef, "ZONE_CHANGED_NEW_AREA")

local coachSegments = NS.GetCoachSegments(false, 160)
assert_eq(1, #coachSegments, "zone-change event should finalize the previous segment")
assert_eq("ZONE_CHANGED", coachSegments[1].reason, "zone-change event should record a zone segment")
assert_eq("Elwynn", coachSegments[1].zone, "zone-change event should preserve the old zone on the finalized segment")

local currentSegments = NS.GetCoachSegments(true, 160)
assert_eq("Westfall", currentSegments[#currentSegments].zone, "zone-change event should start a new segment in the new zone")

SetTime(190)
SetXP(500, 1000)
onEvent(eventFrameRef, "PLAYER_XP_UPDATE", "player")
SetMoney(400)
onEvent(eventFrameRef, "PLAYER_MONEY")

ClearChatLog()
SetLevel(13)
SetTime(220)
onEvent(eventFrameRef, "PLAYER_LEVEL_UP", 13)

local profile = NS.GetProfileStore(true)
assert_eq(1, #profile.sessions, "level-up event should record the finished session")

local record = profile.sessions[1]
assert_eq("LEVEL_UP", record.reason, "level-up record should carry the LEVEL_UP reason")
assert_eq(12, record.levelStart, "level-up record should keep the previous level as levelStart")
assert_eq(13, record.levelEnd, "level-up record should capture the new current level")
assert_eq("Elwynn", record.zone, "level-up record should use the highest-XP segment zone")
assert_eq(2, #record.segments, "level-up record should preserve both completed segments")
assert_eq("ZONE_CHANGED", record.segments[1].reason, "first segment should come from the zone change")
assert_eq("LEVEL_UP", record.segments[2].reason, "current segment should finalize with the level-up reason")
assert_true(record.coachSummary ~= nil, "level-up record should include a coach summary")
assert_true(DingTimerDB.coach.lastRecap ~= nil, "level-up should persist the latest recap")

assert_eq(220, NS.state.sessionStartTime, "level-up event should reset the session timer")
assert_eq(13, NS.state.levelStart, "level-up event should start the next session at the new level")
assert_eq(0, NS.state.sessionXP, "level-up event should clear session XP")
assert_eq(0, #NS.state.events, "level-up event should clear rolling XP events")

local chatLog = GetChatLog()
assert_true(#chatLog >= 2, "level-up event should emit the ding announcement")
assertStringMatch("LEVEL UP", chatLog[1], "level-up announcement should include the level-up banner")

print("Event + level-up + zone integration test passed!")
