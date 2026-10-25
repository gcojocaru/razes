# First Human Implementation Plan

> **For agentic workers:** Use the dispatching-parallel-agents skill for the independent model and rendering tasks, then integrate and review in this chat.

**Goal:** One visible autonomous farmer carries out ordered field work and meets basic food/rest needs.

**Architecture:** `Human` is deterministic RefCounted state, independent of scene
nodes. `human_actor.gd` renders that state, `human_hud.gd` shows controls and
needs, and `game.gd` owns the single clock and dispatches existing farm inputs.

**Tech Stack:** Godot 4.7.2/GDScript and original procedural meshes; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-25-first-human-design.md`

## Global constraints

One person, 100 m² plots, integer grams, no migrations. Preserve current edits
and export settings. Costs reserve once; work revalidates once at completion.
600 real seconds per day at 1×, start 06:00. All tuning limits are explicit.

## Shared interfaces

`Human.new()` exposes `position`, `facing`, `home` (Vector2 metres), `activity`
(Idle/Walking/Working/Cooking/Sleeping/Dead), `job` (Dictionary),
`queue` (Array[Dictionary]), `carried_crop`, `carried` (grams),
`calories`, `fatigue`, `health`, `message`, `sleep_remaining`,
`eating_requested` and `advanced_hours` (actual time consumed by the last advance).

- `order(farm: Farm, cells: Array, day: int, action := "", crop := "") -> int`
- `cancel(farm: Farm) -> void`, `wake_up() -> void`, `reserved_seed() -> int`
- `eat(farm: Farm, crop: String, grams: Variant) -> bool` requests a selected
  meal (updated by the camp-food follow-up).
- `sleep(hours: Variant) -> bool` and `sleep_prediction(hours: Variant) -> Dictionary`
  replace indefinite rest in the camp-sleep follow-up.
- `advance(farm: Farm, day: int, hour: float, hours: float) -> bool`: internally
  subdivides into at most one-minute steps; caller splits at midnight and
  supplies current day/hour. Returns true if farm/stock state changed.

`human_actor.gd.new(metres_to_units: float)` is a Node3D;
`show_person(person, seconds: float)` updates pose/location, and
`create_camp() -> Node3D` returns a separate scaled camp at origin.

## Review focus

Exact food/seed accounting on interrupt, stale jobs and death; midnight and
pause consistency; long skips; malformed/duplicate orders; actual renderer
scale and legibility with crops/UI. Tests exercise each boundary.

### Task 1: Human model and deterministic checks

Own `godot/human.gd`, `godot/tests/test_human.gd`. Add failing behavioral tests,
implement shared interfaces and spec rules, run that suite, and report limits.
Do not edit other files or commit.

- [x] Test first; observe failure against missing/new behavior.
- [x] Implement model, reservations/hauling and needs.
- [x] Run deterministic tests including conservation and time subdivision.

### Task 2: Human and camp renderer

Own `godot/human_actor.gd`, `godot/tests/test_human_actor.gd`. Use metre-sized
procedural meshes, actual poses and carrying. Test bounds/grounding/scale and
paused pose stability. Do not edit game/model/HUD or commit.

- [x] Test first; observe failure.
- [x] Implement original meshes, camp and poses through shared interface.
- [x] Run geometry/pose checks and report visual limitations.

### Task 3: Game, HUD, regression fixtures and documentation

Own `godot/game.gd`, `godot/human_hud.gd`, `godot/time_hud.gd`,
`godot/farm_hud.gd`, `godot/action_wheel.gd`, `godot/crops.gdshader`, existing
crop/menu tests, `godot/tests/test_person_scene.gd`,
`godot/tests/capture_human.gd`, README, wiki, artwork and validation notes.
Consume tasks 1 and 2 without duplicating their state or implementation.

- [x] Write failing scene input/clock checks.
- [x] Integrate the shared clock, queue inputs, needs panel and actor.
- [x] Adapt instant-work assertions to execute the actual queue.
- [x] Document all controls, pacing and explicit survival abstractions.
- [x] Run import and all seven test scripts; inspect GPU captures.
- [x] Request an independent final review, resolve findings, leave uncommitted.

Review fixes: previews exclude assigned plots and explain queued work; camera
panning includes camp; completion of stale work refreshes action availability.
Each regression was observed failing before its fix, then all seven suites passed.

### User follow-up: manual needs and Game Over

- [x] Remove starting flour, automatic meals and automatic rest/sleep.
- [x] Add Eat/G and Rest/Resume/R with immediate paused UI feedback.
- [x] Track negative energy and actual elapsed time up to zero health.
- [x] Freeze play behind Game Over; verify death, F10 and keyboard Restart.
- [x] Update documentation, all seven suites and GPU captures.

The subsequent camp-food plan replaces direct Eat/G with camp context input,
ingredient/quantity selection and a shared proportional porridge recipe.
