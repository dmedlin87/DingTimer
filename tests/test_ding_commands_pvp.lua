dofile("tests/mocks.lua")

SetProfileIdentity("Commander", "Azeroth", "PRIEST", 80, "Priest")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)
LoadAddonFile("DingTimer/Actions.lua", NS)
LoadAddonFile("DingTimer/Commands.lua", NS)

NS.GraphFeedXP = function() end
NS.GraphReset = function() end
NS.RefreshStatsWindow = function() end
NS.RefreshInsightsWindow = function() end
NS.RefreshSettingsPanel = function() end
NS.RefreshFloatingHUD = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
LoadAddonFile("DingTimer/Pvp.lua", NS)

DingTimerDB = nil
NS.InitStore()

SetTime(100)
SetXP(0, 1000)
SetHonor(5000, 75000)
SetLifetimeHKs(100)
NS.resetXPState()

NS.ExecuteSlashCommand("pvp on")
assert_true(NS.IsPvpMode(), "pvp on should enable pvp mode")

NS.ExecuteSlashCommand("pvp goal 12000")
assert_eq("custom", DingTimerDB.pvp.settings.goalMode, "numeric pvp goals should switch to custom mode")
assert_eq(12000, DingTimerDB.pvp.settings.customGoalHonor, "numeric pvp goals should store the requested honor target")

NS.ExecuteSlashCommand("pvp auto on")
assert_eq(true, DingTimerDB.pvp.settings.autoSwitchBattlegrounds, "pvp auto on should enable battleground auto switching")

NS.ExecuteSlashCommand("pvp goal cap")
assert_eq("cap", DingTimerDB.pvp.settings.goalMode, "pvp goal cap should switch back to honor cap mode")

NS.ExecuteSlashCommand("pvp off")
assert_false(NS.IsPvpMode(), "pvp off should disable pvp mode")

print("PvP command tests passed!")
