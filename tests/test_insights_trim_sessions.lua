dofile("tests/mocks.lua")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", NS)
LoadAddonFile("DingTimer/Insights.lua", NS)
LoadAddonFile("DingTimer/Store.lua", NS)

local function makeSession(id)
  return { id = id, avgXph = id * 1000 }
end

local function sessionIds(profile)
  local ids = {}
  for i = 1, #profile.sessions do
    ids[i] = profile.sessions[i] and profile.sessions[i].id or nil
  end
  return ids
end

it("TrimSessions keeps the newest sessions and drops the oldest overflow", function()
  DingTimerDB = {
    xp = {
      keepSessions = 5,
      profiles = {},
    },
  }

  local profile = {
    sessions = {
      makeSession(1),
      makeSession(2),
      makeSession(3),
      makeSession(4),
      makeSession(5),
      makeSession(6),
      makeSession(7),
    },
  }

  NS.TrimSessions(profile, 5)

  assert_eq(5, #profile.sessions, "trim should keep the requested number of sessions")
  assert_eq(3, profile.sessions[1].id, "oldest retained session should be the third original entry")
  assert_eq(7, profile.sessions[5].id, "newest session should remain at the end")
  assert_eq(nil, profile.sessions[6], "overflow slots should be cleared")
  assert_eq(nil, profile.sessions[7], "overflow slots should be cleared")
end)

it("TrimSessions uses the saved retention limit and clamps it to the minimum", function()
  DingTimerDB = {
    xp = {
      keepSessions = 2,
      profiles = {},
    },
  }

  local profile = {
    sessions = {
      makeSession(1),
      makeSession(2),
      makeSession(3),
      makeSession(4),
      makeSession(5),
      makeSession(6),
    },
  }

  NS.TrimSessions(profile)

  assert_eq(5, #profile.sessions, "saved retention should clamp up to the minimum")
  local ids = sessionIds(profile)
  assert_eq(2, ids[1], "trim should keep the newest five sessions in order")
  assert_eq(3, ids[2], "trim should keep the newest five sessions in order")
  assert_eq(4, ids[3], "trim should keep the newest five sessions in order")
  assert_eq(5, ids[4], "trim should keep the newest five sessions in order")
  assert_eq(6, ids[5], "trim should keep the newest five sessions in order")
end)

it("TrimSessions leaves in-range history untouched", function()
  DingTimerDB = {
    xp = {
      keepSessions = 30,
      profiles = {},
    },
  }

  local profile = {
    sessions = {
      makeSession(1),
      makeSession(2),
      makeSession(3),
    },
  }

  local before = sessionIds(profile)
  NS.TrimSessions(profile, 10)

  assert_eq(3, #profile.sessions, "history below the limit should not be trimmed")
  assert_eq(before[1], profile.sessions[1].id, "first session should remain unchanged")
  assert_eq(before[2], profile.sessions[2].id, "second session should remain unchanged")
  assert_eq(before[3], profile.sessions[3].id, "third session should remain unchanged")
end)

it("TrimSessions ignores nil or invalid profile tables without throwing", function()
  local ok = pcall(function()
    NS.TrimSessions(nil, 10)
    NS.TrimSessions({}, 10)
    NS.TrimSessions({ sessions = "not-a-table" }, 10)
  end)

  assert_true(ok, "TrimSessions should tolerate missing or malformed profile tables")
end)

run_tests()
