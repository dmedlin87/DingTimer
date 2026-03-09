## 2024-05-28 - Avoid O(N*M) loops on time-series data
**Learning:** In `UI_XPGraphWindow.lua`, calculating a sliding sum over a chronological event log was done by re-iterating the entire event list for every graph segment (N segments * M events). Because the events are strictly chronologically ordered, we can do this in O(N+M) by advancing a single pointer (`evIdx`).
**Action:** Always check if nested loops over time-series data can be flattened by maintaining a pointer across the outer loop.

## 2024-05-29 - O(N) Number Formatting in Lua 5.1
**Learning:** In Lua 5.1 (World of Warcraft), number formatting with thousand separators using iterative `string.gsub` loops has O(N^2) complexity due to string immutability and repeated scanning. The `reverse-gsub-reverse` pattern (`string.reverse(string.gsub(string.reverse(absNum), "(%d%d%d)", "%1,")):gsub("^,", "")`) is significantly more efficient at O(N) and correctly handles numbers of all lengths without lookahead patterns.
**Action:** Always use the `reverse-gsub-reverse` pattern for thousand separators in Lua 5.1 environments instead of recursive or iterative `gsub` loops.

## 2025-01-28 - Optimizing O(N*M) Graph Aggregation
**Learning:** A visually bounded graph loop (O(N) iteration over bars) can contain an unbounded O(M) nested loop if processing time-series data without state caching. A loop processing `up to t_end` over time-series data requires scanning O(M) elements on every frame if starting from index 1.
**Action:** Use the `total` or full aggregate state as a starting constraint, then process chronologically sorted data backwards (subtracting from the total rather than adding from zero). This drops loop complexity from O(N*M) to O(N).

## 2024-05-19 - O(1) Sliding Window Calculation
**Learning:** Chronologically sorted time-series data with a sliding window (e.g. for XP or Money per hour calculations) can be optimized by maintaining a continuous running total during insertion and pruning. This avoids full O(N) re-evaluations on every calculation tick.
**Action:** When calculating rates over a sliding window array, initialize a running total. Increment it when inserting a new event and decrement it when an event is pruned.

## 2024-05-28 - Optimize string formatting to avoid regex
**Learning:** In Lua 5.1 environments, sequential string concatenation combined with `string.match("^%s*(.-)%s*$")` for whitespace trimming is significantly slower than building the string exactly as needed via `string.format()`.
**Action:** Use `string.format()` over multiple concatenations (`..`) to avoid intermediate string allocations, and conditionally build strings to completely bypass expensive regex whitespace trimming functions like `string.match`.

## 2025-01-29 - Avoid table length operator (#) inside hot loops
**Learning:** In Lua 5.1, repeatedly evaluating a table's length using the `#` operator inside loops (e.g., `for i=1, #table` or `table[#table + 1] = x`) incurs meaningful overhead, as `#` calculates length rather than retrieving a cached value.
**Action:** For loops bounded by table length, cache the length into a local variable before the loop (`local n = #table`). For building tables in tight loops, use an explicit counter variable instead of `#table + 1` to track insertion indices.
