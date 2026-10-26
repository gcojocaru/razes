# Woodland, Shelter and Exposure Implementation Plan

**Approved:** 26 October 2026. Execute inline; one independent final review.
**Goal:** Woodland → hauled wood → permanent timber shelter → cooking/heating → thermal survival.
**Architecture:** Farm owns woodland, ground piles and deposited wood; Human owns orders, reservations and exposure. Renderers read state. Weather samples game time, not audio gusts.
**Constraints:** Godot 4.7.2 Compatibility. No saves/migrations, generic crafting, individual trees, extra materials, clothing system, planting, thirst or diseases. Existing crop indices/daily weather/grain accounting stay intact.

## Task 1: Woodland and hauling
- [x] Test seeded clumps on ~25% of usable plots, >=16 clear reachable plots, cultivation/camp restrictions and pure previews.
- [x] Two natural textured broadleaf GLBs from EZ-Tree with provenance/licences, terrain/season/wind/occlusion rendering. Whole-plot selection; woodland walkable.
- [x] Chop 6h → 240 kg ground pile; automatic <=15kg trips; only deposits spendable. Partial chop/piles/carried wood survive cancel; piles block farming.
- [x] Cleared unused grass regrows after 2 game years; cultivation/camp prevents regrowth. Separate integer-gram wood stock, field actions/inventory/ledger/debug.

## Task 2: Shelter and fire
- [x] Test resource conservation, construction interruption/refund/once, movement restriction, cooking/heating sharing.
- [x] Camp Build shelter reserves 300kg and takes 8h work, preserves field jobs. Eat/Sleep/Recover interrupt then resume. Clear jobs resets/refunds construction. Moving unfinished camp cancels; completed shelter disables Move.
- [x] Original compact timber/shingle hut with vented hearth and roof/wall occlusion fading. Comfortable sleep clears fatigue in 6h vs 8h outdoors. Roof stops precipitation, reduces wind/cold and shades sun; fire supplies winter heat.
- [x] Start 48kg; enabled/toggleable heating burns 0.5kg/h only at home. Cooking reserves grain plus fuel, same fire/no double-charge, refunds unused fuel. Exact exhaustion, paused/dead/away consumes nothing. Show kg and burn duration; fire/light reflect state.

## Task 3: Exposure and forecasts
- [x] Test neutral/wet cold/winter sheltered/hot work/shaded recovery scenarios, forecasts vs outcomes, minute/long-step equivalence, midnight/fuel/death/pause/Restart.
- [x] Wetness 0–1, initial core37°C, exposure health100. Precipitation/sweat/drying/metabolic heat/shivering/wind/sun/shelter/fire with body mass/energy; one fixed insulation assumption. Cold costs energy; extremes slow pace/recovery and damage health. Health=min(BMI health,exposure health). Warnings <36/>38, damage <35/>39; safe rest heals exposure. Document/calibrate coefficients as game tuning.
- [x] Manual Recover at camp preserves jobs/deposits/rests until wetness<=0.1 and core36.5–37.5; no sleep bonus; cancellable; warnings when unsafe. No automatic emergency return.
- [x] Weather.at(day,hour) deterministic hourly temp/wind/sun; daily crop Weather.on unchanged. Sleep forecast clones resource/reservation/fire/shelter/exposure and follows actual future weather/travel/midnight/fuel exhaustion without mutation.
- [x] Update field/camp/Body/food/sleep/inventory/ledger/debug/wiki/README/validation. Run every suite, native captures/input/minimum viewport, tree performance comparison, terrain/weather survival simulation and independent review.

## Review focus
Mixed jobs/piles preserve stock; construction/cooking/heating cannot spend reservations twice; forecasts/skips handle weather/fuel; cancellation/movement/death cannot duplicate wood; foliage/roof cannot hide farmer/controls.
