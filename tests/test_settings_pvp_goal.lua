dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/GraphMath.lua", NS)
LoadAddonFile("DingTimer/Pvp.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)
LoadAddonFile("DingTimer/UI_SettingsWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()

local panel = NS.InitSettingsPanel(nil)
panel:Refresh()

assert_true(panel.controls.pvpGoal ~= nil, "settings should expose a custom PvP goal field")
assert_eq("", panel.controls.pvpGoal:GetText(), "custom goal field should be blank until custom mode is active")

local pvp = NS.EnsurePvpConfig(DingTimerDB)
pvp.goalMode = "custom"
pvp.customGoalHonor = 42000
panel:Refresh()

assert_eq("42000", panel.controls.pvpGoal:GetText(), "custom goal field should show the saved custom honor target")

panel.controls.pvpGoal:SetText("43000")
panel.controls.pvpGoal:GetScript("OnEnterPressed")(panel.controls.pvpGoal)

assert_eq("custom", pvp.goalMode, "pressing enter should keep the PvP goal in custom mode")
assert_eq(43000, pvp.customGoalHonor, "pressing enter should update the saved custom honor target")
assert_eq("43000", panel.controls.pvpGoal:GetText(), "the settings field should refresh to the committed value")

print("Settings PvP custom goal test passed!")
