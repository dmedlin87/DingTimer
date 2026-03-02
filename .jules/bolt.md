## 2024-05-28 - Avoid O(N*M) loops on time-series data
**Learning:** In `UI_XPGraphWindow.lua`, calculating a sliding sum over a chronological event log was done by re-iterating the entire event list for every graph segment (N segments * M events). Because the events are strictly chronologically ordered, we can do this in O(N+M) by advancing a single pointer (`evIdx`).
**Action:** Always check if nested loops over time-series data can be flattened by maintaining a pointer across the outer loop.
