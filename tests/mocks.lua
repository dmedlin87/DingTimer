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

-- Addon Loading Mock
function LoadAddonFile(path, NS)
    local f, err = loadfile(path)
    if not f then error(err) end
    f("DingTimer", NS)
end

-- Assertion Helpers
function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)), 2)
    end
end

function assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) > (tolerance or 0.001) then
        error(string.format("%s: expected ~%s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)), 2)
    end
end
