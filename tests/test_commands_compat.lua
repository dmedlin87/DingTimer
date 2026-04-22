dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Core_HUD.lua", NS)
LoadAddonFile("DingTimer/Core_Events.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)
LoadAddonFile("DingTimer/UI_HUDPopup.lua", NS)
LoadAddonFile("DingTimer/DingTimer.lua", NS)

DingTimerDB = {
  enabled = true,
  float = false,
  floatLocked = true,
  floatShowInCombat = false,
  windowSeconds = 600,
  mode = "full",
}

NS.InitStore()

it("opens the popup from /ding settings without any main-window dependency", function()
  NS.HideHUDPopup()
  SlashCmdList.DINGTIMER("settings")
  assert_true(NS.IsHUDPopupShown(), "settings command should open the HUD popup")

  local point, relativeTo = NS.GetHUDPopup():GetPoint()
  assert_eq("CENTER", point, "settings command should center the popup when the HUD is hidden")
  assert_eq(relativeTo, UIParent, "settings command should anchor the popup to UIParent when the HUD is hidden")
  assert_true(DingTimerMainWindow == nil, "HUD-first build should not create the legacy main window")
end)

it("recenters and enables the HUD from /ding float reset", function()
  DingTimerDB.float = false
  DingTimerDB.floatPosition = {
    point = "TOPLEFT",
    relativePoint = "TOPLEFT",
    xOfs = -9999,
    yOfs = 9999,
  }

  SlashCmdList.DINGTIMER("float reset")

  assert_true(DingTimerDB.float, "float reset should enable the HUD")
  assert_eq(nil, DingTimerDB.floatPosition, "float reset should clear the stored HUD position")

  local floatFrame = NS.GetFloatFrame()
  assert_true(floatFrame ~= nil, "float reset should ensure the HUD frame exists")
  local point, relativeTo, relativePoint, xOfs, yOfs = floatFrame:GetPoint()
  assert_eq("CENTER", point, "float reset should recenter the HUD")
  assert_eq(UIParent, relativeTo, "float reset should anchor to UIParent")
  assert_eq("CENTER", relativePoint, "float reset should use the default relative point")
  assert_eq(0, xOfs, "float reset should restore the default x offset")
  assert_eq(220, yOfs, "float reset should restore the default y offset")
  assert_true(floatFrame:IsShown(), "float reset should reveal the HUD")
end)

it("prints the compatibility message for removed dashboard commands", function()
  local removed = {
    "live",
    "ui",
    "stats",
    "analysis",
    "graph",
    "history",
    "insights",
    "goal ding",
    "split",
    "recap",
    "pvp on",
  }

  for i = 1, #removed do
    ClearChatLog()
    SlashCmdList.DINGTIMER(removed[i])
    local chatLog = GetChatLog()
    assert_true(#chatLog > 0, "removed command should print a compatibility message: " .. removed[i])
    assertStringMatch("Removed in HUD-first build; use /ding settings", chatLog[#chatLog], "removed command should print the HUD-first compatibility message")
  end
end)

run_tests()
