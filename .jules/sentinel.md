## 2024-05-24 - Unhandled NaN/Infinity in UI Logic
**Vulnerability:** The `FormatNumber` function used for formatting statistics in UI elements could fail when given `NaN` or `Infinity` resulting from division by zero in calculations (like XP/hour when time elapsed is 0).
**Learning:** WoW Addon UI crashes or unexpected behavior can act as a Denial of Service if error handling is lacking for edge-case mathematical inputs.
**Prevention:** Always validate numeric inputs in math-heavy formatting logic (`num ~= num` for NaN, `num == math.huge` or `-math.huge` for infinity) and provide safe fallbacks.

## 2024-05-24 - Unbounded Event Logging (DoS)
**Vulnerability:** Unbounded insertion into UI state tables when the corresponding UI frame is hidden (e.g. `NS.state.moneyEvents` or `graphState.events`).
**Learning:** In event-driven UI frameworks (like WoW Addons), if data pruning is tied exclusively to the UI render loop (e.g. `OnUpdate` or redraw functions), hiding the UI disables pruning. A malicious actor can then trigger a flood of events (e.g. rapid 1-copper trades) to cause unbounded table growth, leading to memory exhaustion and a client crash (Denial of Service).
**Prevention:** Always enforce data pruning and boundary checks directly at the event ingestion layer (the event handler), independent of the UI render state.
