local M = dofile("tests/mocks.lua")
local NS = M.loadAddonFile("DingTimer/Util.lua")

print("--- Testing NS.fmtMoney ---")

M.assertEquals("0|cffeda55fc|r", NS.fmtMoney(0), "Zero copper")
M.assertEquals("0|cffeda55fc|r", NS.fmtMoney(nil), "Nil copper")

M.assertEquals("5|cffeda55fc|r", NS.fmtMoney(5), "Copper only")
M.assertEquals("1|cffc7c7cfs|r 0|cffeda55fc|r", NS.fmtMoney(100), "Silver only (zero copper)")
M.assertEquals("1|cffffd700g|r 0|cffc7c7cfs|r 0|cffeda55fc|r", NS.fmtMoney(10000), "Gold only (zero silver, zero copper)")

M.assertEquals("1|cffc7c7cfs|r 50|cffeda55fc|r", NS.fmtMoney(150), "Silver and copper")
M.assertEquals("1|cffffd700g|r 50|cffc7c7cfs|r 0|cffeda55fc|r", NS.fmtMoney(15000), "Gold and silver")
M.assertEquals("1|cffffd700g|r 2|cffc7c7cfs|r 3|cffeda55fc|r", NS.fmtMoney(10203), "Gold, silver, and copper")
M.assertEquals("100|cffffd700g|r 99|cffc7c7cfs|r 99|cffeda55fc|r", NS.fmtMoney(1009999), "Large amount")

-- negative amounts?
M.assertEquals("|cffff4040-|r5|cffeda55fc|r", NS.fmtMoney(-5), "Negative copper only")
M.assertEquals("|cffff4040-|r1|cffffd700g|r 2|cffc7c7cfs|r 3|cffeda55fc|r", NS.fmtMoney(-10203), "Negative gold, silver, copper")

M.printSummary()
