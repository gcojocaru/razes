# Godot Village Implementation Plan

> **For agentic workers:** Use the parallel-agent workflow for the independent rules, models and world tasks, then integrate and verify in this session. Steps use checkbox syntax for tracking.

**Goal:** Deliver a playable, textured 3D Răzeș desktop game with the native simulation and purchasable land.

**Architecture:** A standalone `godot/` project uses JSON-compatible game dictionaries and pure rule functions, one Node3D village and one Godot Control interface. Existing Swift and browser applications provide references and remain independent.

**Tech Stack:** Installed Godot 4.7.2, typed GDScript, Compatibility renderer, orthographic Camera3D, standard Godot meshes/materials and local JSON saves.

**Spec:** `docs/superpowers/specs/2026-10-24-native-3d-village-design.md`

## Global constraints

- Target Mac, Windows and Linux; record platforms actually executed.
- Start with 16 × 16 tiles; unlock adjoining 16 × 16 parcels in a finite 48 × 48 map.
- Keep a fixed coordinate origin, 2 metres per tile and ground-centred model pivots.
- Use warm rural textures and recognizably different building silhouettes.
- Port the current native rules, including reservations, skill gains, crop timing, construction and death guards.
- No save migrations, Swift bridge, engine plugin dependencies or changes to the reference applications' rules.
- Work in the existing non-main checkout; the new `godot/` tree is disjoint from the user's package-lock and Finder changes.

## Review focus

- Building footprints crossing locked parcel boundaries must reject the complete placement.
- Negative coordinates map to the correct parcel using floor division.
- Purchases must preserve weekly reservations and fail atomically.
- UI input and dragging must not place or select objects behind controls/modal windows.
- Corrupt saves and invalid game actions must preserve the last valid household.

## Shared interfaces

Game dictionaries use the native camelCase JSON keys, with `version = 1` and `layout.ownedParcels = [{x: 0, y: 0}]`. Positions in persisted dictionaries are `{x: int, y: int}`. Public map inputs use `Vector2i`. Building records remain `{id, level, condition, completedSeason, legacyAssignment, debugPlaced}`; layout buildings are `{id, position, facing}`. All eleven building IDs retain their current native strings.

`VillageRules` (`RefCounted`) exposes static `new_game() -> Dictionary`, `act(state, action: String, payload: Dictionary = {}) -> Dictionary` returning `{state: Dictionary, error: String}` without mutating the input, `forecast(state) -> Dictionary`, `validate(state) -> String`, `placement_problem(state, kind: String, tile: Vector2i, facing: int = 0) -> String`, `footprint(kind: String, facing: int = 0) -> Vector2i`, `available_money(state) -> int`, `available_materials(state) -> Dictionary`, `requirements(state, id: String, level: int = 1) -> Dictionary`, `crop_stage(state) -> String`, `display_season(state) -> int`, and `DEFINITIONS` keyed by building ID. Required actions are `assign`, `end_week`, `continue`, `place_building`, `upgrade_building`, `repair_building`, `rotate_building`, `place_scenery`, `remove_scenery`, `infrastructure`, `buy_land`, `buy_material`, `discard_material`, `craft`, `buy_seeds`, `upgrade_house`, `preview_season`, and `debug_building`. Payloads use `task`, `id`, `position`, `facing`, `kind`, `amount`, `season`, `instant`, `level` as needed. `position` is a persisted position dictionary. Land price is 20 Galbeni, beside balance constants; purchase uses `position` as a parcel index. Infrastructure kinds are `pavement`, `dirtPath`, `farmland`, `fence`, `wattleFence`, `erase`; scenery kinds are prefixed `scenery:` for placement checks.

`VillageModels` (`RefCounted`) exposes static `building(id: String, level: int = 1, condition: float = 100, winter: bool = false, progress: float = 1.0) -> Node3D`, `figure(task: String = "rest") -> Node3D`, and `scenery(kind: String, winter: bool = false) -> Node3D`. Roots sit at ground height and footprint centre, building bounds fit 4 × 4 metres (house 6 × 6). Mesh/material resources are shared. Models contain no game state or UI.

`VillageWorld` (`Node3D`) exposes signals `selection_changed(selection: Dictionary)`, `placement_requested(kind: String, tile: Vector2i, facing: int)`, `parcel_selected(parcel: Vector2i)`, and methods `set_state(state: Dictionary)`, `set_tool(kind: String, facing: int = 0, instant: bool = false)`, `set_selection(selection: Dictionary)`, `rotate_map(delta: int)`, `zoom_camera(factor: float)`, `reset_camera()`, `set_reduce_motion(value: bool)`. Selection dictionaries use `{kind: "building"|"worker"|"hotspot"|"scenery", id: String}`. `kind = ""` cancels placement. Export `grid_to_world(tile: Vector2, footprint: Vector2i = Vector2i.ONE) -> Vector3` and `world_to_grid(point: Vector3, footprint: Vector2i = Vector2i.ONE) -> Vector2i` for coordinate tests. Map building tools use their building ID; infrastructure uses its kind string. Land selection emits a parcel index.

