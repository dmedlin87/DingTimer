dofile("tests/mocks.lua")
LoadAddonFile("DingTimer/Util.lua")

it("NS.fmtMoney returns zero string for nil and zero", function()
    assert_equal("0|cffeda55fc|r", NS.fmtMoney(nil))
    assert_equal("0|cffeda55fc|r", NS.fmtMoney(0))
end)

it("NS.fmtMoney formats copper only", function()
    assert_equal("5|cffeda55fc|r", NS.fmtMoney(5))
end)

it("NS.fmtMoney formats silver and copper", function()
    assert_equal("1|cffc7c7cfs|r 0|cffeda55fc|r",  NS.fmtMoney(100))
    assert_equal("1|cffc7c7cfs|r 50|cffeda55fc|r", NS.fmtMoney(150))
end)

it("NS.fmtMoney formats gold, silver, and copper", function()
    assert_equal("1|cffffd700g|r 0|cffc7c7cfs|r 0|cffeda55fc|r",   NS.fmtMoney(10000))
    assert_equal("1|cffffd700g|r 50|cffc7c7cfs|r 0|cffeda55fc|r",  NS.fmtMoney(15000))
    assert_equal("1|cffffd700g|r 2|cffc7c7cfs|r 3|cffeda55fc|r",   NS.fmtMoney(10203))
    assert_equal("100|cffffd700g|r 99|cffc7c7cfs|r 99|cffeda55fc|r", NS.fmtMoney(1009999))
end)

it("NS.fmtMoney formats negative amounts", function()
    assert_equal("|cffff4040-|r5|cffeda55fc|r",                          NS.fmtMoney(-5))
    assert_equal("|cffff4040-|r1|cffffd700g|r 2|cffc7c7cfs|r 3|cffeda55fc|r", NS.fmtMoney(-10203))
end)

run_tests()
