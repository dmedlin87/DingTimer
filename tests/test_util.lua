require("tests.mocks")

local NS = LoadAddonFile("DingTimer/Util.lua")

print("Running tests for Util.lua...")

-- test NS.fmtTime
assertEqual("??", NS.fmtTime(nil), "fmtTime(nil)")
assertEqual("??", NS.fmtTime(-10), "fmtTime(-10)")
assertEqual("??", NS.fmtTime(0), "fmtTime(0)")
assertEqual("??", NS.fmtTime(math.huge), "fmtTime(huge)")

assertEqual("5s", NS.fmtTime(5), "fmtTime(5)")
assertEqual("119s", NS.fmtTime(119), "fmtTime(119)")
assertEqual("2m 0s", NS.fmtTime(120), "fmtTime(120)")
assertEqual("2m 5s", NS.fmtTime(125), "fmtTime(125)")
assertEqual("59m 59s", NS.fmtTime(3599), "fmtTime(3599)")

assertEqual("1h 0m", NS.fmtTime(3600), "fmtTime(3600)")
assertEqual("1h 5m", NS.fmtTime(3900), "fmtTime(3900)")
assertEqual("2h 30m", NS.fmtTime(9000), "fmtTime(9000)")


-- test NS.fmtMoney
assertEqual("0|cffeda55fc|r", NS.fmtMoney(nil), "fmtMoney(nil)")
assertEqual("0|cffeda55fc|r", NS.fmtMoney(0), "fmtMoney(0)")
assertEqual("5|cffeda55fc|r", NS.fmtMoney(5), "fmtMoney(5)")
assertEqual("12|cffc7c7cfs|r 34|cffeda55fc|r", NS.fmtMoney(1234), "fmtMoney(1234)")
assertEqual("1|cffffd700g|r 23|cffc7c7cfs|r 45|cffeda55fc|r", NS.fmtMoney(12345), "fmtMoney(12345)")
assertEqual("10|cffffd700g|r 0|cffc7c7cfs|r 0|cffeda55fc|r", NS.fmtMoney(100000), "fmtMoney(100000)")
assertEqual("|cffff4040-|r1|cffffd700g|r 23|cffc7c7cfs|r 45|cffeda55fc|r", NS.fmtMoney(-12345), "fmtMoney(-12345)")

-- test NS.ttlColor
assertEqual(NS.C.val, NS.ttlColor(100, nil), "ttlColor(nil lastTTL)")
assertEqual(NS.C.val, NS.ttlColor(100, math.huge), "ttlColor(huge lastTTL)")
assertEqual(NS.C.mid, NS.ttlColor(100, 100), "ttlColor(same)")
assertEqual(NS.C.mid, NS.ttlColor(100, 101), "ttlColor(small diff -1)")
assertEqual(NS.C.mid, NS.ttlColor(100, 99), "ttlColor(small diff +1)")
assertEqual(NS.C.xp, NS.ttlColor(100, 105), "ttlColor(improved)") -- down = improved = green = xp
assertEqual(NS.C.bad, NS.ttlColor(105, 100), "ttlColor(worsened)") -- up = worsened = red = bad

-- test NS.ttlDeltaText
assertEqual("", NS.ttlDeltaText(nil, 100), "ttlDeltaText(nil ttl)")
assertEqual("", NS.ttlDeltaText(math.huge, 100), "ttlDeltaText(huge ttl)")
assertEqual("", NS.ttlDeltaText(100, nil), "ttlDeltaText(nil lastTTL)")
assertEqual("", NS.ttlDeltaText(100, math.huge), "ttlDeltaText(huge lastTTL)")
assertEqual("", NS.ttlDeltaText(100, 100), "ttlDeltaText(same)")
assertEqual("", NS.ttlDeltaText(100, 101), "ttlDeltaText(small diff)")
assertEqual("", NS.ttlDeltaText(100, 101.9), "ttlDeltaText(dead-zone upper bound)")

-- diff = ttl - lastTTL
-- if diff < 0 it's an improvement (down arrow), meaning ttl is smaller than lastTTL
local diff_down = NS.ttlDeltaText(100, 150)
assertStringMatch("\226\134\147", diff_down, "down arrow in " .. tostring(diff_down))
assertStringMatch("50s", diff_down, "50s in " .. tostring(diff_down))

-- if diff > 0 it's a worsening (up arrow), meaning ttl is bigger than lastTTL
local diff_up = NS.ttlDeltaText(150, 100)
assertStringMatch("\226\134\145", diff_up, "up arrow in " .. tostring(diff_up))
assertStringMatch("50s", diff_up, "50s in " .. tostring(diff_up))

local rounded_down = NS.ttlDeltaText(100, 101.5)
assertStringMatch("\226\134\147", rounded_down, "down arrow in rounded_down")
assertStringMatch("2s", rounded_down, "2s in rounded_down")

print("All tests passed!")
