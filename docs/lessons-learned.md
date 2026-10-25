# Lessons carried into Ștefan

These lessons come from the previous implementations and validation notes.
Their mechanics, values and technology choices are references, not a new product specification.

## Scope and gameplay

- Build one coherent playable loop before adding systems or maintaining multiple ports.
- Keep the map readable and commands discoverable. Explain unavailable actions and show costs, prerequisites and consequences before confirmation.
- Prototype economy and progression with deterministic full-loop checks, then playtest with people. Automated survival and resource balance do not demonstrate enjoyment or good pacing.
- Calendar, crop yield, land area, crafting, capacity and resource reservations must agree. A larger painted field must not imply a larger yield unless the rules implement it.
- This is unreleased software: save schemas may reset progress. Do not add migrations or compatibility layers unless requested.

## Simulation and persistence

- Keep one authoritative state and deterministic rules separate from rendering. Forecasts and committed outcomes should use the same calculations.
- Reserve assigned resources consistently; failed commands must leave state unchanged.
- Validate untrusted saves and commands before arithmetic, allocation or occupancy calculation. Bound coordinates, sizes, identifiers, quantities and progression combinations.
- Write saves safely and report failures without discarding live state. Corrupt-save recovery must preserve useful bytes and offer a reachable fresh start.
- Use isolated save locations for tests and debug captures. Debug commands must preserve ordinary state invariants.

## Rendering and interaction

- Pick a shared physical scale for people, buildings and terrain. Check ground contact, silhouettes, rear views and every rotation in actual renderer output.
- Placement previews, committed transforms, rotated footprints and picking must agree. Distinguish clicks from camera drags and deduplicate painted cells.
- Cache meshes, materials and textures. Keep entities stable when unrelated HUD values change; instance repeated decoration and clear it from occupied land.
- Geometry and screenshots matter more than promising procedural detail. Inspect useful play zoom, close views, winter, damage and construction variants.
- Keep keyboard alternatives to map targets, useful focus order, readable text, modal input blocking and reduced motion. Test screen readers on real platforms before claiming accessibility.

## Technology and validation

- Previous paths were TypeScript/Phaser, SwiftUI/SpriteKit and Godot/GDScript. Their settings survive only as reference; no engine has been selected for this fresh start.
- The Godot prototype used the Compatibility renderer and matching engine/export-template versions. Export generation alone did not prove Windows/Linux execution or distribution readiness.
- Test rules and malformed input headlessly; verify appearance with actual GPU captures and interaction in the running app.
- Separate completed evidence from unverified hardware, minimum OS, accessibility, signing/notarization and player balance. Previous test counts do not validate Ștefan.
- Avoid parallel test runs that write into the same screenshot or report directory.

## Historical and art research

- The previous setting used a fictional village in northern Moldavia in 1495. A later vernacular museum or elite artifact does not prove ordinary fifteenth-century rural life.
- Keep source dates, locality, social context, reproduction rights and invented details explicit. Generated art is illustration, not historical evidence.
- Buildings, clothing, tools, crops and historical prices still need dated specialist evidence. Retain the linked research and its uncertainty rather than inheriting old claims as facts.
