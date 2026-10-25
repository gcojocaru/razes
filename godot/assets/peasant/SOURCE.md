# Farmer model

`peasant.glb` is assembled by `build_peasant.py` (Blender 5.2) from four packs by
[Quaternius](https://quaternius.com), all released under **CC0 1.0** (public
domain dedication); no attribution is required, but it is recorded here.
Standard (free) versions, retrieved from itch.io on 25 October 2026.

| Part | Pack |
| --- | --- |
| Tunic, sleeves, hands, trousers and boots (`Male_Peasant`) | [Modular Character Outfits – Fantasy](https://quaternius.itch.io/modular-character-outfits-fantasy) |
| Head, eyes, eyebrows, `Hair_SimpleParted`, `Hair_Beard` | [Universal Base Characters](https://quaternius.itch.io/universal-base-characters) |
| `Idle`, `Walk`, `Fixing_Kneeling`, `Death01` | [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) |
| `Farm_PlantSeed`, `Farm_Harvest`, `TreeChopping`, `LayToIdle` | [Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2) |

The script keeps only the head and neck of the base body, which the outfit's
collar covers, swaps its skin to the light texture so the game can tint it,
splits the upper lip off the beard as a separate moustache, keeps the eight
clips above, and shrinks the textures to 1024 px. To rebuild, unzip the four
packs into one folder and run:

    blender -b -P build_peasant.py -- <that folder>

The `peasant_T_*.jpg` files are the textures Godot extracts from the GLB on
import. The outfit is a generic fantasy peasant, not a reconstruction of
fifteenth-century Moldavian dress.