## Task 1: Rules, ownership and simulation parity

**Files:** `godot/scripts/village_rules.gd`, `godot/scripts/game_content.gd` if needed, `godot/tests/test_rules.gd`, native reference fixtures under `godot/tests/`.

- [x] Write and run failing checks for new game, the weekly loop and ownership purchases.
- [x] Port the native rules and all required actions using the shared API, with rejected actions leaving state unchanged.
- [x] Add strict save-state validation; test corrupted directions, inventory, ownership and reports.
- [x] Compare representative initial/action/result states with native Swift-generated reference fixtures.
- [x] Run `Godot --headless --path godot --script tests/test_rules.gd`; expect clean exit and explicit passed count.

## Task 2: Grounded textured models

**Files:** `godot/scripts/village_models.gd`, `godot/tests/test_models.gd`.

- [x] Write failing bounds/silhouette checks for every building, five levels, winter and foundation models.
- [x] Build shared matte wood/plaster/stone/roof textures and distinctive real geometry for every type, house, scenery and Ion.
- [x] Verify geometry minima meet the ground, bounds fit each reserved plot and upgrade geometry changes.
- [x] Run the headless model checks; expect no invalid meshes/materials and a clean exit.

## Task 3: Terrain, camera and map input

**Files:** `godot/scripts/village_world.gd`, `godot/tests/test_world.gd`.

- [x] Write failing coordinate round-trip and stable-entity checks.
- [x] Implement orthographic camera, terrain/locked parcels, seasons, paths, farmland/crops, fences, model synchronization and worker placement.
- [x] Connect selection and placement ray tests to the shared signals; preserve click-versus-drag, painting, R rotation, zoom and camera reset.
- [x] Use the exact same transforms/models for previews and committed structures.
- [x] Run headless coordinate and state-update checks and inspect actual rendered output.

## Task 4: Playable interface, saves and desktop project

**Files:** `godot/project.godot`, `godot/main.tscn`, `godot/scripts/main.gd`, `godot/scripts/save_store.gd`, `godot/tests/test_save.gd`, `godot/export_presets.cfg`, `.gitignore`, root and Godot READMEs.

- [x] Configure the pinned engine project, shared resources, desktop sizing and generated-output ignores.
- [x] Write failing save round-trip/corrupt-primary recovery checks, then implement validated atomic save and recovery writes.
- [x] Implement keyboard-accessible HUD, tasks, forecast/summary, building/material/land controls, inspectors, recovery and fresh start, settings and previews.
- [x] Integrate map signals with rule actions and save successful mutations. Show action errors in the interface.
- [x] Add export presets for Mac/Windows/Linux and document exact launch/test/export commands.

## Task 5: Verify, inspect and review

- [x] Run all Godot checks with actual exit codes; reject script parser errors as failures.
- [x] Run the game and capture actual renderer output at multiple views, seasons and land/placement states.
- [x] Fix visual/gameplay integration failures and run the complete checks again.
- [x] Obtain a fresh code review, resolve important findings and update `godot/VALIDATION.md` with actual evidence and remaining platform/accessibility limits.
- [x] Present the runnable project and verification results without claiming Windows/Linux hardware testing or distribution signing.

## Execution record

- Installation verified: `4.7.2.stable.official.ed1daf0bf`, `/Users/gheorghecojocaru/Downloads/Godot.app/Contents/MacOS/Godot`.
- User installed Godot after selecting Windows/Linux and receiving the Godot proposal; proceed with that direction without another confirmation cycle.
- The independent rules, models and map work have fixed shared interfaces above. Integration, saves and project configuration are owned by the primary agent.

## Completion evidence

- Five headless suites pass: rules 3,905, models 10,264, world 72, saves 14, application 24 checks. Normal-permission execution has clean engine output.
- Actual GPU screenshots were inspected and used to correct HUD layout and scene lighting.
- Fresh review findings were fixed with red/green regressions; reserved plans, scenery rotation and debug tools are reachable.
- All three desktop presets generated development data packs. Standalone binaries remain ungenerated because export templates are not installed; Windows/Linux hardware and screen-reader validation are unverified.
- No commits or native/browser gameplay changes were made; the working diff remains reviewable.
