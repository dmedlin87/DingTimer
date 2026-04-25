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

local forbiddenRuntimeReferences = {
  "UI_MainWindow",
  "UI_SettingsWindow",
  "UI_XPGraphWindow",
  "UI_InsightsWindow",
  "UI_MinimapButton",
  "SessionCoach",
  "GraphMath",
  "NS.GraphFeedXP",
  "NS.GraphReset",
  "NS.RefreshStatsWindow",
  "NS.RefreshMainWindow",
  "NS.OpenMainWindow",
  "NS.ToggleMainWindow",
  "NS.OpenSettingsWindow",
  "NS.ToggleSettingsWindow",
  "NS.OpenXPGraphWindow",
  "NS.ToggleXPGraphWindow",
  "NS.OpenInsightsWindow",
  "NS.ToggleInsightsWindow",
  "NS.CreateMinimapButton",
}

local forbiddenCommandHandlers = {
  "ROOT_COMMANDS.live =",
  "ROOT_COMMANDS.ui =",
  "ROOT_COMMANDS.stats =",
  "ROOT_COMMANDS.analysis =",
  "ROOT_COMMANDS.graph =",
  "ROOT_COMMANDS.history =",
  "ROOT_COMMANDS.insights =",
  "ROOT_COMMANDS.goal =",
  "ROOT_COMMANDS.split =",
  "ROOT_COMMANDS.recap =",
  "ROOT_COMMANDS.pvp =",
}

local requiredInterfaceVersions = {
  "120001",
  "50503",
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

local function readFile(path)
  ---@diagnostic disable-next-line: undefined-global
  local handle = assert(io.open(path, "r"))
  local contents = handle:read("*a")
  handle:close()
  return contents
end

local function readTocInterfaceVersions()
  local contents = readFile("DingTimer/DingTimer.toc")
  local interfaceLine = contents:match("## Interface:%s*([^\r\n]+)")
  assert_true(interfaceLine ~= nil, "TOC should declare supported WoW interface versions")

  local versions = {}
  for version in interfaceLine:gmatch("[^,%s]+") do
    versions[version] = true
  end
  return versions
end

it("keeps supported client interface versions current", function()
  local versions = readTocInterfaceVersions()
  for i = 1, #requiredInterfaceVersions do
    local version = requiredInterfaceVersions[i]
    assert_true(versions[version] == true, "TOC should include supported interface version " .. version)
  end
end)

it("keeps the HUD-first toc load path explicit and stable", function()
  local entries = readTocRuntimeEntries()
  assert_eq(#activeEntries, #entries, "TOC should contain only active HUD-first runtime files")

  for i = 1, #activeEntries do
    assert_eq(activeEntries[i], entries[i], "TOC entry order should stay aligned with the HUD-first contract")
  end
end)

it("keeps active runtime files free of removed surface references", function()
  for i = 1, #activeEntries do
    local path = "DingTimer/" .. activeEntries[i]
    local contents = readFile(path)

    for j = 1, #forbiddenRuntimeReferences do
      local token = forbiddenRuntimeReferences[j]
      assert_false(
        string.find(contents, token, 1, true) ~= nil,
        "active runtime file must not reference removed surface token '" .. token .. "': " .. path
      )
    end
  end
end)

it("keeps removed dashboard commands as compatibility redirects only", function()
  local contents = readFile("DingTimer/Commands.lua")

  for i = 1, #forbiddenCommandHandlers do
    local token = forbiddenCommandHandlers[i]
    assert_false(
      string.find(contents, token, 1, true) ~= nil,
      "removed dashboard command must not regain an active handler: " .. token
    )
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
