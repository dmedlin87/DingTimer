local ADDON, NS = {}, {}

local function mock()
    local graphState = { events = {}, totalXP = 0 }

    local function pruneGraphEvents(now)
      local cutoff = now - 3600 - 60
      local events = graphState.events
      local i = 1
      while events[i] and events[i].t < cutoff do
        graphState.totalXP = graphState.totalXP - events[i].xp
        i = i + 1
      end
      if i > 1 then
        for j = 1, (#events - i + 1) do
          events[j] = events[j + i - 1]
        end
        for j = #events, (#events - i + 2), -1 do
          events[j] = nil
        end
      end
    end

    function GraphFeedXP(delta, timestamp)
      if delta <= 0 then return end
      table.insert(graphState.events, { t = timestamp, xp = delta })
      graphState.totalXP = graphState.totalXP + delta
      graphState.dirty = true
    end

    function GraphReset()
      graphState.anchor = 1000
      graphState.events = {}
      graphState.totalXP = 0
      graphState.dirty = true
    end

    -- Populate
    for i = 1, 10 do
        GraphFeedXP(100, 1000 + i * 10)
    end
    print("Initial Total XP:", graphState.totalXP)

    -- Prune up to 1050 (cutoff = 1050, removes i=1,2,3,4)
    pruneGraphEvents(1050 + 3600 + 60)
    print("Pruned Total XP:", graphState.totalXP)
end

mock()
