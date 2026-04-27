dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/HUDText.lua", NS)
LoadAddonFile("DingTimer/HUDGraph.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)

DingTimerDB = {
  enabled = true,
  dingSoundEnabled = true,
  float = true,
  floatLocked = true,
  floatShowInCombat = false,
  windowSeconds = 600,
  mode = "full",
}

NS.InitStore()
NS.ensureFloat()
NS.setFloatVisible(true)

local floatFrame = NS.GetFloatFrame()
local popup = NS.InitHUDPopup()

local function buttonFillAlpha(button)
  return button and button._dingFill and button._dingFill._color and button._dingFill._color[4]
end

it("toggles the popup from HUD clicks according to lock state", function()
  NS.HideHUDPopup()

  floatFrame:GetScript("OnClick")(floatFrame, "LeftButton")
  assert_true(NS.IsHUDPopupShown(), "locked left-click should open the popup")

  floatFrame:GetScript("OnClick")(floatFrame, "LeftButton")
  assert_false(NS.IsHUDPopupShown(), "locked left-click should close the popup")

  DingTimerDB.floatLocked = false
  popup:Refresh()
  floatFrame:GetScript("OnClick")(floatFrame, "LeftButton")
  assert_false(NS.IsHUDPopupShown(), "unlocked left-click should not toggle the popup")

  floatFrame:GetScript("OnClick")(floatFrame, "RightButton")
  assert_true(NS.IsHUDPopupShown(), "right-click should always toggle the popup")
end)

it("anchors to the HUD when visible and to UIParent when opened without the HUD", function()
  NS.ShowHUDPopup()
  local point, relativeTo = popup:GetPoint()
  assert_eq("TOP", point, "popup should anchor below the HUD when the HUD is visible")
  assert_eq(relativeTo, floatFrame, "popup should anchor to the HUD frame")

  NS.SetFloatEnabled(false)
  NS.ShowHUDPopup()
  local centerPoint, centerRelativeTo = popup:GetPoint()
  assert_eq("CENTER", centerPoint, "popup should center itself when the HUD is hidden")
  assert_eq(centerRelativeTo, UIParent, "popup should anchor to UIParent when the HUD is hidden")
end)

it("hides the popup with the HUD when combat visibility hides the HUD", function()
  NS.SetFloatEnabled(true)
  DingTimerDB.floatShowInCombat = false
  NS.ShowHUDPopup()
  assert_true(NS.IsHUDPopupShown(), "precondition: popup should be visible")

  local baseInCombatLockdown = InCombatLockdown
  InCombatLockdown = function()
    return true
  end

  NS.setFloatVisible(true)
  assert_false(floatFrame:IsShown(), "HUD should hide when combat starts")
  assert_false(NS.IsHUDPopupShown(), "popup should not remain centered during combat hiding")

  InCombatLockdown = baseInCombatLockdown
  NS.setFloatVisible(true)
end)

it("updates DB values and HUD text immediately from popup controls", function()
  NS.SetFloatEnabled(true)
  SetTime(0)
  SetXP(0, 1000)
  NS.resetXPState()
  NS.RefreshFloatingHUD()
  popup:Refresh()

  assert_eq(0.96, buttonFillAlpha(popup.controls.profileFull), "full profile should be active by default")
  assert_eq("Graph", popup.controls.profileGraph:GetText(), "graph profile button should use the full label")
  assert_true(popup.controls.dingSoundEnabled == nil, "popup should not expose the level-up sound toggle")
  assert_true(popup.controls.previewSound == nil, "popup should not expose the level-up sound preview button")
  popup.controls.profileCompact:GetScript("OnClick")(popup.controls.profileCompact)
  assert_eq("compact", DingTimerDB.hudProfile, "compact profile button should update the HUD profile")
  assert_eq(308, floatFrame:GetWidth(), "compact profile button should resize the HUD immediately")
  assert_eq(0.96, buttonFillAlpha(popup.controls.profileCompact), "compact profile button should become active")
  assert_eq(0.7, buttonFillAlpha(popup.controls.profileFull), "full profile button should become inactive")

  popup.controls.profileBarTTL:GetScript("OnClick")(popup.controls.profileBarTTL)
  assert_eq("bar_ttl", DingTimerDB.hudProfile, "bar+TTL profile button should update the HUD profile")
  assert_eq(260, floatFrame:GetWidth(), "bar+TTL profile button should resize the HUD immediately")
  assert_false(floatFrame.subText:IsShown(), "bar+TTL profile button should hide the HUD detail line")
  assert_eq(0.96, buttonFillAlpha(popup.controls.profileBarTTL), "bar+TTL profile button should become active")

  popup.controls.profileGraph:GetScript("OnClick")(popup.controls.profileGraph)
  assert_eq("graph", DingTimerDB.hudProfile, "graph profile button should update the HUD profile")
  assert_eq(385, floatFrame:GetWidth(), "graph profile button should keep the wide HUD width")
  assert_true(floatFrame.graphArea:IsShown(), "graph profile button should show the HUD graph")
  assert_false(floatFrame.progressBar:IsShown(), "graph profile button should replace the XP bar")
  assert_eq(0.96, buttonFillAlpha(popup.controls.profileGraph), "graph profile button should become active")

  popup.controls.profileFull:GetScript("OnClick")(popup.controls.profileFull)
  assert_eq("full", DingTimerDB.hudProfile, "full profile button should restore the full HUD profile")
  assert_eq(385, floatFrame:GetWidth(), "full profile button should restore the full HUD width")
  assert_true(floatFrame.subText:IsShown(), "full profile button should restore the HUD detail line")
  assert_false(floatFrame.graphArea:IsShown(), "full profile button should hide the HUD graph")

  popup.controls.window1m:GetScript("OnClick")(popup.controls.window1m)
  assert_eq(60, DingTimerDB.windowSeconds, "window quick button should update the rolling window")
  assertStringMatch("No XP in 60s", floatFrame.subText:GetText(), "changing the window should refresh the HUD text")

  popup.controls.modeTTL:GetScript("OnClick")(popup.controls.modeTTL)
  assert_eq("ttl", DingTimerDB.mode, "mode button should update the chat mode")

  popup.controls.chat:SetChecked(false)
  popup.controls.chat:GetScript("OnClick")(popup.controls.chat)
  assert_false(DingTimerDB.enabled, "chat checkbox should update the enabled flag")

  popup.controls.floatShowInCombat:SetChecked(true)
  popup.controls.floatShowInCombat:GetScript("OnClick")(popup.controls.floatShowInCombat)
  assert_true(DingTimerDB.floatShowInCombat, "combat visibility checkbox should update the DB")
end)

it("requires confirmation before resetting the session from the popup", function()
  NS.SetFloatEnabled(true)
  NS.state.sessionXP = 123

  popup.controls.reset:GetScript("OnClick")(popup.controls.reset)
  assert_eq(123, NS.state.sessionXP, "first reset click should only arm confirmation")
  assertStringMatch("Confirm reset", popup.controls.reset:GetText(), "first reset click should change the button label")

  popup.controls.reset:GetScript("OnClick")(popup.controls.reset)
  assert_eq(0, NS.state.sessionXP, "second reset click should reset the session")
  assert_eq("Reset session", popup.controls.reset:GetText(), "confirmed reset should restore the idle label")
end)

it("clears a pending reset confirmation when the popup hides", function()
  NS.state.sessionXP = 456
  NS.ShowHUDPopup()

  popup.controls.reset:GetScript("OnClick")(popup.controls.reset)
  assertStringMatch("Confirm reset", popup.controls.reset:GetText(), "precondition: reset should be armed")

  NS.HideHUDPopup()
  assert_eq("Reset session", popup.controls.reset:GetText(), "hiding the popup should disarm reset confirmation")

  NS.ShowHUDPopup()
  popup.controls.reset:GetScript("OnClick")(popup.controls.reset)
  assert_eq(456, NS.state.sessionXP, "first reset click after hiding should only arm confirmation again")
end)

run_tests()
