# Household materials

Approved in conversation: seasonal gathering, immediate buying and crafting, shared material storage in the house (expanded by house upgrades) and a separate storage building. Implement in native macOS; browser gameplay stays independent.

## Approaches

Materials only would omit the requested crafting foundation. Full production chains add unnecessary complexity. Use wood, stone and one immediate recipe (2 wood → 1 plank), with both gathering and buying available. No worker or timer for buying/crafting, no selling or depletion.

## Rules and initial tuning

Start with 6 wood and 4 stone, capacity 20. Each unit of any material occupies one slot; food and coins stay separate. Gather timber yields 6 wood per worker/season; gather stone yields 4 stone. Work forecasts show accepted quantities and storage truncation before confirmation. Fill in displayed worker order (Ion, Ana, Petru). Supplies arrive when work resolves; future supplies cannot fund current construction. Post-story gathering resolves through Next settlement season, retaining the story records.

Buying one unit costs 1 coin for wood/stone, 3 for planks. Only free coins may be spent. Instant crafting consumes 2 free wood and produces 1 plank; check capacity after consuming ingredients. All failures leave state unchanged. Seasonal legacy construction reserves materials as well as money.

House storage levels 1–5: 20 + 10 per additional level. Instant upgrade costs 4 × target level coins plus 2 wood, 2 stone, 1 plank. This changes capacity, not shelter condition. Storehouse costs 4 coins, 6 wood, 2 stone, 2 planks; finishes at season end and adds 40 capacity per completed level. Its materials fit in starter storage. Storehouse uses existing granary artwork. Existing building coin costs, production and seasonal wear remain; construction, upgrades and repairs also consume materials. Upgrade materials scale with target level. Basic buildings use wood/stone; advanced buildings introduce planks. Roads/fences retain their existing coin costs in this increment.

Storage cannot destroy supplies: storehouse wear/downgrades can leave inventory over capacity; block intake until room exists, allow spending. Zero condition does not eject stored materials or remove the surviving level's capacity. No building removal in live gameplay. Materials and storage management remain available in all phases; gathering assignment changes are allowed during work and at the ending.

## Integration and safety

Schema 7 persists inventory, house storage level and optional seasonal material report. Migrate schemas 1–6 with starter materials; preserve all existing household state and migration backups before overwrite. Preserve material reservations on instant actions. Reject negative, oversized, non-integer and missing current-schema data. No live user save during validation.

UI: Materials button, inventory/capacity, buy quantity, instant plank crafting, gathering assignment controls, house storage upgrade, storehouse placement and material costs in construction/upgrade/repair views. Forecasts and season summaries expose material outcomes. No additional dependencies.
