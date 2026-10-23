# Painted settlement building atlas — 2026-10-23

Generated with the built-in image-generation tool, using the existing woodshed as a style reference. No existing artwork was replaced.

Final asset: `native/macos/Sources/RazesMac/Resources/Art/settlement-buildings.png`, 1536×1024 RGBA. Alpha is present (705532 fully transparent pixels). SpriteKit crops six frames at runtime: granary, workshop, bakery, smithy, stable and apiary. The existing props atlas supplies barn and well; the existing woodshed/cellar assets remain. Level storage add-ons reuse the props atlas. UI, level badges, wear and timer bars remain independent layers.

Prompt: Create one 3-column by 2-row transparent game sprite atlas, matching the painted 15th-century Moldavian woodshed reference. Top row: raised timber granary with ladder and sacks; carpenter workshop with bench and tools; plaster bakery with bread oven. Bottom row: stone blacksmith forge and anvil; wooden horse stable with hay; cluster of six woven and wooden beehives. Consistent three-quarter isometric camera, warm upper-left sunlight, aged wood, straw/shingles, stone foundations; fully isolated structures with transparent margins. No people, ground tiles, text, logos, grid, UI, modern objects, flat vectors or low-poly style.

The generated images are visual game assets, not historical certification. New atlas buildings share one painted base per type across their five gameplay levels; incremental storage layers, status and wear indicate progression. Separate full painted architecture for every level and new winter variants are outside this pass.

The original full prompt also specified a 1536×1024 canvas, exact 512×512 cells, 30-pixel transparent margins, centered structures and ground contact at cell y=460. The generated layout was inspected and individual crop frames adjusted in SpriteKit without changing the PNG.
