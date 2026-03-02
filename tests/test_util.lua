dofile("tests/mocks.lua")
LoadAddonFile("DingTimer/Util.lua")

local ARROW_DOWN = "\226\134\147"
local ARROW_UP   = "\226\134\145"

-- Mock NS.fmtTime to isolate the logic.
local original_fmtTime = NS.fmtTime

it("NS.ttlDeltaText handles nil inputs", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    assert_equal("", NS.ttlDeltaText(nil, 100))
    assert_equal("", NS.ttlDeltaText(100, nil))
    assert_equal("", NS.ttlDeltaText(nil, nil))
    NS.fmtTime = original_fmtTime
end)

it("NS.ttlDeltaText handles math.huge inputs", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    assert_equal("", NS.ttlDeltaText(math.huge, 100))
    assert_equal("", NS.ttlDeltaText(100, math.huge))
    assert_equal("", NS.ttlDeltaText(math.huge, math.huge))
    NS.fmtTime = original_fmtTime
end)

it("NS.ttlDeltaText handles small differences (< 2)", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    assert_equal("", NS.ttlDeltaText(100, 100))
    assert_equal("", NS.ttlDeltaText(100.4, 100))
    assert_equal("", NS.ttlDeltaText(100, 101))
    assert_equal("", NS.ttlDeltaText(101, 100))
    NS.fmtTime = original_fmtTime
end)

it("NS.ttlDeltaText formats improving TTL (diff < 0)", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    -- TTL drops by 5 seconds
    local expected = string.format(" (%s fmt_5)", ARROW_DOWN)
    assert_equal(expected, NS.ttlDeltaText(100, 105))

    -- TTL drops by 2 minutes (120 seconds)
    local expected2 = string.format(" (%s fmt_120)", ARROW_DOWN)
    assert_equal(expected2, NS.ttlDeltaText(100, 220))
    NS.fmtTime = original_fmtTime
end)

it("NS.ttlDeltaText formats worsening TTL (diff > 0)", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    -- TTL increases by 5 seconds
    local expected = string.format(" (%s fmt_5)", ARROW_UP)
    assert_equal(expected, NS.ttlDeltaText(105, 100))

    -- TTL increases by 1 hour (3600 seconds)
    local expected2 = string.format(" (%s fmt_3600)", ARROW_UP)
    assert_equal(expected2, NS.ttlDeltaText(3700, 100))
    NS.fmtTime = original_fmtTime
end)

it("NS.ttlDeltaText properly rounds the difference", function()
    NS.fmtTime = function(seconds) return "fmt_" .. tostring(seconds) end
    -- diff is 1.5 -> rounds to 2
    local expected = string.format(" (%s fmt_2)", ARROW_UP)
    assert_equal(expected, NS.ttlDeltaText(101.5, 100))

    -- diff is -1.5. In lua math.floor(-1.5 + 0.5) is math.floor(-1.0) == -1.
    -- Absolute is 1, so it returns empty string!
    assert_equal("", NS.ttlDeltaText(100, 101.5))

    local expected2 = string.format(" (%s fmt_2)", ARROW_DOWN)
    assert_equal(expected2, NS.ttlDeltaText(100, 102.5))
    NS.fmtTime = original_fmtTime
end)

-- Run tests
run_tests()
