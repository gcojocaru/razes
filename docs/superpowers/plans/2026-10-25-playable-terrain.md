# Playable terrain implementation plan

**Goal:** Procedural hills and multiple ponds within the 16×16 playing field,
with farming on dry slopes and a farmer who walks around water.

**Scope:** Reuse Godot noise, meshes and AStar2D. Terrain is shared by the
farm model, farmer, renderer and picking. Keep only a compact dry camp clearing.
Travel keeps its existing horizontal distance/time rules. No save migrations,
dependencies, new resources, bridges or uphill effort system.

1. [x] Replace the flat centre with seeded hills and 2–3 separated field ponds.
   Match height sampling, rendered triangles and visible-surface ray hits. Check
   farm eligibility across each plot and dry-land reachability from camp.
2. [x] Reject unusable plots consistently in actions/previews/debug; cache land
   routes for all farmer travel and use those routes in sleep predictions.
   Verify reservations, cancellation, stale jobs and deterministic time steps.
3. [x] Ground actors/crops on terrain, pick hills and water correctly, and follow
   terrain with the camera while preserving existing input and camp access.
   Show explicit water/slope reasons and exclude unusable land from field counts.
4. [x] Run all suites with deterministic scene fixtures; add multi-seed terrain,
   movement, picking, grounding and camera checks. Inspect GPU views of farmed
   hills, ponds, a routed farmer, rotation, close camp and snow. Obtain independent
   code review, address material findings and record validation.

Ownership: terrain generator/model tests in one agent; Human/Farm/debug and
movement tests in another; game/render/UI/scene tests, documentation and final
verification with the parent. Keep existing character-creation edits intact.

Review fixes: forecast retained return routes; validate complete navigation
edges and direct shortcuts at heightfield triangle crossings; back the camera
away from steep ground at close zoom. Each defect received a failing regression
before its fix. Gameplay fixtures use seed 40 and pause before the first frame.

Final verification: all 12 headless suites exited 0; the terrain scene suite
also exited 0 with the native Compatibility renderer. Inspected three seeds,
farmed hills, water selection, walking beside a pond, camp, rotation, snow and
the minimum window size in `/tmp/stefan-playable-terrain/`. `git diff --check`
passed. No gameplay saves or migrations were added.
