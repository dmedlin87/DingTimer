## 2024-05-24 - Unhandled NaN/Infinity in UI Logic
**Vulnerability:** The `FormatNumber` function used for formatting statistics in UI elements could fail when given `NaN` or `Infinity` resulting from division by zero in calculations (like XP/hour when time elapsed is 0).
**Learning:** WoW Addon UI crashes or unexpected behavior can act as a Denial of Service if error handling is lacking for edge-case mathematical inputs.
**Prevention:** Always validate numeric inputs in math-heavy formatting logic (`num ~= num` for NaN, `num == math.huge` or `-math.huge` for infinity) and provide safe fallbacks.
