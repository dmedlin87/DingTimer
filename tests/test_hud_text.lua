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

  assert_eq("9m 0s to level (idle 35s)", title, "title should show TTL and idle age")
  assertStringMatch("6,000 XP/hr", sub, "subtext should show rolling pace")
  assert_true(string.find(sub, "(idle", 1, true) == nil, "subtext should leave idle age on the title")
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

it("builds gold HUD text for gold tracking mode", function()
  local title, sub = NS.BuildHUDText({
    effectiveTrackingMode = "gold",
    moneyPerHour = 360000,
    windowMoney = 60000,
    sessionMoney = 45000,
    rollingWindow = 600,
  })

  assertStringMatch("/hr", title, "gold title should show a per-hour rate")
  assertStringMatch("36|cffffd700g|r", title, "gold title should format the rolling gold rate")
  assertStringMatch("Window +6|cffffd700g|r", sub, "gold subtext should show rolling-window income")
  assertStringMatch("10m 0s", sub, "gold subtext should include the active rolling window")
  assertStringMatch("Session +4|cffffd700g|r", sub, "gold subtext should show net session money")
end)

it("handles max-level XP mode without next-level text", function()
  local title, sub = NS.BuildHUDText({
    effectiveTrackingMode = "xp",
    isMaxLevel = true,
    ttl = 0,
    currentXph = 1000,
    remainingXP = 0,
    rollingWindow = 600,
  })

  assert_eq("Max level", title, "max-level XP title should not show a fake TTL")
  assert_eq("XP tracking complete", sub, "max-level XP subtext should avoid remaining-XP estimates")
end)

it("builds compact bar text for gold tracking mode", function()
  local title, sub = NS.BuildHUDText({
    effectiveTrackingMode = "gold",
    moneyPerHour = 0,
    windowMoney = 0,
    sessionMoney = 0,
    rollingWindow = 60,
  }, { shortTTL = true })

  assert_eq("No gold in 60s", title, "gold bar mode should show a compact no-gold state")
  assert_eq("", sub, "gold bar mode should not render detail text")
end)

run_tests()
