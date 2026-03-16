local function bench()
    local MAX_ITERATIONS = 50000000
    local tabs = { "Live", "Analysis", "History", "Settings" }

    local start_time = os.clock()
    for iter = 1, MAX_ITERATIONS do
        for i, tab in pairs(tabs) do
            local x = i
            local y = tab
        end
    end
    local end_time = os.clock()
    print(string.format("pairs time: %.4f seconds", end_time - start_time))

    local start_time2 = os.clock()
    for iter = 1, MAX_ITERATIONS do
        for i, tab in ipairs(tabs) do
            local x = i
            local y = tab
        end
    end
    local end_time2 = os.clock()
    print(string.format("ipairs time: %.4f seconds", end_time2 - start_time2))

    local start_time3 = os.clock()
    for iter = 1, MAX_ITERATIONS do
        for i = 1, #tabs do
            local x = i
            local y = tabs[i]
        end
    end
    local end_time3 = os.clock()
    print(string.format("numeric for loop time: %.4f seconds", end_time3 - start_time3))
end
for i=1,3 do bench() end
