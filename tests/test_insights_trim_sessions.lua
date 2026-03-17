dofile("tests/mocks.lua")

SetProfileIdentity("Tracker", "Azeroth", "ROGUE", 30, "Rogue")

local NS = {
  C = { base = "", r = "", val = "", xp = "", bad = "", mid = "" },
  chat = function() end,
  fmtTime = function(v) return tostring(v) end,
  ttlColor = function() return "" end,
  ttlDeltaText = function() return "" end,
  GraphFeedXP = function() end,
  GraphReset = function() end,
  RefreshStatsWindow = function() end,
}

LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Core_DingTimer.lua", NS)

-- Test nil profile
local no_error = pcall(function()
  NS.TrimSessions(nil, 10)
end)

assert_true(no_error, "TrimSessions should not throw an error when passed a nil profile")

print("TrimSessions nil profile test passed!")
