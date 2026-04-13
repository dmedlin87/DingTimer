## 2024-05-24 - Performance Pattern: In Lua 5.1, direct indexing (`table[#table + 1] = val`) is faster than `table.insert(table, val)` for single insertions
**Learning:** For array insertions, `table[#table + 1] = val` avoids the function call overhead of `table.insert` and runs roughly 1.25x faster.
**Action:** Use direct indexing for simple table appends, especially in tight loops or high-frequency event handlers, keeping in mind `#` overhead for very large tables if used heavily inside inner loops.

## 2024-05-24 - Performance Pattern: Using Numeric Loops for Dictionary Data Aggregation
**Learning:** When aggregating data into a dictionary for lookup (e.g., `zoneStatsMap`), simultaneously maintaining a sequential array (`zoneStatsList`) with an explicit counter enables high-performance numeric `for` loop iteration in downstream consumers (like `calculateZoneLeaders`) and avoids the overhead of `pairs()` or the `#` operator.
**Action:** When a dictionary's entries must be processed as a collection later in the same execution path, populate a parallel array during the initial population phase to trade a small amount of memory for significant iteration performance gains in Lua 5.1.
