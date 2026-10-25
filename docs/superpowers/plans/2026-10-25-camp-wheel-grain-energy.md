# Camp Wheel and Grain Energy Implementation Plan

**Goal:** Shared camp action wheel and ingredient-specific meal calories.
**Architecture:** Camp extends the existing action wheel; Farm stores dry-grain
energy density, and Human.porridge(crop, grams) serves preview and meal output.
**Tech Stack:** Godot 4.7.2/GDScript, existing SVG icon style.
**Spec:** `docs/superpowers/specs/2026-10-25-camp-wheel-grain-energy-design.md`

## Constraints and review focus

Preserve existing uncommitted work and foreign export settings; no migrations
or commits. Check inherited wheel dispatch, focus reset, annular picking,
outside clicks, live calorie selection and precise energy after cooking.

- [x] Write and run failing crop-aware porridge and five-grain completion tests.
- [x] Add calorie density to Farm; update Human, food preview, bag tooltips and
  affected numeric fixtures. Observe model/input tests pass.
- [x] Write failing camp wheel mouse/keyboard/resize checks; add two SVG icons,
  reuse the wheel with camp effects/activation and adapt old button fixtures.
- [x] Run all nine suites, inspect GPU captures, update docs/sources and obtain
  one independent final review. Leave changes uncommitted.

Model and camp regressions observed RED → GREEN. A first-opening keyboard
regression also observed RED → GREEN after correcting empty crop focus matching
in the shared wheel. All nine suites pass; GPU captures checked at both sizes.
The existing inventory test was adapted to retain its exact mass line while
accepting the new nutrition line. Final independent read-only review found no
actionable issues or deferred items. Work remains uncommitted.
