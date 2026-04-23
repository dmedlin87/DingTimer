dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
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

  popup.controls.window1m:GetScript("OnClick")(popup.controls.window1m)
  assert_eq(60, DingTimerDB.windowSeconds, "window quick button should update the rolling window")
  assertStringMatch("No XP in 60s", floatFrame.subText:GetText(), "changing the window should refresh the HUD text")

  popup.controls.modeTTL:GetScript("OnClick")(popup.controls.modeTTL)
  assert_eq("ttl", DingTimerDB.mode, "mode button should update the chat mode")

  popup.controls.chat:SetChecked(false)
  popup.controls.chat:GetScript("OnClick")(popup.controls.chat)
  assert_false(DingTimerDB.enabled, "chat checkbox should update the enabled flag")

  popup.controls.dingSoundEnabled:SetChecked(false)
  popup.controls.dingSoundEnabled:GetScript("OnClick")(popup.controls.dingSoundEnabled)
  assert_false(DingTimerDB.dingSoundEnabled, "level-up sound checkbox should update the DB")

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

run_tests()
