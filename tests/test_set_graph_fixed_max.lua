require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)

print("Testing NS.SetGraphFixedMax boundaries...")

-- Initialize required DB structure
DingTimerDB = {
  graph = {
    fixedMax = 100000,
    scaleMode = "visible"
  }
}

-- Provide a mock for functions that would normally manipulate UI frames
NS.GraphSetNeedsUpdate = function() end
NS.RefreshSettingsPanel = function() end

-- Normal valid number
NS.SetGraphFixedMax(250000)
assert_eq(250000, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should update DB fixedMax to 250000")
assert_eq("fixed", DingTimerDB.graph.scaleMode, "SetGraphFixedMax should set scaleMode to fixed")

-- Valid edge case: minimum clamp
NS.SetGraphFixedMax(5000)
assert_eq(10000, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should clamp to minimum 10000 in DB")

-- Valid edge case: maximum clamp
NS.SetGraphFixedMax(15000000)
assert_eq(10000000, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should clamp to maximum 10000000 in DB")

-- String inputs that are valid numbers
NS.SetGraphFixedMax("150000")
assert_eq(150000, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should parse numeric string and update DB")

-- Invalid input (nil)
DingTimerDB.graph.fixedMax = 123456
NS.SetGraphFixedMax(nil)
assert_eq(123456, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should early return and not modify DB on nil")

-- Invalid input (unparseable string)
NS.SetGraphFixedMax("abc")
assert_eq(123456, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should early return and not modify DB on invalid string")

-- Invalid input (NaN)
local nan = 0/0
NS.SetGraphFixedMax(nan)
-- Based on Lua 5.1 math.max behavior, NaN returns 10000000
assert_eq(10000000, DingTimerDB.graph.fixedMax, "SetGraphFixedMax should handle NaN gracefully and clamp to upper bound")

print("All tests passed!")
