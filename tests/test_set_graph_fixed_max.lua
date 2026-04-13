require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)

print("Testing NS.SetGraphFixedMax boundaries...")

-- Initialize required DB structure
DingTimerDB = {
  graphFixedMaxXPH = 100000,
  graphScaleMode = "visible"
}

-- Provide a mock for functions that would normally manipulate UI frames
NS.RefreshSettingsPanel = function() end

-- Normal valid number
local applied = NS.SetGraphFixedMax(250000)
assert_eq(250000, applied, "SetGraphFixedMax should return the applied cap")
assert_eq(250000, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should update DB fixed max to 250000")
assert_eq("fixed", DingTimerDB.graphScaleMode, "SetGraphFixedMax should set scaleMode to fixed")

-- Valid edge case: minimum clamp
NS.SetGraphFixedMax(5000)
assert_eq(10000, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should clamp to minimum 10000 in DB")

-- Valid edge case: maximum clamp
NS.SetGraphFixedMax(15000000)
assert_eq(10000000, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should clamp to maximum 10000000 in DB")

-- String inputs that are valid numbers
NS.SetGraphFixedMax("150000")
assert_eq(150000, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should parse numeric string and update DB")

-- Invalid input (nil)
DingTimerDB.graphFixedMaxXPH = 123456
NS.SetGraphFixedMax(nil)
assert_eq(123456, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should early return and not modify DB on nil")

-- Invalid input (unparseable string)
NS.SetGraphFixedMax("abc")
assert_eq(123456, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should early return and not modify DB on invalid string")

-- Invalid input (NaN)
local nan = 0/0
NS.SetGraphFixedMax(nan)
-- Based on Lua 5.1 math.max behavior, NaN returns 10000000
assert_eq(10000000, DingTimerDB.graphFixedMaxXPH, "SetGraphFixedMax should handle NaN gracefully and clamp to upper bound")

print("All tests passed!")
