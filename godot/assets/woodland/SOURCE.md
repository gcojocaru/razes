# Woodland assets — 26 October 2026

`ash_0.glb` and `ash_1.glb` are static exports authored with Daniel Greenheck's [EZ-Tree](https://github.com/dgreenheck/ez-tree), version 1.1.0, Ash Medium preset, seeds 1523 and 9821, heights 7.5 and 9 m. `build_trees.mjs` reproduces the meshes from a built EZ-Tree checkout; it asserts the triangle budget. The game bundles the GLBs and needs no JavaScript, npm or network.

- EZ-Tree generator and `ash.png` foliage texture: MIT; included `EZ-TREE-LICENSE.txt` and upstream texture provenance.
- `bark.jpg`: ambientCG [Bark001](https://ambientcg.com/view?id=Bark001), CC0 1.0, 1K color map. Source is EZ-Tree's ambientCG texture collection, documented in `TEXTURES-LICENSE.md`.
- Axe, logs, stumps and timber shelter are original game meshes. Shelter appearance is inspired by the Romanian [Feneș pastoral hut museum record](https://monumente-etnografice.cimec.ro/muzee-in-aer-liber.asp?ID=3F67C633868A46299585DCDEE8643121), not a verified medieval reconstruction. No reference photographs are bundled.
