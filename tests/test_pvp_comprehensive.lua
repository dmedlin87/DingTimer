dofile("tests/mocks.lua")

SetProfileIdentity("Veteran", "Azeroth", "WARRIOR", 80, "Warrior")

local function newPvpHarness()
  local NS = {}
  LoadAddonFile("DingTimer/Util.lua", NS)
  LoadAddonFile("DingTimer/Insights.lua", NS)
  LoadAddonFile("DingTimer/Store.lua", NS)
  LoadAddonFile("DingTimer/SessionCoach.lua", NS)

  NS.GraphFeedXP = function() end
  NS.GraphReset = function() end
  NS.RefreshMainWindowSubtitle = function() end
  NS.RefreshStatsWindow = function() end
  NS.RefreshInsightsWindow = function() end
  NS.RefreshSettingsPanel = function() end
  NS.RefreshFloatingHUD = function() end

  LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)
  LoadAddonFile("DingTimer/Pvp.lua", NS)

  DingTimerDB = nil
  NS.InitStore()

  ClearChatLog()
  SetTime(100)
  SetXP(0, 1000)
  SetMoney(0)
  SetHonor(1000, 75000)
  SetLifetimeHKs(10)
  SetZone("Warsong Gulch")
  SetInstanceState(false, nil)
  NS.resetXPState()

  return NS
end

it("accepts multi-return honor APIs without crashing", function()
  local NS = newPvpHarness()
  local previousGetHonorCurrency = GetHonorCurrency
  local previousGetMaxHonorCurrency = GetMaxHonorCurrency

  GetHonorCurrency = function()
    return "33913", 75000
  end

  GetMaxHonorCurrency = function()
    return 75000
  end

  local ok, err = pcall(function()
    NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)
  end)

  GetHonorCurrency = previousGetHonorCurrency
  GetMaxHonorCurrency = previousGetMaxHonorCurrency

  assert_true(ok, "multi-return honor APIs should not crash PvP mode: " .. tostring(err))

  local snapshot = NS.GetPvpSnapshot(100)
  assert_eq(33913, snapshot.currentHonor, "the PvP snapshot should use the first honor API return value")
  assert_eq(75000, snapshot.targetHonor, "the PvP snapshot should still keep the honor cap goal")
end)

