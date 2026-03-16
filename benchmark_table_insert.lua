local function bench()
    local MAX_ITERATIONS = 5000000

    local start_time = os.clock()
    local events1 = {}
    for i = 1, MAX_ITERATIONS do
        table.insert(events1, { t = 1, xp = 1, sessionXP = 1 })
    end
    local end_time = os.clock()
    print(string.format("table.insert time: %.4f seconds", end_time - start_time))

    local start_time2 = os.clock()
    local events2 = {}
    for i = 1, MAX_ITERATIONS do
        events2[#events2 + 1] = { t = 1, xp = 1, sessionXP = 1 }
    end
    local end_time2 = os.clock()
    print(string.format("direct indexing time: %.4f seconds", end_time2 - start_time2))
end
for i=1,3 do bench() end
