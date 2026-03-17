require("tests.mocks")

local NS = LoadAddonFile("DingTimer/Util.lua")

print("Running tests...")

local failCount = 0
local passCount = 0

local function test(name, result)
  if result then
    passCount = passCount + 1
    print("  [PASS] " .. name)
  else
    failCount = failCount + 1
    print("  [FAIL] " .. name)
  end
end

test("NS.FormatNumber returns '0' for nil", NS.FormatNumber(nil) == "0")
test("NS.FormatNumber handles 0 correctly", NS.FormatNumber(0) == "0")
test("NS.FormatNumber handles small positive numbers correctly (< 1000)", NS.FormatNumber(1) == "1" and NS.FormatNumber(999) == "999")
test("NS.FormatNumber handles small negative numbers correctly (> -1000)", NS.FormatNumber(-1) == "-1" and NS.FormatNumber(-999) == "-999")
test("NS.FormatNumber adds comma for thousands", NS.FormatNumber(1000) == "1,000" and NS.FormatNumber(1234) == "1,234" and NS.FormatNumber(999999) == "999,999")
test("NS.FormatNumber adds commas for millions", NS.FormatNumber(1000000) == "1,000,000" and NS.FormatNumber(1234567) == "1,234,567")
test("NS.FormatNumber handles large negative numbers with commas", NS.FormatNumber(-1234567) == "-1,234,567")
test("NS.FormatNumber rounds down fractions (math.floor)", NS.FormatNumber(1234.5) == "1,234" and NS.FormatNumber(-1234.5) == "-1,235")

print("\nResults: " .. passCount .. " passed, " .. failCount .. " failed\n")
if failCount > 0 then
  os.exit(1)
end
