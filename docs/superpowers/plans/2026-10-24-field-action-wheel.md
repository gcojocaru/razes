# Field action wheel implementation plan

> Execute inline in the existing isolated worktree, using executing-plans and test-driven-development.

**Goal:** Replace the crop popup with approved segmented contextual field actions.
**Architecture:** A Godot Control overlay builds action entries with Farm.preview and emits existing action/crop signals. Polygon-shaped native buttons provide radial targets and keyboard focus; the existing HUD and game retain all gameplay ownership.
**Tech stack:** Godot 4.7, GDScript, existing fonts and palette, original vector icons drawn in code.
**Spec:** docs/superpowers/specs/2026-10-24-field-action-wheel-design.md

## Constraints and review focus

No gameplay/save changes, migrations, or dependencies. Respect right-drag rotation and multi-selection. Check stale availability as time passes, click-through on dismissal, depleted seed, empty/growing/winter selections, and viewport edges.

## Task 1: Contextual wheel and input integration

- [x] Add failing test_wheel.gd checks for grass/plowed/ripe/growing/mixed states, seed/season limits, focus, dismissal, boundary positioning, refresh, and revalidation.
- [x] Run `./godot/run.sh --headless --script tests/test_wheel.gd` and confirm missing-wheel failure.
- [x] Add godot/action_wheel.gd: open_at(position), show_farm(farm,cells,day,seed_crop), entries, activated(action,crop); segmented geometry, icon/label/cost rendering, native keyboard buttons, outside/Escape dismissal.
- [x] Replace farm_hud.gd crop popup with the wheel; route its signals to existing work/choose_crop; update game.gd entry points. Block field and camera input while the wheel is open.
- [x] Adapt existing test_crops.gd popup assertions to wheel entries and focus without reducing selection/rotation coverage.
- [x] Import and run test_wheel, test_crops and test_menu; resolve failures.

## Task 2: Player instructions and visual verification

- [x] Update README, wiki and VALIDATION to describe contextual actions and shortcuts.
- [x] Capture GPU-rendered grass/plowed/ripe/mixed/edge screens; inspect icons, labels and fit.
- [x] Review final diff against spec and rerun affected checks. Record results here.

## Progress

Design approved with “lets do it”. Implementation and review complete. All three headless test scripts passed with exit 0. Nine rendered state/edge captures were inspected on Apple M4. Regression tests caught first-opening label sizing, long-reason overflow, bottom-edge hint overlap, and modal input priority. The reviewer confirmed the input-order fix. Physical accessibility and other platforms were not tested.
