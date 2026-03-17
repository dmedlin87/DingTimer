require("tests.mocks")
local NS = LoadAddonFile("DingTimer/Util.lua")

print("Running tests for NS.IsInvalidNumber...")

-- Valid Numbers (should return false)
assert_false(NS.IsInvalidNumber(0), "IsInvalidNumber(0)")
assert_false(NS.IsInvalidNumber(1), "IsInvalidNumber(1)")
assert_false(NS.IsInvalidNumber(-1), "IsInvalidNumber(-1)")
assert_false(NS.IsInvalidNumber(3.14), "IsInvalidNumber(3.14)")
assert_false(NS.IsInvalidNumber(-3.14), "IsInvalidNumber(-3.14)")

-- Invalid Numbers (should return true)
assert_true(NS.IsInvalidNumber(math.huge), "IsInvalidNumber(math.huge)")
assert_true(NS.IsInvalidNumber(-math.huge), "IsInvalidNumber(-math.huge)")

-- NaN case: 0/0 is NaN in Lua, and NaN ~= NaN evaluates to true
assert_true(NS.IsInvalidNumber(0/0), "IsInvalidNumber(NaN)")

print("All tests passed!")
