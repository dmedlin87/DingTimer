dofile("tests/mocks.lua")
LoadAddonFile("DingTimer/Util.lua")

it("NS.fmtTime returns '??' for boundary invalid inputs", function()
    assert_equal("??", NS.fmtTime(nil))
    assert_equal("??", NS.fmtTime(0))
    assert_equal("??", NS.fmtTime(-50))
    assert_equal("??", NS.fmtTime(math.huge))
end)

it("NS.fmtTime formats seconds at lower and upper bounds (< 120s)", function()
    assert_equal("45s",  NS.fmtTime(45))
    assert_equal("119s", NS.fmtTime(119))
end)

it("NS.fmtTime formats minutes and seconds at boundaries", function()
    assert_equal("2m 0s",   NS.fmtTime(120))
    assert_equal("2m 30s",  NS.fmtTime(150))
    assert_equal("59m 59s", NS.fmtTime(3599))
end)

it("NS.fmtTime formats hours and minutes at boundaries", function()
    assert_equal("1h 0m",  NS.fmtTime(3600))
    assert_equal("1h 30m", NS.fmtTime(5400))
    assert_equal("2h 5m",  NS.fmtTime(7500))
end)

it("NS.fmtTime rounds fractional seconds correctly", function()
    assert_equal("46s",    NS.fmtTime(45.6))
    assert_equal("2m 1s",  NS.fmtTime(120.5))
end)

it("NS.fmtTime handles extremely large values", function()
    assert_equal("2400h 0m", NS.fmtTime(100 * 24 * 3600))
end)

it("NS.fmtTime fractional values near 120s boundary", function()
    assert_equal("2m 0s", NS.fmtTime(119.5))
    assert_equal("119s",  NS.fmtTime(119.4))
end)

it("NS.fmtTime fractional values near 3600s boundary", function()
    assert_equal("1h 0m",   NS.fmtTime(3599.6))
    assert_equal("59m 59s", NS.fmtTime(3599.4))
end)

run_tests()
