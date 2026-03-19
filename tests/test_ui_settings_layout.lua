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

run_tests()
