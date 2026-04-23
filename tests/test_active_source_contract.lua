dofile("tests/mocks.lua")

local activeEntries = {
  "Util.lua",
  "Store.lua",
  "Core_DingTimer.lua",
  "HUDText.lua",
  "Core_HUD.lua",
  "Core_Events.lua",
  "Actions.lua",
  "Commands.lua",
  "UI_HUDPopup.lua",
  "DingTimer.lua",
}

local legacyFiles = {
  "GraphMath.lua",
  "Insights.lua",
  "Pvp.lua",
  "SessionCoach.lua",
  "UI_InsightsWindow.lua",
  "UI_MainWindow.lua",
  "UI_MinimapButton.lua",
  "UI_SettingsWindow.lua",
  "UI_StatsWindow.lua",
  "UI_XPGraphWindow.lua",
}

local function fileExists(path)
  ---@diagnostic disable-next-line: undefined-global
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function readTocRuntimeEntries()
  local entries = {}
  ---@diagnostic disable-next-line: undefined-global
  local handle = assert(io.open("DingTimer/DingTimer.toc", "r"))
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and not trimmed:match("^#") then
      entries[#entries + 1] = trimmed
    end
  end
  handle:close()
  return entries
end

it("keeps the HUD-first toc load path explicit and stable", function()
  local entries = readTocRuntimeEntries()
  assert_eq(#activeEntries, #entries, "TOC should contain only active HUD-first runtime files")

  for i = 1, #activeEntries do
    assert_eq(activeEntries[i], entries[i], "TOC entry order should stay aligned with the HUD-first contract")
  end
end)

it("keeps retired modules archived outside the active addon folder", function()
  for i = 1, #legacyFiles do
    local file = legacyFiles[i]
    assert_false(fileExists("DingTimer/" .. file), "legacy module should not live in the active addon folder: " .. file)
    assert_true(fileExists("archive/DingTimer-legacy/" .. file), "legacy module should stay available in the archive: " .. file)
  end
end)

run_tests()
