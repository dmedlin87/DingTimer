dofile("tests/mocks.lua")
LoadAddonFile("DingTimer/Util.lua")

it("NS.ttlColor returns NS.C.val when lastTTL is missing or infinite", function()
    assert_equal(NS.C.val, NS.ttlColor(100, nil))
    assert_equal(NS.C.val, NS.ttlColor(100, math.huge))
end)

it("NS.ttlColor returns NS.C.mid in the dead-zone (|diff| < 2)", function()
    assert_equal(NS.C.mid, NS.ttlColor(100, 100))
    assert_equal(NS.C.mid, NS.ttlColor(100, 101))
    assert_equal(NS.C.mid, NS.ttlColor(101, 100))
    assert_equal(NS.C.mid, NS.ttlColor(100, 101.9))
end)

it("NS.ttlColor returns NS.C.xp when TTL improved (diff < 0)", function()
    assert_equal(NS.C.xp, NS.ttlColor(90, 100))
    assert_equal(NS.C.xp, NS.ttlColor(98, 100))
end)

it("NS.ttlColor returns NS.C.bad when TTL worsened (diff > 0)", function()
    assert_equal(NS.C.bad, NS.ttlColor(110, 100))
    assert_equal(NS.C.bad, NS.ttlColor(102, 100))
end)

run_tests()
