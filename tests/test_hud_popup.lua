dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)

DingTimerDB = {
  enabled = true,
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

  popup.controls.floatShowInCombat:SetChecked(true)
  popup.controls.floatShowInCombat:GetScript("OnClick")(popup.controls.floatShowInCombat)
  assert_true(DingTimerDB.floatShowInCombat, "combat visibility checkbox should update the DB")
end)

run_tests()
