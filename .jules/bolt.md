## 2024-05-28 - Avoid O(N*M) loops on time-series data
**Learning:** In `UI_XPGraphWindow.lua`, calculating a sliding sum over a chronological event log was done by re-iterating the entire event list for every graph segment (N segments * M events). Because the events are strictly chronologically ordered, we can do this in O(N+M) by advancing a single pointer (`evIdx`).
**Action:** Always check if nested loops over time-series data can be flattened by maintaining a pointer across the outer loop.

## 2024-05-29 - O(N) Number Formatting in Lua 5.1
**Learning:** In Lua 5.1 (World of Warcraft), number formatting with thousand separators using iterative `string.gsub` loops has O(N^2) complexity due to string immutability and repeated scanning. The `reverse-gsub-reverse` pattern (`string.reverse(string.gsub(string.reverse(absNum), "(%d%d%d)", "%1,")):gsub("^,", "")`) is significantly more efficient at O(N) and correctly handles numbers of all lengths without lookahead patterns.
**Action:** Always use the `reverse-gsub-reverse` pattern for thousand separators in Lua 5.1 environments instead of recursive or iterative `gsub` loops.

## 2025-01-28 - Optimizing O(N*M) Graph Aggregation
**Learning:** A visually bounded graph loop (O(N) iteration over bars) can contain an unbounded O(M) nested loop if processing time-series data without state caching. A loop processing `up to t_end` over time-series data requires scanning O(M) elements on every frame if starting from index 1.
**Action:** Use the `total` or full aggregate state as a starting constraint, then process chronologically sorted data backwards (subtracting from the total rather than adding from zero). This drops loop complexity from O(N*M) to O(N).
