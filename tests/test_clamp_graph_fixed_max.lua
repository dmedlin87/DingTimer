require("tests.mocks")

local NS = LoadAddonFile("DingTimer/Util.lua")

print("Running tests for ClampGraphFixedMax edge cases...")

-- Default/Nil value (should return 500000)
assertEqual(500000, NS.ClampGraphFixedMax(nil), "ClampGraphFixedMax(nil) should return 500000")

-- Valid numbers within range
assertEqual(50000, NS.ClampGraphFixedMax(50000), "ClampGraphFixedMax(50000) should return 50000")

-- Below minimum (10000)
assertEqual(10000, NS.ClampGraphFixedMax(5000), "ClampGraphFixedMax(5000) should clamp to 10000")
assertEqual(10000, NS.ClampGraphFixedMax(-100), "ClampGraphFixedMax(-100) should clamp to 10000")

-- Above maximum (10000000)
assertEqual(10000000, NS.ClampGraphFixedMax(15000000), "ClampGraphFixedMax(15000000) should clamp to 10000000")

-- String inputs that are valid numbers
assertEqual(20000, NS.ClampGraphFixedMax("20000"), "ClampGraphFixedMax('20000') should return 20000")

-- Invalid string inputs
assertEqual(500000, NS.ClampGraphFixedMax("abc"), "ClampGraphFixedMax('abc') should fall back to default 500000")

-- Float numbers
assertEqual(15000.7, NS.ClampGraphFixedMax(15000.7), "ClampGraphFixedMax(15000.7) should return 15000.7")

-- Invalid numbers (NaN, Infinity)
local nan = 0/0
local result_nan = NS.ClampGraphFixedMax(nan)
-- math.max(10000, math.min(10000000, NaN))
-- math.min(10000000, NaN) -> NaN
-- math.max(10000, NaN) -> NaN
-- So it actually returns NaN.
assertEqual(10000000, result_nan, "ClampGraphFixedMax(NaN) should clamp to 10000000 (math.max behavior in Lua 5.1)")

local inf = math.huge
assertEqual(10000000, NS.ClampGraphFixedMax(inf), "ClampGraphFixedMax(Infinity) should clamp to 10000000")

local neg_inf = -math.huge
assertEqual(10000, NS.ClampGraphFixedMax(neg_inf), "ClampGraphFixedMax(-Infinity) should clamp to 10000")

print("All tests passed!")
