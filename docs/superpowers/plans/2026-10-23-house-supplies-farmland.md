# House supplies and farmland implementation plan

> Execute inline using executing-plans and test-driven-development.

Goal: house stock overview with access to buying; pavement-style paintable farmland.
Architecture: extend the infrastructure pipeline with farmland tiles, replace the fixed field renderer, reuse the existing materials sheet. Keep schema 8 and decode missing farmland as the old nine tiles.
Tech: Swift, SwiftUI, SpriteKit, SwiftPM.
Spec: docs/superpowers/specs/2026-10-23-house-supplies-farmland.md

## Constraints
Mac only; no dependencies; same prices and yields; farmland costs one coin per tile; preserve existing saves; block crop destruction.

## Review focus
- Missing versus explicitly empty farmland must decode differently.
- Invalid farmland coordinates, overlap, duplicates must fail safely.
- Active crops and assigned farm work must prevent edits without spending money.
- Relocated fields must update click targets, workers, map rotation, and seasonal appearance.
- Empty farmland must block sowing while retaining keyboard access to building controls.

## Task 1: Persistent farmland and placement rules
- [x] Add failing tests in SettlementTests, SaveTests, PlacementSessionTests for default/save compatibility, bounds/overlap, costs/erase and crop protection.
- [x] Add InfrastructureKind.farmland and SettlementLayout.farmland; decodeIfPresent with default nine tiles in Settlement.swift. Extend shared occupancy and validation.
- [x] Add Settlement.farmlandEditingProblem(GameState) -> String?; enforce in GameSession.placeInfrastructure and placement preview. Gate planting with nonempty farmland in Rules.taskOptions/assignmentProblem.
- [x] Run swift test; confirm all tests pass.

## Task 2: Farmland rendering and controls
- [x] Add scene tests for relocated farmland, crop visual refresh, and selection marker/worker position.
- [x] Add farmland button to BuildPanel; render one crop-state tile per saved farmland cell in InfrastructureLayer, remove fixed field sprite. Update HomesteadScene selection and IsometricLayout worker target.
- [x] Run swift test; confirm all tests pass.

## Task 3: House stock overview and buying
- [x] Add food, coins, wood, stone, planks, reserved stock and material capacity to the house inspector; pass buying callback through SelectionInspector from ContentView to open existing materials sheet.
- [x] Explain seasonal food provision purchasing in the buying sheet, preserve existing mechanics.
- [x] Update Mac help/README; run full Mac suite and package script; inspect house, buying and drag/erase in running app.

No push or PR requested. Leave changes reviewable on the isolated feature branch.

Validation: 82 Mac tests pass (46 UI/session/scene tests, 36 core tests). Debug and Release app packages built and signatures verified. Live house stocks and buying-panel affordability controls inspected. Native UI automation timed out during the subsequent debug-resource action; drag interpolation, erase, crop locking, and persistence were verified by automated session/scene tests. Independent code review found no actionable findings. Browser unchanged.
