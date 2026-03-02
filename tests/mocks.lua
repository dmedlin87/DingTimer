local ADDON = "DingTimer"
local NS = {}

-- Global Mocks
_G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
_G.GetTime = function() return 1000 end
_G.UnitXP = function() return 0 end
_G.UnitXPMax = function() return 1000 end
_G.CreateFrame = function() return { Hide = function() end, Show = function() end, SetScript = function() end } end

-- Simple test framework
local passCount = 0
local failCount = 0

local function assertEquals(expected, actual, message)
    if expected == actual then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print("FAIL: " .. (message or "") .. " | Expected: '" .. tostring(expected) .. "', Actual: '" .. tostring(actual) .. "'")
    end
end

local function assertTruthy(actual, message)
    if actual then
        passCount = passCount + 1
    else
        failCount = failCount + 1
        print("FAIL: " .. (message or "") .. " | Expected truthy, Actual: " .. tostring(actual))
    end
end

local function printSummary()
    print("\nTest Summary: " .. passCount .. " passed, " .. failCount .. " failed.")
    if failCount > 0 then
        error("Tests failed")
    end
end

return {
    ADDON = ADDON,
    NS = NS,
    assertEquals = assertEquals,
    assertTruthy = assertTruthy,
    printSummary = printSummary,
    loadAddonFile = function(filepath)
        local f = assert(loadfile(filepath))
        f(ADDON, NS)
        return NS
    end
}
