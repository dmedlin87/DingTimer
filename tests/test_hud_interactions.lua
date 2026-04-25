dofile("tests/mocks.lua")

---@class InteractionTestFrame
---@field progressFill table
---@field progressBar table
---@field _hudGlow table
---@field _hudBottomLine table
---@field _displayedProgress number?
---@field _targetProgress number?
---@field _progressAnim table?
---@field _gainPulse table?
---@field _hovered boolean?
---@field GetScript fun(self: InteractionTestFrame, scriptName: string): function?
---@field GetPoint fun(self: InteractionTestFrame): string, any, string, number, number
---@field SetPoint fun(self: InteractionTestFrame, point: string, relativeTo: any, relativePoint: string, xOfs: number, yOfs: number)
---@field IsShown fun(self: InteractionTestFrame): boolean
---@field Hide fun(self: InteractionTestFrame)
---@field Show fun(self: InteractionTestFrame)

local snapshot = {
  progress = 0,
}

local NS = {
  C = { base = "", r = "" },
  BuildHUDText = function()
    return "TTL", "detail"
  end,
  GetSessionSnapshot = function()
    return snapshot
  end,
  RefreshHUDPopup = function() end,
  UpdateHeartbeatTicker = function() end,
}

DingTimerDB = {
  float = true,
  floatLocked = true,
  floatShowInCombat = false,
}

LoadAddonFile("DingTimer/Core_HUD.lua", NS)

NS.setFloatVisible(true)
local frame = NS.GetFloatFrame()
assert_true(frame ~= nil, "HUD should be available for interaction tests")
---@cast frame InteractionTestFrame

it("clamps rendered level progress to the XP bar bounds", function()
  snapshot.progress = 2
  NS.RefreshFloatingHUD()
  frame:GetScript("OnUpdate")(frame, 1)
  assert_eq(frame.progressFill:GetWidth(), frame.progressBar:GetWidth(), "progress above 100% should render as a full bar")
  assert_true(frame.progressFill:IsShown(), "full clamped progress should show the fill")

  snapshot.progress = -0.25
  NS.RefreshFloatingHUD()
  assert_eq(0, frame.progressFill:GetWidth(), "negative progress should render as an empty bar")
  assert_false(frame.progressFill:IsShown(), "empty clamped progress should hide the fill")

  snapshot.progress = 0.001
  NS.RefreshFloatingHUD()
  frame:GetScript("OnUpdate")(frame, 1)
  assert_eq(2, frame.progressFill:GetWidth(), "non-zero progress should keep a visible minimum fill width")
  assert_true(frame.progressFill:IsShown(), "minimum non-zero progress should show the fill")
end)

it("shows hover help for locked and movable HUD states", function()
  ClearTooltip()
  DingTimerDB.floatLocked = true
  frame:GetScript("OnEnter")(frame)

  local lockedTooltip = GetTooltipLines()
  assert_true(frame._hovered, "hovering the HUD should set hover state")
  assert_true(GameTooltip:IsShown(), "hovering the HUD should show the tooltip")
  assertStringMatch("DingTimer", lockedTooltip[1], "HUD tooltip should identify the addon")
  assertStringMatch("Left-click to toggle settings", lockedTooltip[2], "locked HUD tooltip should advertise left-click settings")
  assertStringMatch("Right-click to toggle settings", lockedTooltip[3], "HUD tooltip should advertise right-click settings")
  assert_true(frame._hudGlow:GetAlpha() > 0.12, "hovering should raise the HUD glow alpha")

  frame:GetScript("OnLeave")(frame)
  assert_false(frame._hovered, "leaving the HUD should clear hover state")
  assert_false(GameTooltip:IsShown(), "leaving the HUD should hide the tooltip")
  assert_eq(0.12, frame._hudGlow:GetAlpha(), "leaving should restore the resting HUD glow alpha")

  ClearTooltip()
  DingTimerDB.floatLocked = false
  frame:GetScript("OnEnter")(frame)
  local movableTooltip = GetTooltipLines()
  assertStringMatch("Left-drag to move the HUD", movableTooltip[2], "unlocked HUD tooltip should advertise dragging")
  frame:GetScript("OnLeave")(frame)
end)

it("persists drag position only when the HUD is unlocked", function()
  local moveStarts = 0
  local moveStops = 0
  frame.StartMoving = function()
    moveStarts = moveStarts + 1
  end
  frame.StopMovingOrSizing = function()
    moveStops = moveStops + 1
  end

  DingTimerDB.floatLocked = true
  DingTimerDB.floatPosition = nil
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 34)
  frame:GetScript("OnDragStart")(frame)
  frame:GetScript("OnDragStop")(frame)
  assert_eq(0, moveStarts, "locked HUD should not start moving")
  assert_eq(0, moveStops, "locked HUD should not stop and persist a drag")
  assert_true(DingTimerDB.floatPosition == nil, "locked drag should not persist a position")

  DingTimerDB.floatLocked = false
  frame:GetScript("OnDragStart")(frame)
  frame:GetScript("OnDragStop")(frame)
  assert_eq(1, moveStarts, "unlocked HUD should start moving")
  assert_eq(1, moveStops, "unlocked HUD should stop moving")
  assert_eq("BOTTOMLEFT", DingTimerDB.floatPosition.point, "unlocked drag should persist the anchor point")
  assert_eq("BOTTOMLEFT", DingTimerDB.floatPosition.relativePoint, "unlocked drag should persist the relative point")
  assert_eq(12, DingTimerDB.floatPosition.xOfs, "unlocked drag should persist the x offset")
  assert_eq(34, DingTimerDB.floatPosition.yOfs, "unlocked drag should persist the y offset")
end)

it("resets position and clears active animations when hidden", function()
  DingTimerDB.floatPosition = {
    point = "BOTTOMLEFT",
    relativePoint = "BOTTOMLEFT",
    xOfs = 12,
    yOfs = 34,
  }

  assert_true(NS.ResetFloatPosition(), "resetting the HUD position should report success")
  assert_true(DingTimerDB.floatPosition == nil, "resetting should clear the persisted HUD position")
  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
  assert_eq("CENTER", point, "resetting should restore the default anchor point")
  assert_eq(UIParent, relativeTo, "resetting should anchor to UIParent")
  assert_eq("CENTER", relativePoint, "resetting should restore the default relative point")
  assert_eq(0, xOfs, "resetting should clear the x offset")
  assert_eq(220, yOfs, "resetting should restore the default y offset")

  frame._displayedProgress = 0.75
  frame._targetProgress = 0.75
  frame._progressAnim = { target = 0.8 }
  NS.TriggerFloatGainPulse(-1)
  assert_eq(0, frame._displayedProgress, "gain pulses should clamp regressed progress at zero")
  assert_eq(0, frame._targetProgress, "gain pulses should clamp target progress at zero")
  assert_true(frame._gainPulse ~= nil, "visible gain pulse should be armed")
  assert_true(frame:GetScript("OnUpdate") ~= nil, "visible gain pulse should start animation updates")

  frame:Hide()
  assert_true(frame._gainPulse == nil, "hiding the HUD should clear gain pulse state")
  assert_true(frame._progressAnim == nil, "hiding the HUD should clear progress animation state")
  assert_true(frame:GetScript("OnUpdate") == nil, "hiding the HUD should stop animation updates")
end)

run_tests()
