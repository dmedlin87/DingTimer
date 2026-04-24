dofile("tests/mocks.lua")

---@class TestFontRegion
---@field GetText fun(self: TestFontRegion): string
---@field GetPoint fun(self: TestFontRegion): string, any, string, number, number
---@field IsShown fun(self: TestFontRegion): boolean
---@field _fontObject string?
---@field _justifyH string?

---@class TestTextureRegion
---@field IsShown fun(self: TestTextureRegion): boolean
---@field GetAlpha fun(self: TestTextureRegion): number
---@field GetWidth fun(self: TestTextureRegion): number
---@field GetHeight fun(self: TestTextureRegion): number
---@field GetPoint fun(self: TestTextureRegion): string, any, string, number, number
---@field _drawLayer string?
---@field _subLevel number?

---@class TestFrameRegion
---@field GetPoint fun(self: TestFrameRegion): string, any, string, number, number
---@field GetWidth fun(self: TestFrameRegion): number
---@field GetHeight fun(self: TestFrameRegion): number
---@field IsShown fun(self: TestFrameRegion): boolean

---@class TestHeartbeatTicker
---@field interval number
---@field callback fun()?
---@field cancelled boolean
---@field Cancel fun(self: TestHeartbeatTicker)
---@field Fire fun(self: TestHeartbeatTicker)

---@class TestHUDFrame
---@field titleText TestFontRegion
---@field subText TestFontRegion
---@field progressBar TestFrameRegion
---@field progressFill TestTextureRegion
---@field progressPulse TestTextureRegion
---@field progressSpark TestTextureRegion
---@field progressTicks TestTextureRegion[]
---@field graphArea TestFrameRegion?
---@field graphBars TestTextureRegion[]?
---@field graphHitboxes TestFrameRegion[]?
---@field graphPeakText TestFontRegion?
---@field _dingGlow TestTextureRegion?
---@field _dingAccent TestTextureRegion?
---@field GetPoint fun(self: TestHUDFrame): string, any, string, number, number
---@field GetWidth fun(self: TestHUDFrame): number
---@field GetHeight fun(self: TestHUDFrame): number
---@field GetScript fun(self: TestHUDFrame, scriptName: string): function?

---@type TestHUDFrame?
local capturedFrame = nil
local baseCreateFrame = CreateFrame
CreateFrame = function(frameType, name, parent, template)
  local frame = baseCreateFrame(frameType, name, parent, template)
  if not name and not capturedFrame then
    ---@cast frame TestHUDFrame
    capturedFrame = frame
  end
  return frame
end

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/HUDText.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)

DingTimerDB = {
  enabled = false,
  float = true,
  floatLocked = true,
  windowSeconds = 60,
  mode = "full",
}

NS.InitStore()
SetTime(0)
SetXP(0, 1000)
NS.resetXPState()
NS.setFloatVisible(true)
NS.UpdateHeartbeatTicker()

local ticker = C_Timer._lastTicker
assert_true(ticker == nil, "heartbeat ticker should stay stopped until there is live XP activity")

SetTime(60)
SetXP(100, 1000)
NS.onXPUpdate()

ticker = C_Timer._lastTicker
assert_true(ticker ~= nil, "heartbeat ticker should start after an XP gain creates live HUD activity")
---@cast ticker TestHeartbeatTicker
assert_eq(ticker.interval, 1, "heartbeat ticker should tick every second")

