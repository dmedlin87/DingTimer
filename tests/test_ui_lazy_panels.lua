dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)
LoadAddonFile("DingTimer/UI_MainWindow.lua", NS)

DingTimerDB = nil
NS.InitStore()

NS.InitStatsPanel = function(parent)
  local frame = CreateFrame("Frame", "LazyStatsPanel", parent)
  frame:SetAllPoints(parent)
  frame:Hide()
  return frame
end

NS.InitGraphPanel = function()
  error("graph unavailable")
end

NS.InitInsightsPanel = function(parent)
  local frame = CreateFrame("Frame", "LazyHistoryPanel", parent)
  frame:SetAllPoints(parent)
  frame:Hide()
  return frame
end

NS.InitSettingsPanel = function(parent)
  local frame = CreateFrame("Frame", "LazySettingsPanel", parent)
  frame:SetAllPoints(parent)
  frame:Hide()
  return frame
end

local ok = pcall(function()
  NS.ShowMainWindow(4)
end)

assert_true(ok, "opening settings should not fail if another panel init errors")
assert_true(DingTimerMainWindow:IsShown(), "main window should still show")
assert_eq(DingTimerDB.lastOpenTab, 4, "settings tab should become active")
assert_true(_G.LazySettingsPanel:IsShown(), "settings panel should still load lazily")

print("UI lazy panel test passed!")
