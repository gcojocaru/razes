# Woodland, shelter and exposure — approved design

Approved in chat on 26 October 2026, including the starting values below. The [implementation plan](../plans/2026-10-26-woodland-shelter-exposure.md) tracks delivery and verification.

## Intent and approach

Add a useful wood-resource loop to the single-person Godot homestead. The user chose wooded plots over individually selectable trees, construction over a stockpile-only resource, and a permanent camp shelter as the first construction. Reuse existing field selection/jobs/camp controls rather than a general crafting or building framework.

## Woodland

Seed natural groves across approximately 25% of dry usable plots, with at least 16 clear reachable plots. Trees are natural textured broadleaf models, optimized static EZ-Tree GLBs with provenance, seasonal leaves, wind/snow, terrain placement and visibility through obstructing foliage. Woodland blocks cultivation and camps, not walking.

A Chop order takes six game hours and leaves 240 kg usable wood in a ground pile. The farmer automatically makes <=15 kg hauling trips before starting the next plot. Only deposited wood can be spent. Cancellation preserves partial chopping, unhauled piles and carried resources; piles block farming until removed. Cleared grass left unused regrows over two 336-day years; cultivation/camp occupation prevents regrowth. Wood is integer grams separate from cereal stock and crop shader indices. Previews own their mutable copies.

## Shelter and fire

Build shelter reserves 300 kg deposited wood and takes eight hours at camp, preserving field work. Meals, sleep and recovery interrupt and resume building. Clear jobs resets unfinished construction and refunds its reserved wood; moving an unfinished camp cancels it too. A completed shelter permanently disables Move.

The user selected a compact enclosed timber hut inspired by the Romanian Feneș pastoral hut: timber walls, shingle roof, vented hearth and a visible interior cutaway. It blocks rain/snow, reduces wind/cold and provides shade. Comfortable shelter sleep clears full fatigue in six hours versus eight outdoors. Winter warmth needs a fire.

Start with 48 kg wood. Toggleable heating is enabled initially and burns 0.5 kg/hour only while the farmer is home. Cooking reserves grain and enough fuel together, sharing the same fire without double charging. Return unconsumed reservations on cancellation/failure; burned fuel stays consumed. Fuel exhaustion is a time boundary. Pause, absence and death stop consumption. Show stock, fuel duration and actual flame/light state.

## Exposure and controls

The user selected full cold-and-heat exposure: wetness, core temperature initially 37°C, exposure health initially100. Model precipitation, sweat, drying, metabolic heat, shivering, wind, sunlight, body mass, shelter and fire. Current clothing remains cosmetic with one insulation assumption. Cold costs calories; extremes reduce pace/sleep recovery and damage exposure health; safe rest recovers it. Overall health is min(existing BMI health, exposure health), and either can end the game. Warnings start below36/above38°C; damage below35/above39°C. Coefficients are documented game tuning, not medical predictions.

Recover at camp is explicit, preserves field work, deposits cargo and rests until wetness<=10% and core36.5–37.5°C. It gives no sleep bonus and is cancellable; warn when roof/fuel/heating state cannot help. Warnings never automatically abandon work.

Weather.at(day,hour) supplies deterministic hourly exposure weather; Weather.on(day) stays unchanged for crop means. Sleep forecasts clone supplies/reservations/fire/shelter/exposure and replay travel and future weather including midnight/fuel exhaustion without live mutation. Update game panels, wheels, inventory, ledger, debug controls, wiki and source/validation docs.

## Limits and acceptance

Godot only. No save system/migrations, individual-tree targeting, generic crafting, extra building materials, planting, clothing system, thirst or diseases.

Verify seeded generation, cultivation/camp restrictions, regrowth, pure previews, mixed/duplicate jobs, exact wood conservation and cancellation; construction lifecycle and shared cooking/heating fuel; mild weather/wet cold/winter shelter/hot work/shaded recovery; forecasts vs actual outcomes and irregular time subdivision; pause/midnight/death/Restart. Run all existing suites, native input/minimum-window/capture/performance checks, and scripted terrain/weather survival through seasonal cycles. Balance and slower hardware still need real playtesting.