local frame = capturedFrame
assert_true(capturedFrame ~= nil, "floating HUD frame should be created")
---@cast frame TestHUDFrame
assert_eq("9m 0s to level", frame.titleText:GetText(), "HUD should show only TTL text on the top line")
assertStringMatch("6,000 XP/hr", frame.subText:GetText(), "HUD should show the rolling XP/hr immediately after a gain")
assertStringMatch("Last +", frame.subText:GetText(), "HUD should show the most recent XP gain on the second line")
assertStringMatch("Last +100 (9)", frame.subText:GetText(), "HUD should show the most recent XP gain and gains remaining estimate on the second line")
assertStringMatch("Need 900", frame.subText:GetText(), "HUD should show the remaining XP needed to level")
assert_true(string.find(frame.titleText:GetText(), "DingTimer", 1, true) == nil, "HUD title should not include the addon name")
assert_eq("GameFontHighlightLarge", frame.titleText._fontObject, "HUD TTL text should use the larger title font")
assert_eq("CENTER", frame.titleText._justifyH, "HUD TTL title text should stay centered in the wider frame")
assert_eq(385, frame:GetWidth(), "HUD frame should be 25% wider than the original 308px width")
assert_true(frame.progressBar ~= nil, "HUD should create an internal XP progress bar")
assert_eq(345, frame.progressBar:GetWidth(), "HUD XP bar should stretch with the wider frame")
local barPoint, barRelativeTo, barRelativePoint, _, barYOffset = frame.progressBar:GetPoint()
assert_eq("BOTTOM", barPoint, "HUD XP bar should sit below the detail label")
assert_eq(frame, barRelativeTo, "HUD XP bar should anchor to the HUD frame")
assert_eq("BOTTOM", barRelativePoint, "HUD XP bar should stay at the bottom of the HUD")
assert_eq(11, barYOffset, "HUD XP bar should leave room for the bottom border")
local subPoint, subRelativeTo, subRelativePoint = frame.subText:GetPoint()
assert_eq("BOTTOM", subPoint, "HUD detail label should sit above the XP bar")
assert_eq(frame.progressBar, subRelativeTo, "HUD detail label should anchor to the XP bar")
assert_eq("TOP", subRelativePoint, "HUD detail label should stay above the XP bar")
assert_false(frame._dingGlow and frame._dingGlow:IsShown(), "HUD should hide the shared top glow behind the TTL label")
assert_false(frame._dingAccent and frame._dingAccent:IsShown(), "HUD should hide the shared top accent behind the TTL label")
assert_true(frame.progressPulse ~= nil, "HUD should create a gain pulse texture")
assert_true(frame.progressSpark ~= nil, "HUD should create a gain spark texture")
assert_true(frame.progressTicks ~= nil, "HUD should keep XP tick markers available for layering checks")
for i = 1, 3 do
  local tick = frame.progressTicks[i]
  assert_true(tick ~= nil, "HUD should create XP tick marker " .. i)
  assert_eq("OVERLAY", tick._drawLayer, "HUD XP tick markers should render above the progress fill")
  assert_eq(2, tick._subLevel, "HUD XP tick markers should render above other bar overlay shading")
end

local savedPoint, savedRelativeTo, savedRelativePoint, savedX, savedY = frame:GetPoint()
NS.SetHUDProfile("compact")
assert_eq("compact", DingTimerDB.hudProfile, "profile switch should persist the compact HUD profile")
assert_eq(308, frame:GetWidth(), "compact profile should apply the smaller frame width")
assert_eq(54, frame:GetHeight(), "compact profile should apply the smaller frame height")
assert_eq(276, frame.progressBar:GetWidth(), "compact profile should apply the smaller XP bar width")
assert_eq(8, frame.progressBar:GetHeight(), "compact profile should apply the smaller XP bar height")
assert_eq("GameFontHighlight", frame.titleText._fontObject, "compact profile should use a smaller title font")
assert_true(frame.subText:IsShown(), "compact profile should keep the detail line visible")
local compactPoint, compactRelativeTo, compactRelativePoint, compactX, compactY = frame:GetPoint()
assert_eq(savedPoint, compactPoint, "profile switching should not reset the saved HUD anchor point")
assert_eq(savedRelativeTo, compactRelativeTo, "profile switching should not reset the saved HUD relative target")
assert_eq(savedRelativePoint, compactRelativePoint, "profile switching should not reset the saved HUD relative point")
assert_eq(savedX, compactX, "profile switching should not reset the saved HUD x offset")
assert_eq(savedY, compactY, "profile switching should not reset the saved HUD y offset")

NS.SetHUDProfile("bar_ttl")
assert_eq("bar_ttl", DingTimerDB.hudProfile, "profile switch should persist the bar+TTL HUD profile")
assert_eq(260, frame:GetWidth(), "bar+TTL profile should apply the focused frame width")
assert_eq(38, frame:GetHeight(), "bar+TTL profile should apply the focused frame height")
assert_eq(232, frame.progressBar:GetWidth(), "bar+TTL profile should apply the focused XP bar width")
assert_eq("9m 0s", frame.titleText:GetText(), "bar+TTL profile should show short TTL text")
assert_eq("", frame.subText:GetText(), "bar+TTL profile should clear the detail text")
assert_false(frame.subText:IsShown(), "bar+TTL profile should hide the detail line")
local _, _, _, firstTickX = frame.progressTicks[1]:GetPoint()
assert_eq(58, firstTickX, "bar+TTL tick markers should reposition for the focused XP bar width")

