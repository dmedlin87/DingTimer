## 2024-05-24 - Performance Pattern: In Lua 5.1, direct indexing (`table[#table + 1] = val`) is faster than `table.insert(table, val)` for single insertions
**Learning:** For array insertions, `table[#table + 1] = val` avoids the function call overhead of `table.insert` and runs roughly 1.25x faster.
**Action:** Use direct indexing for simple table appends, especially in tight loops or high-frequency event handlers, keeping in mind `#` overhead for very large tables if used heavily inside inner loops.
