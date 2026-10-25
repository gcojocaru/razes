# Camp Sleep Implementation Plan

**Goal:** Camp → Sleep → hours and live recovery preview → timed sleep.

**Architecture:** Human owns timed sleep and predicts it using an isolated Human
running the same advancement. A sleep HUD window uses the existing frame;
Game routes camp, keyboard, live updates and Game Over.

**Tech Stack:** Godot 4.7.2/GDScript; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-25-camp-sleep-design.md`

## Constraints and review focus

One person; no migrations or commits; retain existing uncommitted work.
Sleep restores fatigue, burns food energy and must not spend reserved grain.
Check travel/death in predictions, sleep deadlines across frame sizes,
preserved work/seed, menu focus, typed hours and Game Over isolation.

### Task 1: Model

Files: human.gd and tests/test_human.gd.
Interfaces: sleep(hours: Variant) -> bool; wake_up() -> void;
sleep_remaining: float; sleep_prediction(hours: Variant) -> Dictionary with
fatigue, calories, health and hours (elapsed travel plus sleep).

- [x] Write failing tests for duration, daytime sleep, seed preservation,
  validation, travel/death forecasts and subdivision; observe missing behavior.
- [x] Replace indefinite rest with timed sleep, shared-rate predictions and
  early waking. Run test_human.gd, expecting PASS and exit 0.

### Task 2: Camp and window

Files: camp_menu.gd, new sleep_window.gd, human_hud.gd, game.gd,
food_window.gd, tests/test_camp_sleep.gd, test_person_scene.gd,
capture_human.gd, README, wiki and validation notes.

- [x] Write and run failing scene test: click camp/Sleep, type hours, preview,
  close without sleeping, confirm exact duration, pause, wake, meal conflict,
  preserved queue, field input isolation and death/Restart.
- [x] Add menu item and focused keyboard activation; shared-style duration
  window; R configuration/early waking; replace direct Rest control.
- [x] Update fixtures/docs, run all nine suites and inspect GPU captures at
  normal/minimum sizes. Request one independent final review and fix any
  material findings with a failing regression first. Leave uncommitted.

## Execution record

Pre-flight: task 2 consumes task 1's exact interfaces above; no conflicts.
Existing codex/bottom-panel-icons workspace retained with all prior edits.
Task 1: complete — model duration/forecast tests observed RED → GREEN, exit 0.
Task 2: camp input observed RED → GREEN; all nine suites exit 0. GPU check
prompted dynamic scroll fitting after text layout. Documentation updated;
final capture recheck passed at both sizes including the starvation warning.
Final review: independent read-only review found no issues or deferred items.
Work remains uncommitted.
