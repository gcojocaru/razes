# Construction, progression, and survival skills

Approved implementation specification, 2026-10-24. Native macOS only. No migrations; schema 11/new filename resets progress. Keep existing architecture and dependencies.

## Construction catalogue
- 900 × 600 modal catalogue: left building/house list, right artwork, benefits, complete requirement table (required/free/missing), all blockers and actions. Separate land/paths tab. Body >=14 pt, secondary >=13 pt, opaque contrasting surfaces, locked rows readable/selectable. Show Locked/Missing supplies/Ready to build/Under construction/Operational/Needs repair.
- Show completion date/weeks, next seasonal payout, practical bonuses, upgrade/repair costs. Placement dismisses catalogue. Reuse clear details in map inspector. House upgrade entry included.
- H1/B1: woodshed, cellar, well, workshop. H2/B2: barn requires completed well; granary requires cellar; apiary requires well; storehouse requires workshop. H3/B3: bakery requires granary; smithy requires workshop; stable requires barn.
- Building upgrades require max(type minimum,target level) house and Building skill. House upgrades retain current resource costs/no skill gate. Prerequisite condition does not affect blueprint access. Shared core checks enforce locks and free-resource affordability; worker task checks never double-count own reservations.

## Effects and crafting
- Existing prices/yields remain except Workshop needs 4 wood+2 stone+5 Galbeni, no planks.
- Practical effects activate once completed with condition>0. Passive income retains following-season timing. Storehouse retains capacity at condition 0.
- Well +2 harvest food/level; Granary +1 harvest seed/level; Bakery +1 provision food/level stacking cellar 7→10; Stable +1 wage; Smithy changes planks 2 wood→1 plank to 1 wood→1 plank. Woodshed/cellar/storage existing effects remain. Barn/Apiary passive yields remain.
- Immediate crafting requires operational Workshop, consumes no worker/XP; controls live there, Materials links to workshop. Buying planks remains 3 Galbeni. Shared crafting calculation checks actual recipe, free wood and capacity.
- Forecast/report name contributing buildings and effects, including passive income breakdown.
- House level2+ new timber porch/plaster/stone foundation art, front/rear × summer/winter × intact/damaged, mirrored for four views. Same footprint; level3–5 reuse upgraded appearance.

## Skills, task persistence, saves
- Strength/Endurance use 3XP/level, cap12XP/level5. Strength +1XP wages or successful gathering; wages=start Strength level +1 operational Stable.
- Endurance +1XP productive farming/gathering/repair/worker construction/wages, none rest/provisions/instant. Energy=max(5,base10 paid/provisions or20 physical -2*(level-1)) +10 if health<25. Rest35 (25 exposed)+2*(level-1), same healing.
- Building +1XP per finished foundation, all placement methods, replacing worker-construction start XP. Effective weekly repairs +1XP. All rewards use starting skills. Foundation XP included in forecast and applied exactly once.
- Continue repeats previous task only if next-state assignmentProblem=nil; else Rest plus visible reason. Completed assignment remains intact during summary/death.
- SeasonReport.buildingsBefore snapshot preserves pre-resolution effects/foundations for strict replay after wear and summary edits. Schema11 and settlement-v11.json, no migration.
- Rename ALL native visible currency to Galbeni, retain internal money fields.

## Shared interfaces
- ConstructionRequirements: public houseLevel, buildingLevel:Int; prerequisite:BuildingID?; coins,freeCoins:Int; materials,freeMaterials:MaterialStock; locks,shortages:[String]; problems:[String] (locks+shortages); isMet:Bool.
- Construction.requirements(_ id:BuildingID,state:GameState,level:Int=1)->ConstructionRequirements; repairRequirements(_ id:BuildingID,state:GameState)->ConstructionRequirements; unlockProblems(_ id:BuildingID,state:GameState,level:Int=1)->[String]; operationalLevel(_ id:BuildingID,state:GameState)->Int; practicalBenefit(_ id:BuildingID,level:Int)->String.
- Materials.plankWoodCost(state:GameState)->Int; craftingProblems(quantity:Int,state:GameState)->[String]; houseUpgradeRequirements(state:GameState)->ConstructionRequirements.

## Verification
Meaningful red/green tests per new logic, native full suite, reachability/reservations/unchanged failure state, all effects & damaged buildings, skill thresholds/XP/energy, repeat/fallback/calendar, frozen saves after summary edits, catalogue snapshots at1000×700 and1280×850, keyboard/VoiceOver where possible, house rotations/winter/damage, package/signature. No browser edits.
