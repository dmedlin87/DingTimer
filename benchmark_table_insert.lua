local function bench()
    local MAX_ITERATIONS = 2000000

    local start_time = os.clock()
    local profile1 = { sessions = {} }
    for i = 1, MAX_ITERATIONS do
        table.insert(profile1.sessions, { t = 1, xp = 1, sessionXP = 1 })
    end
    local end_time = os.clock()
    print(string.format("table.insert time: %.4f seconds", end_time - start_time))

    local start_time2 = os.clock()
    local profile2 = { sessions = {} }
    for i = 1, MAX_ITERATIONS do
        profile2.sessions[#profile2.sessions + 1] = { t = 1, xp = 1, sessionXP = 1 }
    end
    local end_time2 = os.clock()
    print(string.format("direct indexing time: %.4f seconds", end_time2 - start_time2))

    local start_time3 = os.clock()
    local profile3 = { sessions = {} }
    local sessions = profile3.sessions
    for i = 1, MAX_ITERATIONS do
        sessions[#sessions + 1] = { t = 1, xp = 1, sessionXP = 1 }
    end
    local end_time3 = os.clock()
    print(string.format("direct indexing with local time: %.4f seconds", end_time3 - start_time3))
end
for i=1,3 do bench() end
