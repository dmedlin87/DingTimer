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

local function lastChatLine()
  local chatLog = GetChatLog()
  return chatLog[#chatLog] or ""
end

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

it("applies active slash command state changes and reports the result", function()
  ClearChatLog()
  DingTimerDB.enabled = true
  SlashCmdList.DINGTIMER("off")
  assert_false(DingTimerDB.enabled, "off command should disable chat output")
  assertStringMatch("chat output disabled.", lastChatLine(), "off command should report the disabled state")

  ClearChatLog()
  SlashCmdList.DINGTIMER("on")
  assert_true(DingTimerDB.enabled, "on command should enable chat output")
  assertStringMatch("chat output enabled.", lastChatLine(), "on command should report the enabled state")

  ClearChatLog()
  SlashCmdList.DINGTIMER("mode ttl")
  assert_eq("ttl", DingTimerDB.mode, "mode ttl should update the persisted chat mode")
  assertStringMatch("mode = ttl", lastChatLine(), "mode command should report the selected mode")

  ClearChatLog()
  SlashCmdList.DINGTIMER("window 300")
  assert_eq(300, DingTimerDB.windowSeconds, "window command should update the rolling window")
  assertStringMatch("windowSeconds = 300", lastChatLine(), "window command should report the normalized window")

  ClearChatLog()
  SlashCmdList.DINGTIMER("float unlock")
  assert_false(DingTimerDB.floatLocked, "float unlock should persist unlocked state")
  assertStringMatch("floatLocked = unlock", lastChatLine(), "float unlock should report the selected state")

  ClearChatLog()
  SlashCmdList.DINGTIMER("float lock")
  assert_true(DingTimerDB.floatLocked, "float lock should persist locked state")
  assertStringMatch("floatLocked = lock", lastChatLine(), "float lock should report the selected state")
end)

it("treats surrounding whitespace like normal slash command input", function()
  ClearChatLog()
  DingTimerDB.enabled = true

  SlashCmdList.DINGTIMER("   off   ")

  assert_false(DingTimerDB.enabled, "commands should ignore surrounding whitespace before dispatch")
  assertStringMatch("chat output disabled.", lastChatLine(), "trimmed command should run the intended handler")
end)

it("rejects invalid slash command arguments without mutating persisted settings", function()
  ClearChatLog()
  DingTimerDB.mode = "full"
  SlashCmdList.DINGTIMER("mode compact")
  assert_eq("full", DingTimerDB.mode, "invalid mode should not mutate the persisted chat mode")
  assertStringMatch("Unknown mode. Use 'full' or 'ttl'.", lastChatLine(), "invalid mode should explain valid choices")

  ClearChatLog()
  DingTimerDB.windowSeconds = 600
  SlashCmdList.DINGTIMER("window 29")
  assert_eq(600, DingTimerDB.windowSeconds, "out-of-range window should not mutate the persisted window")
  assertStringMatch("window must be between 30 and 86400 seconds", lastChatLine(), "invalid window should explain the valid range")

  ClearChatLog()
  DingTimerDB.floatLocked = true
  SlashCmdList.DINGTIMER("float spin")
  assert_true(DingTimerDB.floatLocked, "unknown float command should not mutate lock state")
  assertStringMatch("Unknown float command.", lastChatLine(), "unknown float command should report valid options")
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
