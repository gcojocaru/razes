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
  normal map is kept. Both stay at their full 4096 px, because the face gets only
  about 2% of the texture.

The clothes are made by the script itself, so they are original work under the
project's own terms. They follow Moldovan peasant dress. Each is its own mesh on
the skeleton, and `human_actor.gd` shows the ones the peasant chose (`CLOTHES`,
`WORN`).

Most garments are tubes of rings. Each ring is the body's convex outline at that
point plus room for the cloth to hang loose, so the cloth doesn't follow every
muscle. The garments take their weights from the nearest body points, and their
texture coordinates run around and along each tube. Their textures are generated:
`Linen` is a plain weave of uneven threads, with a normal map; `Embroidery` is a
red-and-black diamond border.

- **Shirt (`Shirt`):** a long linen shirt (cămașă). The body runs from under the
  belt to a stand-up collar. Down the front, the cloth is stretched straight over
  the chest's high points, so the hollows between muscles don't show, and it is
  gathered into folds under the belt. It has embroidered stripes down the chest, an
  embroidered collar, and sleeves that widen to the forearm and gather above
  embroidered cuffs, with the altiță band below the shoulder. The sleeves begin
  inside the body, so the two always overlap when the arms move. **Plain** draws
  the linen where the embroidery would be.
- **Skirt (`Skirt`):** the shirt below the belt, to mid-thigh, with folds that
  deepen towards an embroidered hem. It hangs from 16 chains of two bones
  (`skirt_00_a`/`_b` to `skirt_15_a`/`_b`), added to the skeleton and keyed into
  every clip. For each frame, each bone is turned as low as it can go, somewhere
  between moving with the hips and moving with its thigh, while staying clear of
  the legs and the ground. So when kneeling, the back hangs from the hips and the
  front lies on the thighs; when bending over, the cloth folds over the buttocks
  and hangs along the thighs.
- **Belts (`Belt`, `Chimir`):** the red woven brâu (`BeltWeave`), or the chimir: the
  same band in leather stitched along both edges, with brass studs (`Chimir`).
- **Trousers (`Trousers`):** linen ițari, a leg each from under the belt to the
  ankle, loose over the thigh and gathered into rings of folds down the calf.
- **Opinci (`Opinci`, `Laces`):** leather sandals over the sole, sides and toes,
  with nojițe laces wound three times around each lower leg. **Barefoot** takes
  both off; the feet stay under them.
- **Hats (`Cusma`, `Palarie`):** a tall cușmă of curled lambskin (`Fleece`), or a
  black felt pălărie (`Felt`) with a brim and an embroidered band. Both sit on the
  head at the hairline, with room for hair under them, and follow the head bone.

Hair and facial hair are chosen the same way, and tinted in the game to the
chosen hair colour. Their `Hair` texture is near-white strands with a normal map.
Where they sit comes from heights measured on this figure's face in its rest
pose (hairline, ears, nostrils, mouth and chin, below the top of the head), so a
different figure needs them measured again.

- **Hair (`HairCropped`, `HairBowl`, `HairLong`):** rings round the head from its
  highest point down, open for the face and kept clear of the scalp. Cropped hair
  is close to the head, leaving the ears and forehead bare. The bowl cut is
  thicker and cut straight round at the brows. Long hair (plete) covers the ears
  and falls straight from the head's widest point to the neck, longer at the back
  than beside the face.
- **Facial hair (`Moustache`, `Beard`):** the skin of the upper lip, and of the
  jaw, chin and cheeks leaving the lips, subdivided, lifted off the face and
  thickened. The moustache droops at its ends, and the beard thickens towards the
  chin. A beard is always worn with the moustache.

The skin under the shirt and trousers is removed, apart from two rings of faces
under the garment edges.

To rebuild, keep a copy of `peasant.glb` (the script reads the skeleton and clips
from it and overwrites it), then run:

    blender -b -P build_peasant.py -- <path to the figure GLB>

