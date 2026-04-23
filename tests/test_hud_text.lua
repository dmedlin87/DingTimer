dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/HUDText.lua", NS)

it("builds detailed HUD text for active rolling XP", function()
  local title, sub = NS.BuildHUDText({
    ttl = 540,
    currentXph = 6000,
    secondsSinceLastXP = 35,
    lastXPGain = 100,
    gainsToLevel = 9,
    remainingXP = 900,
    rollingWindow = 60,
  })

  assert_eq("9m 0s to level", title, "title should show TTL only")
  assertStringMatch("6,000 XP/hr (idle 35s)", sub, "subtext should show rolling pace and idle age")
  assertStringMatch("Last +100 (9)", sub, "subtext should include last gain details")
  assertStringMatch("Need 900", sub, "subtext should include remaining XP")
end)

it("falls back to compact number formatting when the full subtext would be too long", function()
  local _, sub = NS.BuildHUDText({
    ttl = math.huge,
    currentXph = 36000000000,
    secondsSinceLastXP = 0,
    lastXPGain = 100000000,
    gainsToLevel = 8,
    remainingXP = 800000000,
    rollingWindow = 60,
  })

  assertStringMatch("36.0B XP/hr", sub, "compact mode should abbreviate large XP/hr values")
  assertStringMatch("Last +100.0M (8)", sub, "compact mode should abbreviate large last-gain values")
  assertStringMatch("Need 800.0M", sub, "compact mode should abbreviate remaining XP values")
end)

run_tests()
