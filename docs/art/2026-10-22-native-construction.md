# Native construction art — 2026-10-22

Nine PNG assets were generated with the built-in OpenAI image-generation tool for the native macOS strategy/construction iteration. The existing `public/art/props.png` was supplied as a style, materials, lighting and perspective reference, not edited or replaced.

Assets in `native/macos/Sources/RazesMac/Resources/Art/`:

- `woodshed-construction.png`: timber framework, partial roof and loose planks.
- `woodshed-complete.png`: open-front timber shed with stacked firewood.
- `woodshed-winter.png`: corresponding snowy woodshed.
- `cellar-construction.png`: excavation, shoring and incomplete stone entrance.
- `cellar-complete.png`: low earth-covered cellar with stone entrance and timber doors.
- `cellar-winter.png`: snowy cellar treatment.
- `terrain-grass.png`, `terrain-earth.png` and `terrain-snow.png`: overhead repeating material textures, generated on 2026-10-23, projected onto reusable diamond tiles beneath separate structures and people.

All nine assets are 1254 by 1254. The six building PNGs have transparency spanning 0–255; the material textures are opaque. Original generated pixels are retained. SpriteKit texture windows exclude large transparent margins, preserving aspect ratio and anchoring the visible base to the ground. Existing cottage, barn, well and figure atlases remain untouched.

The earlier single-image ground experiments are excluded from the app. The images were inspected for transparent silhouettes, distinct construction stages and consistency with the painted homestead. Independently generated seasonal variants differ slightly in details; these are illustrative game assets, not historically certified reconstruction or frame-by-frame animation. Small construction dust/tool effects are rendered in SpriteKit. No walking animation is claimed.
