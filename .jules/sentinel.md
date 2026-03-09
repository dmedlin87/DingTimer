## 2024-05-24 - Unhandled NaN/Infinity in UI Logic
**Vulnerability:** The `FormatNumber` function used for formatting statistics in UI elements could fail when given `NaN` or `Infinity` resulting from division by zero in calculations (like XP/hour when time elapsed is 0).
**Learning:** WoW Addon UI crashes or unexpected behavior can act as a Denial of Service if error handling is lacking for edge-case mathematical inputs.
**Prevention:** Always validate numeric inputs in math-heavy formatting logic (`num ~= num` for NaN, `num == math.huge` or `-math.huge` for infinity) and provide safe fallbacks.

## 2024-05-24 - Unbounded Event Logging (DoS)
**Vulnerability:** Unbounded insertion into UI state tables when the corresponding UI frame is hidden (e.g. `NS.state.moneyEvents` or `graphState.events`).
**Learning:** In event-driven UI frameworks (like WoW Addons), if data pruning is tied exclusively to the UI render loop (e.g. `OnUpdate` or redraw functions), hiding the UI disables pruning. A malicious actor can then trigger a flood of events (e.g. rapid 1-copper trades) to cause unbounded table growth, leading to memory exhaustion and a client crash (Denial of Service).
**Prevention:** Always enforce data pruning and boundary checks directly at the event ingestion layer (the event handler), independent of the UI render state.

## 2024-05-24 - NaN/Infinity Validation Bypass in Bounds Checks
**Vulnerability:** Bounds checks using simple `<` or `>` comparisons (e.g., `if val < min`) can be bypassed entirely if the input is `NaN`, because `NaN < x` and `NaN > x` both evaluate to `false` in Lua. An attacker can inject `NaN` via SavedVariables, allowing them to bypass security bounds (like `windowSeconds`) to disable event pruning and trigger unbounded memory exhaustion (DoS).
**Learning:** In Lua, `<` and `>` operators do not trap `NaN`. If validation logic fails to catch `NaN` and `Infinity`, those invalid values will propagate into application logic unhindered.
**Prevention:** Always explicitly check for `NaN` and `Infinity` (`val ~= val` or `val == math.huge` or `val == -math.huge`) before relying on relational operators for security or resource bounds checks.
