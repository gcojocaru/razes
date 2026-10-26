# Farmer model

`peasant.glb` is assembled by `build_peasant.py` (Blender 5.2). It has two sources:

| Part | Source | Licence |
| --- | --- | --- |
| Bald, bare, barefoot body (`Skin`) with its normal map | A figure generated from a prompt with [Tripo](https://www.tripo3d.ai), on a paid plan, which grants commercial rights to the outputs | Tripo paid-plan terms; the file is kept outside the repo |
| Skeleton (`Peasant`) and the eight clips `Idle_Loop`, `Walk_Loop`, `Fixing_Kneeling`, `Death01`, `Farm_PlantSeed`, `Farm_Harvest`, `TreeChopping_Loop`, `LayToIdle` | [Quaternius](https://quaternius.com) Universal Base Characters and Universal Animation Library packs, kept from the previous `peasant.glb` | CC0 1.0 |

The script fits the figure to the Quaternius skeleton rather than the other way
round, so the animations play unchanged:

- **Scale:** the skeleton was made for a 1.85 m model, so the body is scaled until
  the joints of its own (Tripo, Mixamo-named) skeleton match the heights of the
  Quaternius joints. It comes out 1.833 m tall, which `human_actor.gd` records as
  `MODEL_HEIGHT` and shrinks to the peasant's height in the game.
- **Weights:** Blender's automatic (heat) weights, computed on a copy of the mesh
  welded along its UV seams and copied back to every vertex. The Tripo export
  weights almost every vertex to the hips, so its weights are not used.
- **Skin:** the generated texture is grey clay; it is tinted to the `Fair` skin
  tone of `human_actor.gd`, keeping 40% of its light and dark variation. The
  normal map is kept, at 2048 px like the colour.

The clothes are made by the script itself, so they are original work under the
project's own terms. They follow Moldovan peasant dress:

- **Shirt (`Shirt`, `Skirt`):** a long linen shirt (cămașă) hanging over the
  trousers to mid-thigh. The top is the skin of the torso and arms, copied, smoothed
  and lifted off the body, so it keeps the skin's weights. The skirt is a generated
  ring that flares out below the belt. It hangs from 16 chains of two bones
  (`skirt_00_a`/`_b` to `skirt_15_a`/`_b`), added to the skeleton and keyed into
  every clip. For each frame, each bone is turned as low as it can go, somewhere
  between moving with the hips and moving with its thigh, while staying clear of
  the legs and the ground. So when kneeling, the back hangs from the hips and the
  front lies on the thighs; when bending over, the cloth folds over the buttocks
  and hangs along the thighs.
- **Embroidery (`Collar`, `Cuff`, the skirt's hem):** strips along the shirt's edges
  with a generated red-and-black diamond border (`Embroidery` texture).
- **Belt (`Belt`):** a red woven brâu (`BeltWeave` texture).
- **Trousers (`Trousers`):** linen ițari, made from the leg skin like the shirt.
- **Opinci (`Opinci`, `Laces`):** leather sandals over the sole, sides and toes, with
  nojițe laces wound three times around each lower leg.

The skin under the shirt and trousers is removed, apart from two rings of faces
under the garment edges.

To rebuild, keep a copy of `peasant.glb` (the script reads the skeleton and clips
from it and overwrites it), then run:

    blender -b -P build_peasant.py -- <path to the figure GLB>

The model has no hair or facial hair yet.
