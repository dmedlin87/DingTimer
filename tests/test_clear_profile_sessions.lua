dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

it("ClearProfileSessions safely returns when GetProfileStore returns nil", function()
  -- Mock GetProfileStore to return nil
  local originalGetProfileStore = NS.GetProfileStore
  NS.GetProfileStore = function(_createIfMissing)
    return nil
  end

  local refreshCalled = false
  NS.RefreshInsightsWindow = function()
    refreshCalled = true
  end

  -- This should not throw an error
  local ok = pcall(function()
    NS.ClearProfileSessions()
  end)

  assert_true(ok, "ClearProfileSessions should not throw an error when GetProfileStore returns nil")
  assert_false(refreshCalled, "RefreshInsightsWindow should not be called when profile is nil")

  -- Restore original function
  NS.GetProfileStore = originalGetProfileStore
end)

it("ClearProfileSessions clears sessions and calls RefreshInsightsWindow when profile exists", function()
  local profileStore = { sessions = { { id = 1 }, { id = 2 } } }

  -- Mock GetProfileStore to return the profileStore
  local originalGetProfileStore = NS.GetProfileStore
  NS.GetProfileStore = function(_createIfMissing)
    return profileStore
  end

  local refreshCalled = false
  NS.RefreshInsightsWindow = function()
    refreshCalled = true
  end

  local ok = pcall(function()
    NS.ClearProfileSessions()
  end)

  assert_true(ok, "ClearProfileSessions should not throw an error")
  assert_true(refreshCalled, "RefreshInsightsWindow should be called when profile exists")
  assert_eq(0, #profileStore.sessions, "Sessions should be empty after ClearProfileSessions")

  -- Restore original function
  NS.GetProfileStore = originalGetProfileStore
end)

run_tests()