it("queues recap notifications during combat and flushes them later", function()
  local NS = newPvpHarness()
  local settings = NS.EnsurePvpConfig(DingTimerDB)
  settings.matchRecap = true

  local previousCombatLockdown = InCombatLockdown
  local combat = false
  InCombatLockdown = function()
    return combat
  end

  SetInstanceState(true, "pvp")
  NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)
  NS.RefreshPvpSnapshot(100, "BASELINE")

  SetTime(110)
  SetHonor(1200, 75000)
  SetLifetimeHKs(13)
  NS.RefreshPvpSnapshot(110, "UPDATE_BATTLEFIELD_SCORE")

  SetInstanceState(false, nil)
  NS.HandlePvpWorldStateChange(120)

  combat = true
  ClearChatLog()
  local flushedWhileBusy = NS.RunPvpHeartbeat(136)
  assert_false(flushedWhileBusy, "heartbeat should not flush notifications while in combat")
  assert_eq(0, #GetChatLog(), "recap text should stay queued until combat ends")
  assert_eq(0, #NS.GetPvpRecentNotices(1), "queued recap should not appear in the notice log yet")

  combat = false
  local flushed = NS.FlushPvpNotifications(140)
  assert_true(flushed, "queued PvP notifications should flush when combat ends")

  local chat = GetChatLog()
  assert_eq(1, #chat, "exactly one recap message should be emitted")
  assert_true(string.find(chat[1], "[PVP]", 1, true) ~= nil, "recap should use the PvP chat prefix")

  local recent = NS.GetPvpRecentNotices(1)
  assert_eq(1, #recent, "flushed recap should be recorded in the notice log")
  assert_eq("Warsong Gulch recap: 200 Honor, 3 HKs, 400 Honor/hr over 20s.", recent[1].text,
    "recap text should reflect the closed battleground match")

  InCombatLockdown = previousCombatLockdown
end)

it("retains and clears PvP history according to the keep limit", function()
  local NS = newPvpHarness()
  local profile = NS.GetPvpProfileStore(true)

  for i = 1, 7 do
    profile.sessions[i] = {
      id = "session-" .. i,
      avgHonorPerHour = i * 100,
      avgHKPerHour = i * 10,
      durationSec = i * 60,
      zone = "Zone " .. i,
      reason = "MANUAL_RESET",
    }
  end

  local ok, kept = NS.SetPvpKeepSessions(3)
  assert_true(ok, "setting the PvP keep limit should succeed")
  assert_eq(5, kept, "keep counts below the floor should clamp to five")
  assert_eq(5, #profile.sessions, "history should be trimmed to the active keep limit")
  assert_eq("session-3", profile.sessions[1].id, "trimmed history should keep the newest sessions")
  assert_eq("session-7", profile.sessions[5].id, "trimmed history should retain the latest session")

  local cleared = NS.ClearCurrentPvpHistory()
  assert_true(cleared, "clearing PvP history should report success")
  assert_eq(0, #profile.sessions, "clearing PvP history should remove every stored session")
end)

it("summarizes historical PvP sessions with the right ordering and aggregates", function()
  local NS = newPvpHarness()
  local profile = NS.GetPvpProfileStore(true)

  profile.sessions = {
    {
      id = "1",
      avgHonorPerHour = 100,
      avgHKPerHour = 10,
      durationSec = 30,
      zone = "Alpha",
    },
    {
      id = "2",
      avgHonorPerHour = 200,
      avgHKPerHour = 20,
      durationSec = 60,
      zone = "Beta",
    },
    {
      id = "3",
      avgHonorPerHour = 300,
      avgHKPerHour = 30,
      durationSec = 90,
      zone = "Alpha",
    },
    {
      id = "4",
      avgHonorPerHour = 400,
      avgHKPerHour = 40,
      durationSec = 120,
      zone = "Gamma",
    },
  }

  local summary = NS.GetPvpInsightsSummary(3)
  assert_eq(4, summary.totalSessions, "insights should report the full session count")
  assert_eq("4", summary.rows[1].id, "insights rows should be returned newest first")
  assert_eq("3", summary.rows[2].id, "insights rows should include the next newest session")
  assert_eq("2", summary.rows[3].id, "insights rows should respect the requested limit")
  assert_eq(250, summary.medianHonorPerHour, "insights should compute the median honor/hr")
  assert_eq(25, summary.medianHKPerHour, "insights should compute the median HK/hr")
  assert_eq(400, summary.bestHonorPerHour, "insights should find the best honor/hr session")
  assert_near(summary.avgSessionTime, 75, 0.001, "insights should average session durations")
  assert_near(summary.trendPct, 133.3333333333, 0.001, "insights should compare the newest half to the prior half")
  assert_eq("4", summary.bestSession.id, "insights should point at the best session")
  assert_eq("4", summary.lastSession.id, "insights should preserve the latest session")
  assert_eq(4, #summary.chartValues, "chart data should preserve the recent session window")
  assert_eq(100, summary.chartValues[1], "chart data should stay in chronological order")
  assert_eq(400, summary.chartValues[4], "chart data should include the latest session")
  assert_eq("Gamma", summary.zoneLeaders[1].zone, "zone leaders should sort by average honor/hr")
  assert_eq(400, summary.zoneLeaders[1].avgXph, "zone leaders should keep the strongest zone first")
  assert_eq("Alpha", summary.zoneLeaders[2].zone, "zone leaders should break ties alphabetically")
  assert_eq("Beta", summary.zoneLeaders[3].zone, "zone leaders should retain the remaining tied zone")
end)

it("persists resume state as a deep copy and restores it within the age limit", function()
  local NS = newPvpHarness()

  SetInstanceState(true, "pvp")
  NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)
  NS.RefreshPvpSnapshot(100, "BASELINE")

  SetTime(110)
  SetHonor(1200, 75000)
  SetLifetimeHKs(13)
  NS.RefreshPvpSnapshot(110, "UPDATE_BATTLEFIELD_SCORE")

  local persisted = NS.PersistPvpResume(120)
  assert_true(persisted, "persisting an active PvP session should succeed")

  NS.state.pvp.honorEvents[1].honor = 9999
  NS.state.pvp.activeMatch.zone = "Altered"

  assert_eq(200, DingTimerDB.pvp.resume.honorEvents[1].honor, "saved resume data should not share event tables with live state")
  assert_eq("Warsong Gulch", DingTimerDB.pvp.resume.activeMatch.zone, "saved resume data should not share match tables with live state")

  NS.state.pvp = nil
  DingTimerDB.activeMode = "xp"

  local restored = NS.RestorePvpResumeIfAvailable(130)
  assert_true(restored, "fresh resume data should restore the saved PvP session")
  assert_true(NS.IsPvpMode(), "restoring resume data should switch the addon back into PvP mode")
  assert_true(DingTimerDB.pvp.resume == nil, "restoring resume data should clear the persisted snapshot")

  local snapshot = NS.GetPvpSnapshot(130)
  assert_eq(200, snapshot.sessionHonor, "restored session honor should match the persisted snapshot")
  assert_eq(3, snapshot.sessionHKs, "restored session HKs should match the persisted snapshot")
  assert_eq("Warsong Gulch", snapshot.zone, "restored match data should preserve the original zone")
  assert_true(string.find(snapshot.matchStatus, "Active match", 1, true) ~= nil,
    "restored match state should still be active after resume")
end)

it("validates PvP goal modes and reports the off state clearly", function()
  local NS = newPvpHarness()
  local settings = NS.EnsurePvpConfig(DingTimerDB)

  local ok, result = NS.SetPvpGoal("off")
  assert_true(ok, "turning PvP goals off should succeed")
  assert_eq("off", settings.goalMode, "goal mode should switch to off")
  assert_eq("Off", NS.GetPvpGoalLabel(), "the goal label should reflect the off state")

  SetInstanceState(true, "pvp")
  NS.EnterPvpMode("MODE_SWITCH_TO_PVP", false, 100)
  local snapshot = NS.GetPvpSnapshot(100)
  assert_eq("Goal Off", snapshot.goalLabel, "goal off should be reported in the snapshot")
  assert_eq("Set a goal", snapshot.ttgText, "goal off should suppress the time-to-goal estimate")
  assert_eq("Set a PvP goal.", snapshot.goalStatus, "goal off should prompt the user to set a target")

  ok, result = NS.SetPvpGoal(-1)
  assert_false(ok, "negative honor goals should be rejected")
  assert_eq("Use '/ding pvp goal off', '/ding pvp goal cap', or a positive honor value.", result,
    "invalid goal input should return the validation message")

  ok, result = NS.SetPvpGoal(9100)
  assert_true(ok, "numeric PvP goals should be accepted")
  assert_eq("custom", result, "numeric PvP goals should switch the mode to custom")
  assert_eq("9,100", NS.GetPvpGoalLabel(), "custom PvP goals should format the saved honor target")
end)

run_tests()
