dofile("tests/mocks.lua")

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

-- 1. Test empty list edge case
function test_empty_events_list()
    NS.state.events = {}
    local status, err = pcall(function()
        NS.computeXPPerHour(100, 60)
    end)
    assert_true(status, "pruneEvents should not throw an error on empty list")
    assert_equal(0, #NS.state.events, "Events list should remain empty")
end

-- 2. Test list with 1 element that should be kept
function test_single_element_keep()
    NS.state.events = { { t = 50, xp = 100 } }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(1, #NS.state.events, "Single element should be kept")
    assert_equal(50, NS.state.events[1].t, "Element should not be modified")
end

-- 3. Test list with 1 element that should be removed
function test_single_element_remove()
    NS.state.events = { { t = 20, xp = 100 } }
    NS.computeXPPerHour(60, 25) -- Keeps t > 35
    assert_equal(0, #NS.state.events, "Single element should be removed")
end

-- 4. Test normal pruning
function test_normal_pruning()
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

-- 5. Test pruning when all elements are old
function test_all_elements_removed()
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
test_all_elements_removed()

print("All Core_DingTimer tests passed!")
