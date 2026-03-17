require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", "DingTimer", NS)

print("Running tests...")

local passed = 0
local failed = 0

local function test(name, mode, expected)
  local result = NS.NormalizeGraphScaleMode(mode)
  if result == expected then
    print(string.format("  [PASS] %s", name))
    passed = passed + 1
  else
    print(string.format("  [FAIL] %s - Expected: %s, Got: %s", name, tostring(expected), tostring(result)))
    failed = failed + 1
  end
end

-- Valid modes
test("NormalizeGraphScaleMode: 'visible' remains 'visible'", "visible", "visible")
test("NormalizeGraphScaleMode: 'session' remains 'session'", "session", "session")
test("NormalizeGraphScaleMode: 'fixed' remains 'fixed'", "fixed", "fixed")

-- Legacy/alias mode
test("NormalizeGraphScaleMode: 'auto' becomes 'visible'", "auto", "visible")

-- Invalid strings
test("NormalizeGraphScaleMode: 'invalid' falls back to 'visible'", "invalid", "visible")
test("NormalizeGraphScaleMode: empty string falls back to 'visible'", "", "visible")
test("NormalizeGraphScaleMode: whitespace string falls back to 'visible'", "   ", "visible")

-- Nil/null input
test("NormalizeGraphScaleMode: nil input falls back to 'visible'", nil, "visible")

-- Other types
test("NormalizeGraphScaleMode: number input falls back to 'visible'", 123, "visible")
test("NormalizeGraphScaleMode: boolean true input falls back to 'visible'", true, "visible")
test("NormalizeGraphScaleMode: boolean false input falls back to 'visible'", false, "visible")
test("NormalizeGraphScaleMode: table input falls back to 'visible'", {}, "visible")

print(string.format("\nResults: %d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end
