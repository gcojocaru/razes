# Fences, dirt paths and directional weather

Extend the native macOS settlement builder with the user's selected dirt path and woven wattle fence. Keep stone pavement and rail fences, their one-coin price, repeat painting, placement restrictions and eraser. Make fence edge rotation explicit in the placement controls and handle R when SpriteKit owns keyboard focus. Preview and committed facing must agree in all four map views.

Reuse the existing infrastructure renderer and save arrays: add dirt-path tiles and a style on fence segments. Shared-edge uniqueness applies across both fence styles; different surfaces cannot occupy one tile. Schema 6 migrates earlier saves with empty dirt paths and rail fences, preserving original bytes before replacement. Reject invalid styles, overlapping surfaces and protected/out-of-bounds placement.

Correct the rear atlas to match existing front architecture/materials and add painted winter variants for the rear atlas and the six buildings currently lacking winter art. Preserve consistent crop geometry per seasonal pair. House, scenery, buildings and placement ghosts select winter art in every facing; construction keeps its foundation art. Weather remains visual and respects reduced motion.

Use the existing SwiftUI/SpriteKit/SwiftPM architecture, macOS 14+, no new dependencies and no browser game changes. Reuse native terrain textures for dirt and native line composition for wattle. A procedural snow tint alone would miss roof accumulation; replacing all front artwork would unnecessarily change the established appearance.