NS.SetHUDProfile("full")
assert_eq("full", DingTimerDB.hudProfile, "profile switch should return to the full HUD profile")
assert_eq(385, frame:GetWidth(), "full profile should restore the default frame width")
assert_eq(345, frame.progressBar:GetWidth(), "full profile should restore the default XP bar width")
assertStringMatch("to level", frame.titleText:GetText(), "full profile should restore the full TTL title")
assert_true(frame.subText:IsShown(), "full profile should restore the detail line")

assert_true(frame:GetScript("OnUpdate") ~= nil, "HUD should animate when XP is gained")

local onUpdate = frame:GetScript("OnUpdate")
---@cast onUpdate fun(self: TestHUDFrame, elapsed: number)
onUpdate(frame, 0.3)

local expectedFillWidth = math.floor((frame.progressBar:GetWidth() * 0.1) + 0.5)
if expectedFillWidth < 2 then
  expectedFillWidth = 2
end

assert_eq(expectedFillWidth, frame.progressFill:GetWidth(), "HUD XP bar should reflect the current level progress")
assert_true(frame.progressPulse:IsShown(), "HUD should show a pulse texture after gaining XP")
assert_true(frame.progressPulse:GetAlpha() > 0, "HUD pulse should fade instead of remaining static")
assert_true(frame.progressSpark:IsShown(), "HUD should show a spark at the leading edge while the gain pulse is active")

onUpdate(frame, 1)
assert_true(frame:GetScript("OnUpdate") == nil, "HUD should stop animating once the pulse finishes")
assert_false(frame.progressPulse:IsShown(), "HUD pulse should hide after the animation completes")

SetTime(95)
ticker:Fire()

assertStringMatch("idle 35s", frame.titleText:GetText(), "HUD should mark retained rolling rates as idle on the TTL label")
assert_true(string.find(frame.subText:GetText(), "(idle", 1, true) == nil, "HUD detail label should leave idle state on the TTL label")

SetTime(121)
ticker:Fire()

