# Procedural Terrain Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or independent bounded implementation tasks. Track steps below.

**Goal:** Give each new game rolling hills and a lake around a playable starting farm.

**Architecture:** One seeded height sampler builds a continuous terrain mesh. The existing field shader draws the farm on its level central clearing; a water plane below that clearing appears only in the generated lake basin.

**Tech Stack:** Godot 4.7.2, GDScript, FastNoiseLite, existing Compatibility shaders.

**Spec:** User delegated the smallest playable version and asked to get going. Preserve the 16×16 farm, camp, direct walking routes, character-creation edits and existing farming controls. Generate a fresh seed on each new game; there are no gameplay saves. No dependencies or save migrations.

## Review Focus

- Seeds must produce repeatable, different landscapes with a lake and hills.
- The entire farm and camp corridor must remain level and above water.
- Terrain shading must keep plot texture coordinates and selection aligned.
- Camera movement must not enter or pass below hills.
- Actual GPU views must show a shoreline and hills without obscuring farming.

### Task 1: Seeded landscape

**Files:** Create `godot/terrain.gd`, `godot/tests/test_terrain.gd`.

**Interfaces:** `new(seed: int)`, `height_at(point: Vector2) -> float`, `create_mesh() -> ArrayMesh`; constants `HALF_EXTENT`, `FLAT_HALF`, `WATER_LEVEL`; generated `lake_center` and `lake_radii`.

- [x] Write/run failing checks for repeatability, seed variation, flat central ground and dry camp routes, guaranteed lake basin and hills over many seeds, mesh heights and upward normals.
- [x] Implement smooth seeded hills and a lake outside the central clearing, using FastNoiseLite and a subdivided mesh.
- [x] Run `./godot/run.sh --headless --script tests/test_terrain.gd`; expect exit 0.

### Task 2: Scene, shading and verification

**Files:** Modify `godot/game.gd`, `godot/field.gdshader`, README and validation notes; create `godot/water.gdshader`, `godot/tests/test_terrain_scene.gd`, `godot/tests/capture_terrain.gd`.

- [x] Write/run a failing scene check for a larger terrain mesh and water below the playable area.
- [x] Replace the plane with generated geometry, derive field texture coordinates from position, shade banks/slopes, and add gently animated opaque water.
- [x] Keep camera panning within the existing flat clearing; widen the opening view to show the surrounding landscape.
- [x] Run both terrain tests and all nine existing suites; inspect actual renderer captures of multiple seeds, rotation, close camp, snow and minimum window size.
- [x] Obtain an independent scoped code review and address material findings. Record actual validation and leave edits available in the current working tree.

Validation: all 11 suites passed with exit 0. Terrain model checks cover 30 seeds;
scene checks cover 30 opening lake projections and 96 camera edge/zoom/heading
combinations. GPU captures were inspected on Apple M4 / Compatibility. Visual
iteration softened the original crater banks and broad rock patches. Lake
placement uses the two sides beyond the opening view rather than changing the
established camera heading. No material findings remained in independent review.

Work in the supplied checkout to integrate with its existing uncommitted character creation; preserve those edits. No commit or PR requested.
