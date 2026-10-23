# Fence, path and seasonal building artwork

Final assets in `native/macos/Sources/RazesMac/Resources/Art/`:

- `settlement-rear-v2.png` — 1448×1086 RGBA, twelve revised rear views. The original rear atlas remains as source history.
- `settlement-rear-winter.png` — matching twelve snowy rear views.
- `settlement-buildings-winter.png` — 1536×1024 RGBA, snowy front views of granary, workshop, bakery, smithy, stable and apiary.

Generated with the built-in image-generation tool. Existing front artwork, the previous rear atlas, woodshed and cellar art provided identity/material references. Inspection selected the final spaced summer atlas and a winter edit of that exact image. Earlier outputs with touching sprites were discarded. No original front/winter assets were overwritten.

The final summer prompt requested the exact twelve identities in four columns and three rows, preserved facing and natural proportions, aged wood/stone and existing architectural features, with transparent gutters and no labels, grid, terrain or extra buildings. In particular, the bakery retains shingles, the granary retains posts, and the stable retains thatch and its stall structure.

Final rear winter prompt: Add WINTER SNOW to the exact separated 12-sprite atlas; preserve canvas, pixel positions, orientation, widths, heights and identities. Change only seasonal surfaces: snow on roof planes and exposed ledges, white snow at bases, cool blue shadows. Coat existing surfaces rather than adding broad ground patches; preserve transparent gaps. Cover thatched/shingle roofs, well canopy, cellar mound, apiary roofs and cart rims. Keep exposed wood/stone and warm fire readable. No particles, grid, text, backdrop, haze or redesign.

Front winter prompt: Convert the exact six-building atlas to winter, preserving facing, architecture, roof materials, proportions, details, camera and painted style. Keep three columns/two rows: granary/workshop/bakery, smithy/stable/apiary. Add settled snow on roofs, chimney caps, beams, hive roofs, ledges, stones and bases; preserve warm forge/oven glows. Replace flowers/grass with snow. Genuine transparent alpha between isolated sprites; no connecting terrain, particles, labels, grid, watermark or redesign.

Alpha-component inspection confirmed twelve separate major sprites per rear atlas and six per front atlas. All eighteen summer/winter pairs increased light neutral snow coverage by over ten percentage points. `BuildingArtwork.swift` uses common seasonal crop bounds to retain anchors and scale, with boundaries between adjacent atlas columns to prevent neighboring pixels leaking into a sprite. This remains painted 2D directional artwork, not a reconstructed 3D model.

Dirt paths reuse the existing earth texture through the infrastructure tile projection, with winter snow blending. Wattle fences use seven alternating twig rows and five upright stakes; their top weave and stake caps collect snow. Placed fences and their previews share the same native SpriteKit composition. No new raster materials or dependencies were needed for these two styles.
