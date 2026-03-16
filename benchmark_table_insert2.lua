local function bench()
    local MAX_ITERATIONS = 5000000
    local events1 = {}
    local events2 = {}

    local start_time = os.clock()
    for i = 1, MAX_ITERATIONS do
        table.insert(events1, { t = 1, xp = 1, sessionXP = 1 })
    end
    local end_time = os.clock()
    print(string.format("table.insert inline time: %.4f seconds", end_time - start_time))

    local start_time2 = os.clock()
    for i = 1, MAX_ITERATIONS do
        events2[#events2 + 1] = { t = 1, xp = 1, sessionXP = 1 }
    end
    local end_time2 = os.clock()
    print(string.format("direct indexing [#events + 1] time: %.4f seconds", end_time2 - start_time2))
end
for i=1,3 do bench() end
