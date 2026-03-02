-- WoW API Mocks
local currentTime = 0
function GetTime()
    return currentTime
end

function SetTime(t)
    currentTime = t
end

local playerXP = 0
local playerMaxXP = 1000
function UnitXP(unit)
    if unit == "player" then return playerXP end
end

function UnitXPMax(unit)
    if unit == "player" then return playerMaxXP end
end

function SetXP(xp, max)
    playerXP = xp
    if max then playerMaxXP = max end
end

local playerMoney = 0
function GetMoney()
    return playerMoney
end

function SetMoney(m)
    playerMoney = m
end

function InCombatLockdown()
    return false
end

function CreateFrame()
    return {
        SetSize = function() end,
        SetPoint = function() end,
        SetMovable = function() end,
        EnableMouse = function() end,
        RegisterForDrag = function() end,
        SetClampedToScreen = function() end,
        SetBackdrop = function() end,
        SetBackdropColor = function() end,
        SetBackdropBorderColor = function() end,
        SetScript = function() end,
        ClearAllPoints = function() end,
        CreateFontString = function() return {
            SetPoint = function() end,
            SetJustifyH = function() end,
            SetText = function() end,
        } end,
        Hide = function() end,
        Show = function() end,
    }
end

function RegisterStateDriver() end
function UnregisterStateDriver() end

UIParent = {}

-- Addon Loading Mock (supports 1 or 2 args)
function LoadAddonFile(path, NS)
    if not NS then
        if not _G.NS then _G.NS = {} end
        NS = _G.NS
    end
    local f, err = loadfile(path)
    if not f then error(err) end
    f("DingTimer", NS)
end

-- assert_eq/assert_near for Core tests
function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            message or "Assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

function assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) > (tolerance or 0.001) then
        error(string.format("%s: expected ~%s, got %s",
            message or "Assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

-- Test runner framework (it / assert_equal / run_tests)
local _tests = {}
local _passed = 0
local _failed = 0

function it(name, func)
    table.insert(_tests, {name = name, func = func})
end

function assert_equal(expected, actual, msg)
    if expected ~= actual then
        error(string.format("Expected '%s', got '%s'%s",
            tostring(expected), tostring(actual),
            msg and (" - " .. msg) or ""), 2)
    end
end

function run_tests()
    print("Running tests...")
    for _, test in ipairs(_tests) do
        local status, err = pcall(test.func)
        if status then
            _passed = _passed + 1
            print("  [PASS] " .. test.name)
        else
            _failed = _failed + 1
            print("  [FAIL] " .. test.name)
            print("         " .. tostring(err))
        end
    end
    print(string.format("\nResults: %d passed, %d failed", _passed, _failed))
    if _failed > 0 then os.exit(1) end
end
