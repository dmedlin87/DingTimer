dofile("tests/mocks.lua")

---@class TestTicker
---@field cancelled boolean

local NS = {}
local ADDON = "DingTimer"

-- Setup dummy functions that the Core requires to load successfully
NS.C = { base = "", r = "" }
NS.fmtTime = function() return "" end
NS.ttlColor = function() return "" end
NS.ttlDeltaText = function() return "" end
NS.chat = function() end
NS.GraphFeedXP = function() end
NS.RefreshStatsWindow = function() end
NS.GraphReset = function() end

LoadAddonFile("DingTimer/Core_DingTimer.lua", ADDON, NS)

---@param ticker TestTicker?
---@param message string
---@return TestTicker
local function requireTicker(ticker, message)
    assert_true(ticker ~= nil, message)
    local requiredTicker = ticker
    ---@cast requiredTicker TestTicker
    return requiredTicker
end

-- 1. Test empty list edge case
local function test_empty_events_list()
    NS.state.events = {}
    local status = pcall(function()
        NS.computeXPPerHour(100, 60)
    end)
    assert_true(status, "pruneEvents should not throw an error on empty list")
    assert_equal(0, #NS.state.events, "Events list should remain empty")
end

-- 2. Test list with 1 element that should be kept
local function test_single_element_keep()
    NS.state.events = { { t = 50, xp = 100 } }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(1, #NS.state.events, "Single element should be kept")
    assert_equal(50, NS.state.events[1].t, "Element should not be modified")
end

-- 3. Test list with 1 element that should be removed
local function test_single_element_remove()
    NS.state.events = { { t = 20, xp = 100 } }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(0, #NS.state.events, "Single element should be removed")
end

-- 4. Test normal pruning
local function test_normal_pruning()
    NS.state.events = {
        { t = 10, xp = 100 },
        { t = 20, xp = 200 },
        { t = 30, xp = 300 },
        { t = 40, xp = 400 },
        { t = 50, xp = 500 }
    }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(2, #NS.state.events, "Should have 2 events after pruning")
    assert_equal(40, NS.state.events[1].t, "First event should be at t=40")
    assert_equal(50, NS.state.events[2].t, "Second event should be at t=50")
    assert_equal(nil, NS.state.events[3], "Third element should be nil")
end

local function test_pruning_updates_window_sum()
    NS.state.events = {
        { t = 10, xp = 100 },
        { t = 20, xp = 200 },
        { t = 55, xp = 300 }
    }
    NS.state.windowXP = 600

    NS.computeXPPerHour(70, 30)

    assert_equal(1, #NS.state.events, "Only events inside the rolling window should remain")
    assert_equal(300, NS.state.windowXP, "Pruning should remove expired XP from the rolling sum")
end

local function test_saturated_window_rate_decays_each_second()
    NS.state.sessionStartTime = 0
    NS.state.events = { { t = 600, xp = 100 } }
    NS.state.windowXP = 100

    local initialXph = NS.computeXPPerHour(600, 60)
    local nextSecondXph = NS.computeXPPerHour(601, 60)

    assert_near(initialXph, 100 * 3600 / 60, 0.1, "XP/hr should use the window at the moment XP arrives")
    assert_near(nextSecondXph, 100 * 3600 / 61, 0.1, "XP/hr should decay on the next heartbeat")
    assert_true(nextSecondXph < initialXph, "XP/hr should not remain flat between heartbeat ticks")
    NS.state.windowXP = nil
end

-- 5. Test pruning when all elements are old
local function test_all_elements_removed()
    NS.state.events = {
        { t = 10, xp = 100 },
        { t = 20, xp = 200 }
    }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(0, #NS.state.events, "All events should be removed")
    assert_equal(nil, NS.state.events[1], "First element should be nil")
end

-- Run all tests
test_empty_events_list()
test_single_element_keep()
test_single_element_remove()
test_normal_pruning()
test_pruning_updates_window_sum()
test_saturated_window_rate_decays_each_second()
test_all_elements_removed()

-- Tests for SetRollingWindowSeconds
local function test_set_rolling_window_seconds_invalid_inputs()
    DingTimerDB = {}
    assert_false(NS.SetRollingWindowSeconds(nil), "Should return false for nil")
    assert_false(NS.SetRollingWindowSeconds("abc"), "Should return false for non-numeric string")
    assert_false(NS.SetRollingWindowSeconds({}), "Should return false for table")
    assert_equal(nil, DingTimerDB.windowSeconds, "windowSeconds should not be updated for invalid inputs")
end

local function test_set_rolling_window_seconds_out_of_bounds()
    DingTimerDB = {}
    assert_false(NS.SetRollingWindowSeconds(29), "Should return false for n < 30")
    assert_false(NS.SetRollingWindowSeconds(86401), "Should return false for n > 86400")
    assert_equal(nil, DingTimerDB.windowSeconds, "windowSeconds should not be updated for out-of-bounds inputs")
end

local function test_set_rolling_window_seconds_valid()
    DingTimerDB = {}
    assert_true(NS.SetRollingWindowSeconds(60), "Should return true for valid integer")
    assert_equal(60, DingTimerDB.windowSeconds, "windowSeconds should be updated to integer value")

    DingTimerDB = {}
    assert_true(NS.SetRollingWindowSeconds("300"), "Should return true for valid numeric string")
    assert_equal(300, DingTimerDB.windowSeconds, "windowSeconds should be updated to parsed numeric value")

    DingTimerDB = {}
    assert_true(NS.SetRollingWindowSeconds(30.5), "Should return true for valid float")
    assert_equal(30, DingTimerDB.windowSeconds, "windowSeconds should be updated to floored value")
end

test_set_rolling_window_seconds_invalid_inputs()
test_set_rolling_window_seconds_out_of_bounds()
test_set_rolling_window_seconds_valid()

local function test_heartbeat_ticker_lifecycle()
    NS.StopHeartbeatTicker()
    C_Timer._lastTicker = nil

    NS.StartHeartbeatTicker()
    local firstTicker = requireTicker(C_Timer._lastTicker, "StartHeartbeatTicker should create a ticker")

    NS.StartHeartbeatTicker()
    assert_equal(firstTicker, C_Timer._lastTicker, "StartHeartbeatTicker should stay idempotent")

    assert_true(NS.StopHeartbeatTicker(), "StopHeartbeatTicker should cancel an active ticker")
    assert_true(firstTicker.cancelled, "StopHeartbeatTicker should cancel the created ticker")
    assert_false(NS.StopHeartbeatTicker(), "StopHeartbeatTicker should be safe to call repeatedly")

    NS.StartHeartbeatTicker()
    local secondTicker = requireTicker(C_Timer._lastTicker, "StartHeartbeatTicker should create a fresh ticker after stop")
    assert_true(secondTicker ~= firstTicker, "StartHeartbeatTicker should create a fresh ticker after stop")
    NS.StopHeartbeatTicker()
end

test_heartbeat_ticker_lifecycle()

local function test_lazy_heartbeat_decision_logic()
    NS.StopHeartbeatTicker()
    NS.state.lastXPAt = nil
    local originalIsFloatVisible = NS.IsFloatVisible
    local originalIsFloatAnimating = NS.IsFloatAnimating

    NS.IsFloatVisible = function()
        return true
    end
    NS.IsFloatAnimating = function()
        return false
    end
    DingTimerDB = { windowSeconds = 60 }

    assert_false(NS.ShouldHeartbeatRun(10), "visible HUD without live XP activity should not require a ticker")

    NS.state.lastXPAt = 5
    assert_true(NS.ShouldHeartbeatRun(10), "visible HUD with recent XP activity should require a ticker")

    ---@diagnostic disable-next-line: duplicate-set-field
    NS.IsFloatVisible = function()
        return false
    end
    assert_false(NS.ShouldHeartbeatRun(10), "hidden HUD without animation should not require a ticker")

    ---@diagnostic disable-next-line: duplicate-set-field
    NS.IsFloatAnimating = function()
        return true
    end
    assert_true(NS.ShouldHeartbeatRun(10), "active HUD animation should keep the ticker alive even while hidden")

    NS.IsFloatVisible = originalIsFloatVisible
    NS.IsFloatAnimating = originalIsFloatAnimating
end

test_lazy_heartbeat_decision_logic()

local function test_snapshot_cache_invalidates_explicitly()
    DingTimerDB = { windowSeconds = 60 }
    SetTime(100)
    SetXP(100, 1000)
    NS.resetXPState()

    local first = NS.GetSessionSnapshot(100)
    SetXP(400, 1000)
    local cached = NS.GetSessionSnapshot(100)

    assert_equal(first, cached, "Snapshots for the same tick should be cached until invalidated")
    assert_equal(100, cached.xp, "Cached snapshot should not observe later XP changes in the same tick")

    NS.InvalidateTickCache()
    local refreshed = NS.GetSessionSnapshot(100)

    assert_true(refreshed ~= cached, "Invalidation should force a fresh snapshot")
    assert_equal(400, refreshed.xp, "Fresh snapshot should observe the current player XP")
    assert_equal(600, refreshed.remainingXP, "Fresh snapshot should recompute remaining XP")
end

test_snapshot_cache_invalidates_explicitly()

print("All Core_DingTimer tests passed!")
