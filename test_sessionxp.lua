local NS = {}
local events = {
  {t=10, xp=10, sessionXP=10},
  {t=20, xp=15, sessionXP=25},
  {t=30, xp=5,  sessionXP=30},
  {t=40, xp=20, sessionXP=50},
  {t=50, xp=10, sessionXP=60},
}
local high = 3
local cumulativeXP = 0

-- Original code:
-- cumulativeXP = events[high].sessionXP or (cumulativeXP + events[high].xp)
print("Original code cumulativeXP:", events[high].sessionXP or (cumulativeXP + events[high].xp))

-- Wait, the `cumulativeXP` SHOULD be 30, and it is 30.
-- But look at the inner loop:
local eventIndex = high + 1
local event = events[eventIndex]
-- cumulativeXP = event.sessionXP or (cumulativeXP + (event.xp or 0))
print("Next original code cumulativeXP:", event.sessionXP or (cumulativeXP + (event.xp or 0)))

-- The bug/optimization:
-- If `sessionXP` is ALREADY the total cumulativeXP up to this event, then we don't need to add anything.
-- We just SET `cumulativeXP = event.sessionXP`.
