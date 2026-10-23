# Real-time building progression

The user selected real-time construction and decay. Add ten freely placed building types, each with levels 1–5: woodshed, root cellar, barn, well, granary, workshop, bakery, smithy, stable and apiary. The starter house retains its existing shelter/seasonal repair rules.

Construction costs coins immediately and runs independently of seasonal workers and story phases, including after the first-year ending. Existing seasonal woodshed/cellar assignments remain valid for old households. Builds take 30–90 seconds, upgrades take 60 seconds per target level, repairs take 20 seconds. Upgrades cost the base price times the target level; repairs cost half the base price rounded up. Construction and upgrades restore condition to 100.

Buildings produce food or coins every 60 seconds multiplied by their level. They lose four condition points per real hour. At zero condition, a building above level 1 loses a level and returns to 60 condition; level 1 remains at zero, stops producing and can be repaired. Work pauses production and wear. Production and decay integrate correctly across completion and downgrade boundaries. Resource totals cap at 100000. Seasonal benefits on the original two buildings remain; inactive ruins do not supply them. Historical winter reports retain the wear actually applied.

Persist timers, condition and fractional production in schema 4. Resume across restarts with a maximum 24 hours catch-up per absence; backwards clock changes never replay time. Save migration preserves v1–v3 bytes before first write. Reject malformed levels, timers, coordinates and non-finite values. Do not modify browser gameplay or the user's live save during validation.

The scene keeps existing artwork and composes distinct new silhouettes, level extensions, wear marks, level badges and progress bars. Reduced motion keeps status visible. The inspector exposes upgrade/repair with costs and remaining times. Debug offers instant placement, levels 1–5, condition editing, resources, finish-all and +1 hour/+24 hours clock steps.