assert_eq(0, #NS.state.events, "heartbeat refresh should prune expired XP events")
assert_eq(0, NS.state.windowXP, "window XP should decay when the rolling window expires")
assertStringMatch("No XP in 60s", frame.subText:GetText(), "HUD should show when the rolling window is empty")
assertStringMatch("Last +100 (9)", frame.subText:GetText(), "HUD should keep the last gain and gains remaining estimate visible after the rolling window expires")
assertStringMatch("Need 900", frame.subText:GetText(), "HUD should keep the remaining XP needed visible after the rolling window expires")
assert_eq("?? to level", frame.titleText:GetText(), "HUD should fall back to TTL-only text when no pace is available")
assert_eq(expectedFillWidth, frame.progressFill:GetWidth(), "HUD XP bar should keep the player's actual level progress after the rolling window expires")
assert_true(ticker.cancelled, "heartbeat ticker should stop once the rolling window no longer needs live HUD refreshes")

SetTime(200)
SetXP(100000000, 1000000000)
NS.resetXPState()
SetTime(210)
SetXP(200000000, 1000000000)
NS.onXPUpdate()

assertStringMatch("36.0B XP/hr", frame.subText:GetText(), "HUD should compact very large XP/hr values")
assertStringMatch("Last +100.0M (8)", frame.subText:GetText(), "HUD should compact very large last-gain text")
assertStringMatch("Need 800.0M", frame.subText:GetText(), "HUD should compact very large remaining-XP text")

SetTime(300)
SetXP(0, 1000)
NS.resetXPState()
SetTime(360)
SetXP(100, 1000)
NS.onXPUpdate()
SetTime(380)
SetXP(140, 1000)
NS.onXPUpdate()
NS.SetHUDProfile("graph")
assert_eq("graph", DingTimerDB.hudProfile, "profile switch should persist the graph HUD profile")
assert_eq(385, frame:GetWidth(), "graph profile should keep the wide HUD frame")
assert_eq(96, frame:GetHeight(), "graph profile should make room for the taller XP graph")
assert_true(frame.graphArea ~= nil, "graph profile should create a graph area")
assert_true(frame.graphArea:IsShown(), "graph profile should show the graph area")
assert_eq(46, frame.graphArea:GetHeight(), "graph profile should use the taller graph area")
assert_true(frame.graphBackdrop:IsShown(), "graph profile should show the graph backdrop")
assert_true(frame.graphGuides[1]:IsShown(), "graph profile should show graph guide lines")
assert_false(frame.progressBar:IsShown(), "graph profile should hide the level-progress bar")
assert_true(frame.graphBars ~= nil, "graph profile should create graph bars")
assert_eq(18, #frame.graphBars, "graph profile should create one bar per graph bucket")
assert_true(frame.graphHitboxes ~= nil, "graph profile should create graph hover hitboxes")
assert_eq(18, #frame.graphHitboxes, "graph profile should create one hover hitbox per graph bucket")
assert_true(frame.graphBars[12]:GetHeight() > frame.graphBars[18]:GetHeight(), "older larger gains should scale taller than smaller recent gains")
assert_true(frame.graphBars[18]:GetHeight() >= 3, "graph profile should keep smaller gains visible")
assertStringMatch("Max +100", frame.graphPeakText:GetText(), "graph profile should label the largest bucket gain")
assert_eq(96, frame.graphPeakText:GetWidth(), "graph profile should constrain the max label above the graph")
local peakPoint, peakRelativeTo, peakRelativePoint, _, peakY = frame.graphPeakText:GetPoint()
assert_eq("BOTTOMRIGHT", peakPoint, "graph max label should sit above the plot area")
assert_eq(frame.graphArea, peakRelativeTo, "graph max label should anchor to the graph area")
assert_eq("TOPRIGHT", peakRelativePoint, "graph max label should sit above the graph top line")
assert_eq(1, peakY, "graph max label should clear the graph top line")
local buckets, peak = NS.BuildXPGraphBuckets(NS.state.events, 380, 60, 6)
assert_eq(100, buckets[4], "graph bucket helper should place the older gain in the correct interval bucket")
assert_eq(40, buckets[6], "graph bucket helper should place the current gain in the newest bucket")
assert_eq(100, peak, "graph bucket helper should return the peak bucket XP")
ClearTooltip()
local newestGraphHitbox = frame.graphHitboxes[18]
newestGraphHitbox:GetScript("OnEnter")(newestGraphHitbox)
local tooltipLines = GetTooltipLines()
assert_true(GameTooltip:IsShown(), "graph bar hover should show a tooltip")
assertStringMatch("DingTimer Graph", tooltipLines[1], "graph bar tooltip should identify the graph")
assertStringMatch("+40 XP", tooltipLines[2], "graph bar tooltip should show the hovered bucket XP")
assertStringMatch("Latest 3s bucket", tooltipLines[3], "graph bar tooltip should show the hovered bucket time range")
assertStringMatch("Peak +100", tooltipLines[4], "graph bar tooltip should show the peak bucket for context")
newestGraphHitbox:GetScript("OnLeave")(newestGraphHitbox)
assert_false(GameTooltip:IsShown(), "graph bar tooltip should hide when leaving the hovered bar")
local olderGraphHeight = frame.graphBars[12]:GetHeight()
local newestGraphHeight = frame.graphBars[18]:GetHeight()
SetTime(395)
NS.RefreshFloatingHUD(395)
assert_eq(olderGraphHeight, frame.graphBars[12]:GetHeight(), "graph profile should keep older gain bars stable while standing still")
assert_eq(newestGraphHeight, frame.graphBars[18]:GetHeight(), "graph profile should keep the newest gain bar stable while standing still")
local stableBuckets, stablePeak = NS.BuildXPGraphBuckets(NS.state.events, 395, 60, 6)
assert_eq(100, stableBuckets[4], "graph bucket helper should not slide older gains just because time advanced")
assert_eq(40, stableBuckets[6], "graph bucket helper should keep the newest gain anchored while standing still")
assert_eq(100, stablePeak, "graph bucket helper should preserve the peak while standing still")

NS.SetHUDProfile("full")
assert_false(frame.graphArea:IsShown(), "leaving the graph profile should hide the graph area")
assert_false(frame.graphBackdrop:IsShown(), "leaving the graph profile should hide the graph backdrop")
assert_true(frame.progressBar:IsShown(), "leaving the graph profile should restore the XP bar")

print("HUD rolling refresh test passed!")
