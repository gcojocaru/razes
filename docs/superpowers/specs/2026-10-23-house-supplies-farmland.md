# House supplies and paintable farmland

Opening the house shows food, coins, wood, stone, and planks, plus used and total material storage. A Buy supplies button opens the existing materials purchasing panel. Keep its prices, affordability checks, storage limits, crafting, and storage upgrades. Food provisions retain their existing seasonal assignment mechanic.

Add Farmland beside pavement and paths in Construction. Reuse pavement’s click-and-drag tile painting, preview, placement controls, per-tile one-coin cost, and Erase tool. Players choose the location, shape, and size by painting tiles. Prevent overlap with the house, buildings, scenery, pavement, and paths. Replace the fixed field graphic with farmland tiles that show seasonal crop state. Field selection and farming commands must work on the painted land, including keyboard access through Places.

Keep the current sow/tend/harvest rules and yields for this first change; land size defines the cultivated area without adding a new balance system. Require at least one farmland tile to sow, and prevent painting or erasing farmland while an unharvested crop or a farming assignment is active. Show the reason when editing is unavailable.

Preserve existing saves by defaulting missing farmland data to the current nine field tiles. New games also begin with those nine tiles so existing starting balance remains playable. Save custom farmland and validate bounds, duplicates, and overlaps during load.

Approach: reuse pavement’s infrastructure pipeline, as requested. A rectangular two-corner tool was considered and rejected in favor of free tile painting.

Check placement, cost, erase, crop protection, save compatibility, malformed saves, and scene updates with focused tests; build the Mac app and inspect the house panel, buying panel, and farmland placement in the UI.

Scope: native Mac game only. No browser gameplay changes, new dependencies, per-tile crop simulation, or yield scaling.
