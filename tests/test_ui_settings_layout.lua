dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()
NS.resetXPState()

local function assertAnchor(frame, relativeTo, point, relativePoint, xOfs, yOfs, label)
  local actualPoint, actualRelativeTo, actualRelativePoint, actualXOfs, actualYOfs = frame:GetPoint()
  assert_eq(actualPoint, point, label .. " point")
  assert_eq(actualRelativeTo, relativeTo, label .. " relative frame")
  assert_eq(actualRelativePoint, relativePoint, label .. " relative point")
  assert_eq(actualXOfs, xOfs, label .. " x offset")
  assert_eq(actualYOfs, yOfs, label .. " y offset")
end

it("keeps settings value labels anchored to their control rows", function()
  NS.InitSettingsPanel(nil)

  assert_true(DingTimerSettingsPanel ~= nil, "settings panel should be created")
  assert_true(NS and NS.UI, "UI helpers should be available")

  assertAnchor(
    DingTimerSettingsPanel.controls.modeValue,
    DingTimerSettingsPanel.controls.modeButton,
    "TOPLEFT",
    "TOPRIGHT",
    10,
    -5,
    "mode value"
  )
  assertAnchor(
    DingTimerSettingsPanel.controls.windowValue,
    DingTimerSettingsPanel.controls.windowButton,
    "TOPLEFT",
    "TOPRIGHT",
    10,
    -5,
    "window value"
  )
  assertAnchor(
    DingTimerSettingsPanel.controls.goalValue,
    DingTimerSettingsPanel.controls.cycleGoalButton,
    "TOPLEFT",
    "TOPRIGHT",
    10,
    -5,
    "goal value"
  )
  assertAnchor(
    DingTimerSettingsPanel.controls.coachInfo,
    DingTimerSettingsPanel.controls.recapButton,
    "TOPLEFT",
    "TOPRIGHT",
    8,
    -6,
    "coach info"
  )
end)

it("parents busy settings controls inside their owning sections", function()
  NS.InitSettingsPanel(nil)

  assert_true(DingTimerSettingsPanel.sections ~= nil, "settings sections should be tracked")

  local outputPoint, outputRelativeTo = DingTimerSettingsPanel.controls.enabled:GetPoint()
  assert_eq(outputPoint, "TOPLEFT", "output toggle should use top-left section anchoring")
  assert_eq(outputRelativeTo, DingTimerSettingsPanel.sections.output.content, "output toggle should be contained by output section content")

  local hudPoint, hudRelativeTo = DingTimerSettingsPanel.controls.float:GetPoint()
  assert_eq(hudPoint, "TOPLEFT", "hud toggle should use top-left section anchoring")
  assert_eq(hudRelativeTo, DingTimerSettingsPanel.sections.hud.content, "hud toggle should be contained by hud section content")

  local graphPoint, graphRelativeTo = DingTimerSettingsPanel.controls.cycleScaleButton:GetPoint()
  assert_eq(graphPoint, "TOPLEFT", "graph controls should use top-left section anchoring")
  assert_eq(graphRelativeTo, DingTimerSettingsPanel.sections.graph.content, "graph controls should be contained by graph section content")

  local pvpPoint, pvpRelativeTo = DingTimerSettingsPanel.controls.togglePvpMode:GetPoint()
  assert_eq(pvpPoint, "TOPLEFT", "pvp controls should use top-left section anchoring")
  assert_eq(pvpRelativeTo, DingTimerSettingsPanel.sections.pvp.content, "pvp controls should be contained by pvp section content")
end)

run_tests()
