dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/SessionCoach.lua", NS)

it("NS.GetCoachDefaults returns a table with the expected keys", function()
  local defaults = NS.GetCoachDefaults()

  assert_equal("table", type(defaults))
  assert_equal("ding", defaults.goal)
  assert_equal(true, defaults.alertsEnabled)
  assert_equal(true, defaults.chatAlerts)
  assert_equal(90, defaults.idleSeconds)
  assert_equal(15, defaults.paceDropPct)
  assert_equal(90, defaults.alertCooldownSeconds)
  assert_equal(4, defaults.alertHistoryLimit)
  assert_equal(true, defaults.stabilizeEarlyPace)
end)

it("NS.GetCoachDefaults returns a new table reference each time (no side effects on mutation)", function()
  local defaults1 = NS.GetCoachDefaults()
  local defaults2 = NS.GetCoachDefaults()

  assert_true(defaults1 ~= defaults2, "Consecutive calls should return different table references")

  -- Mutate defaults1 and verify defaults2 is unchanged
  defaults1.goal = "test"
  defaults1.idleSeconds = 999

  assert_equal("ding", defaults2.goal)
  assert_equal(90, defaults2.idleSeconds)
end)

it("NS.GetCoachDefaults handles empty store properly", function()
  local defaults = NS.GetCoachDefaults()
  assert_equal("ding", defaults.goal)
end)

run_tests()
