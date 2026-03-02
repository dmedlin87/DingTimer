dofile("tests/mocks.lua")
LoadAddonFile("DingTimer/Util.lua")

it("NS.fmtMoney handles nil and zero edge cases", function()
    assert_equal("0|cffeda55fc|r", NS.fmtMoney(nil))
    assert_equal("0|cffeda55fc|r", NS.fmtMoney(0))
end)

it("NS.fmtMoney formats positive amounts correctly", function()
    assert_equal("12|cffffd700g|r 34|cffc7c7cfs|r 56|cffeda55fc|r", NS.fmtMoney(123456))
end)

it("NS.fmtMoney formats negative amounts with red minus prefix", function()
    assert_equal("|cffff4040-|r12|cffffd700g|r 34|cffc7c7cfs|r 56|cffeda55fc|r", NS.fmtMoney(-123456))
end)

run_tests()
