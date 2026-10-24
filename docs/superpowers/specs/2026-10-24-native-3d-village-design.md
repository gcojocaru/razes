# Răzeș: a cross-platform 3D village with unlockable land

Date: 2026-10-24
Status: First playable implementation completed in `godot/` after the user installed Godot and asked to continue. Mac rendering and automated checks are verified; desktop data packs are generated. Standalone binary exports, Windows/Linux execution and full accessibility validation remain unverified. See `godot/VALIDATION.md`. The parcel size/limit and price are initial Codex implementation choices.

## Intent

Buildings should have believable proportions, sit where their placement footprint says they sit, and remain coherent when the village rotates. The user requested real 3D and selected **stylized rural buildings with warm textures**. The user also requested unlocking more land beyond the current 16 × 16 area.

The proposal is a standalone Godot game for macOS, Windows and Linux, including the simulation changes required for land ownership and purchases. The existing native Swift and browser applications remain available as references while the port is developed. Their gameplay is not automatically changed by this project. The Swift native game is the reference for rules and behaviour; the browser game has separate rules and is not the parity target.

## What exists today

- `ContentView` embeds a SpriteKit `HomesteadScene` beneath a SwiftUI HUD.
- `Settlement` owns a 16 × 16 logical grid and placement validation. The house occupies 3 × 3 tiles; current buildable structures reserve 2 × 2 tiles.
- Most building images are set to 185 points wide, independent of their depicted ground area. Their bottom-centre anchors are placed at the logical footprint centre. Painted front/rear views have different crops and proportions.
- Map rotation reprojects positions and swaps or mirrors pictures. It does not rotate geometry.
- Selection, placement previews, infrastructure and worker locations use the same 2D projection, so replacing buildings alone with an unrelated 3D overlay would create another alignment problem.
- Resources contain PNG artwork, not 3D models. Existing gameplay includes construction, five upgrade levels, condition, seasons, crops and editable infrastructure; these must remain usable.

## Approaches

1. **Recalibrate the existing sprites.** Correct ground anchors and image scales together. This is smaller, but still gives four painted views rather than real 3D and does not satisfy the requested direction.
2. **Native RealityKit village.** Reuse the existing Swift simulation and SwiftUI controls. This would minimize the native-app rewrite, but RealityKit does not provide Windows/Linux targets, so it no longer meets the selected platform direction.
3. **Godot game engine — recommended.** Its 3D editor, scenes, asset import, grid tools, lighting and desktop export workflow fit ongoing village development across Mac, Windows and Linux. It adds a toolchain and requires porting the Swift gameplay and SwiftUI interface. Use typed GDScript and Godot Controls rather than introducing a Swift engine bridge. Swift bindings are community maintained rather than officially supported by Godot. A larger map alone does not require changing engines; the combined 3D and platform goals justify the proposal.

The user chose to build toward Windows/Linux too. Godot is Codex's recommendation based on that choice. The engine does not supply land-purchase rules or correctly proportioned building assets automatically. Approval of this final proposal confirms the engine port and implementation scope.

Relevant primary documentation: [RealityKit](https://developer.apple.com/documentation/realitykit), [Godot GridMaps](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html), [Godot language support](https://docs.godotengine.org/en/stable/tutorials/scripting/other_languages.html).

## Visual direction

The village should resemble a small rural Moldovan household: warm limewashed plaster, visible timber, stone foundations, brown shingle or thatch roofs, simple chimneys, inset dark doors and restrained window light. Buildings should have distinct silhouettes and useful details on all sides. Avoid plastic, glossy surfaces and identical boxes differentiated only by colour.

Use simple authored-in-code meshes for this first implementation. Common structural pieces may share mesh and material resources, but each building type must have a recognizable composition. Do not install an asset-generation pipeline or introduce paid asset dependencies.

Warm wood, plaster, roofing and stone require visible surface detail, using small deterministic material textures created in code and repeated structural detail. Existing ground textures may be reused. Plain flat colours alone are insufficient for the selected textured direction. These are game models, not a claim of production-quality hand-authored 3D assets.

## Coordinate and scale contract

- The logical grid remains authoritative. One tile represents 2 metres on the X/Z ground plane; Y is height. The starting parcel's centre is the fixed world origin. Purchasing land never recentres existing structures or changes their saved coordinates.
- A placement identifies its minimum indexed tile, whose coordinates describe that tile's centre. Tile `(column, row)` maps to `((column - 7.5) * 2, 0, (row - 7.5) * 2)` metres. A model root uses `column = position.x + (width - 1) / 2` and the equivalent row formula, placing it at the centre of the complete reserved footprint at ground height. Every geometry part is positioned relative to that root.
- Wall bases, posts and foundations meet ground height. Decorative overhangs may extend slightly beyond walls, but roofs and annexes must stay within the reserved footprint. Models cannot acquire new occupancy rules independently of `Settlement`.
- The house fits its existing 6 × 6 metre reservation. Other buildings fit their existing 4 × 4 metre reservations, with smaller structures occupying visibly less of the reserved plot. A well should be substantially smaller than a barn.
- Ion is approximately 1.7 metres tall. Doors, storeys, fences and work props derive their proportions from that reference.
- Rotation turns the model around its ground-centred root in quarter turns. No mirroring or alternate front/rear geometry is needed.
- The placement ghost and completed structure use the same model, transform and root. Selection outlines show the actual reserved ground rectangle.

## Unlockable land

The following parcel size, limit and purchasing details are proposals by Codex, not choices already made by the user:

- Start with the current 16 × 16 parcel fully owned. Unlock adjoining 16 × 16 parcels with Galbeni; do not add a currency, a real-time wait, or a separate progression system.
- For the first version, use a finite 3 × 3 arrangement of parcels with the original parcel in the centre: up to 48 × 48 tiles. This is a bounded map, not an infinite procedural world. The outer parcels cover logical coordinates -16 through 31 on each axis, preserving the original 0 through 15 coordinates.
- Offer only parcels sharing an edge with owned land. Diagonal-only purchases cannot create disconnected islands. Show the parcel outline, area and exact price before purchase. Keep locked land visually distinct but visible enough to understand the available expansion.
- A single land price belongs beside the existing balance values; select its initial value against current building costs and early income during implementation. No new pricing configuration or escalating formula is needed. Display the actual price and affordability in the UI.
- Purchase atomically checks valid parcel, adjacency, not already owned, the current action/terminal-state policy, and spendable Galbeni after existing reservations. Charge once and save the new ownership in the same state update. A rejected or duplicate purchase changes neither money nor land.
- Validate every cell of a structure's footprint against owned land. Buildings may straddle two owned parcels, but cannot cross into a locked parcel even if their centre is owned. Roads, farmland, scenery, fences and erase operations must use the same ownership boundary.
- Ownership is simulation state, independent of the renderer. Store owned parcel identifiers in the save and validate uniqueness, inclusion of the starter parcel, allowed range and connectedness. Coordinate-to-parcel mapping must use floor division for negative tile indices, not integer truncation toward zero.
- Camera bounds, terrain coverage, ground hit testing, placement searches and surface/fence save limits must use the available/owned map extents rather than fixed 16 × 16 constants. The camera must be able to inspect purchasable neighbouring land. Keep its target stable after a purchase and extend terrain without rebuilding unchanged buildings.
- Provide an accessible Land command and purchase controls through Godot Controls as well as clickable map parcels. Keyboard users need a way to inspect and purchase every eligible parcel.
- Land expansion does not change the existing one-structure-per-building-type rule or make crop yield scale with farmland area. Those would be separate gameplay changes. Additional land initially provides room for layout, fields, paths, fences and scenery.

Include ownership in the new Godot save format from its first version. Do not change the Swift app's save schema to support the port. Future Godot save-schema changes may require a fresh settlement; reject unsupported versions clearly and do not add migration or compatibility code. State plainly in the port's documentation that existing native/browser development saves are not imported.

## Engine, camera and interface

Create one Godot project under `godot/` using a current stable Godot 4 release, pinned consistently with its export templates. Use typed GDScript and the Compatibility renderer for this modest 3D scene and broad desktop hardware support. Avoid features requiring Forward+; verify the intended lighting and materials in the selected renderer. Do not introduce a separate engine integration SDK or community Swift bindings.

Use an elevated orthographic `Camera3D`: buildings remain equally sized throughout the map, while meshes, lighting and occlusion provide real depth. Preserve macOS 14 as the initial Mac target where supported by the selected engine release. Include Windows and Linux export presets; record their actual validation status separately from export generation.

Preserve pan, bounded zoom, Home/reset, the existing quarter-turn map controls, building rotation and R during placement. Do not add free camera tilt or first-person navigation. Rotate the camera around the village for map rotation, while keeping model facing in world coordinates.

Use a camera ray intersecting the shared ground plane to obtain placement grid coordinates, and collision hit tests for selecting structures and Ion. Port the current selection/placement concepts and settlement/infrastructure validation to GDScript. Ignore preview geometry during hit tests. Resolve click versus drag before committing placement, and preserve drag-to-paint deduplication.

Recreate the current HUD, inspectors, construction/material commands, weekly review, recovery/fresh-start flow and Places equivalents using Godot Controls. Keep the warm visual theme and familiar actions rather than redesigning the gameplay flow during the port. Use one authoritative game state. Keyboard navigation, meaningful focus order, readable text scaling, motion preferences, modal input blocking and terminal-state guards remain required. Validate the engine's screen-reader support on the actual target systems before claiming equivalent accessibility.

## Gameplay port and local saves

Port the existing native simulation and its content values before changing land rules: Ion's character/skills, weekly assignments, material inventory/crafting, food/shelter survival, seasons/calendar, crop stages, construction requirements/progress, five building levels, repairs/condition and production. Follow current native behaviour, including guards and reservation calculations, rather than reconstructing rules from older prose or the independent browser implementation.

Keep rules independent of Godot scene nodes so headless checks can exercise them. Preserve the existing conceptual boundaries without creating a generic engine abstraction, RPC layer, or runtime Swift dependency. Use representative native state/action/result fixtures and port the native rule tests needed to show equivalent behaviour, then add land-specific checks. Do not silently remove game actions to finish the visual port sooner.

Use a strict versioned local save with bounded validation and safe write/recovery handling appropriate to the engine's per-user data directory. Save the complete gameplay state, including land ownership. A corrupt or unsupported save must offer a useful fresh-start/recovery flow without crashing. Do not load or overwrite the existing Swift app's save. No import, migration or compatibility code is required; the Godot game starts a fresh household.

## Complete map scope

- Use one Godot 3D map in the new game. Do not add a selectable SpriteKit renderer, a 2D/3D mode switch or a native-app embedding layer.
- Model the house and all current `BuildingID` cases, including the storehouse, plus existing barn/well/stores/fence scenery.
- Keep terrain, farmland, crop stages, dirt paths, pavement and both fence styles visible and editable. Ground surfaces must not flicker from coincident geometry.
- Represent Ion with a small stylized 3D figure and relevant task props. Preserve task locations and selection. Pathfinding and walking animation are outside scope.
- Show foundations and construction progress. Each upgrade level must produce a visible structural or detail change, including house upgrades. Show condition through restrained wear/material changes and retain numeric details in the inspector.
- Winter changes ground and roof appearance; the four season previews remain useful. Use a common warm light direction, real depth occlusion and shadows. Provide gentle ambient fill so rear walls remain readable.
- Preserve reduced-motion handling. Avoid adding a weather or animation system just to match existing particles; use a restrained seasonal scene and preserve any effects only where needed for existing status feedback.
- Existing painted catalogue/inspector thumbnails may be reused in the Godot UI for this pass. They are illustrations; model-based thumbnail generation is outside scope. Preserve artwork/font attribution and document this limitation.
- Leave the current native/browser projects and tests intact while developing and validating the new game. Do not rewrite or remove those applications as an incidental part of the port.

## Error handling and performance

Cache shared meshes and materials. Keep entities stable when unrelated gameplay values or selection change. Update affected entities when levels, condition, placement, seasons or infrastructure change; do not rebuild the village on every HUD refresh.

Missing optional material textures may use an appropriate matte fallback rather than crash. If the selected engine renderer cannot initialize, report the failure accurately and avoid claiming the game supports that system. Do not introduce a custom renderer fallback or general rendering abstraction.

Pause nonessential animation while inactive. Keep geometry modest enough for the existing 30 FPS target; profile only if visual checks reveal a problem. Actual minimum-OS and Intel performance remain unverified unless tested on those systems.

## Reach of the implementation

Expected changes are a new Godot project, gameplay/content port, model/material generation, terrain/camera/input, Godot UI, local save handling, land ownership/purchases, headless tests and desktop export presets. Existing `SettlementLayout`, placement validation/search, `GameSession`, save validation and reservation handling identify behaviour to port; these Swift files need not be changed to add the Godot game.

Use native tests as a behaviour reference and preserve them. Add Godot checks for simulation parity, selection, camera, placement, infrastructure, crops and land purchases. Document exact run/test/export commands in `godot/README.md` and the root README, and keep a Godot validation report that distinguishes completed checks from unverified hardware, platforms and visual behaviour.

Apart from land purchase costs and the ownership state, do not alter gameplay economy, construction requirements, calendar rules, the starting layout or building occupancy. No save migrations or compatibility machinery are required. Preserve unrelated checkout changes.

## Verification and acceptance

1. Import, run and headless-test the Godot project with the pinned engine release. Check representative simulation outcomes against the native reference and run existing native tests if reference fixture generation changes their code. Generate desktop exports where templates are available; run the Mac export and record Windows/Linux execution as unverified unless actually tested there. Do not claim distribution signing or notarization unless performed.
2. Verify grid-to-world and inverse mapping, every footprint centre, all four facings and map rotations, and bounded camera operations. Check that rotated model bounds stay in their reserved plots.
3. Test placement ghosts and committed structures at the same grid positions, blocked placement, map-edge placement, selecting a roof/wall, selecting Ion, cancel, R rotation and click-versus-pan/paint behaviour.
4. Check every building type, all five levels, foundation progress, damaged appearance, season changes and farmland/crop/infrastructure updates. Confirm unrelated state changes do not grow entity counts or recreate models.
5. Capture actual renderer output at useful zoom levels, including adjacent house, well, barn and Ion, front and rear views, winter, and valid/invalid placement. Check ground contact, relative size, shadowing and readable silhouettes visually. A compiling scene alone is not visual acceptance.
6. Verify keyboard/Places access, Reduce Motion and sheet interaction. Record any inability to inspect the running UI accurately; screen capture failed during initial investigation.
7. Test starter ownership, edge-adjacent unlocks on every side, negative coordinates, insufficient/reserved money, duplicate and disconnected purchases, terminal-state rejection, and save round trips/corrupt ownership rejection. Check placement across an owned parcel seam and rejection across a locked seam; test all infrastructure on expanded land. Verify camera access to purchasable land, stable existing transforms after purchase, and useful zoom at the maximum proposed 48 × 48 size.

## Explicitly deferred

Photorealism, external model tooling, model-based catalogue thumbnails, walking/pathfinding, free camera tilt, web/mobile exports, gameplay changes beyond land purchases, physics simulation, infinite terrain, Swift/engine bridging, save compatibility layers and removal of the reference apps.

The main risks are gameplay parity during the port and visual quality: simple procedural models can look generic. Use the native rules as evidence, judge the actual rendered village before calling its appearance finished, and record platform, accessibility and artwork limitations honestly.
