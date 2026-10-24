# Upgraded house artwork — 2026-10-24

Eight transparent PNG sprites, generated with the built-in image_gen tool. Source props.png and settlement-rear-v2.png were visually inspected before use as style references. Existing artwork was retained. No CLI/API fallback, image processing or generated placeholder graphics were used. Generated source files were copied unchanged into the project's Resources/Art directory; alpha is preserved.

Level 1 retains its original front/rear rendering. Levels 2–5 share the new timber-porch, lime-plaster and stone-foundation house. Summer applies to spring/summer/autumn; winter adds painted snow. Condition below 65 selects damage, matching Presentation. Front and rear each have four independent painted states; horizontal runtime mirroring supplies all four map rotations. The node retains 240-point width, bottom-center anchor and settlement footprint. These are painterly 2D facades, not a reconstructed 3D model.

Map texture loading uses the existing scene cache. Catalogue images load/crop the same source frame definitions directly through AppKit because SKTexture.cgImage can be blank without a renderer, and cache the resulting NSImages. No scene nodes are added for the upgrade.

## Assets and provenance

- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-front-summer-intact.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-c0f40df7-7c97-4983-bae1-f232f7fdaf4a.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-front-summer-damaged.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-885186af-7262-4097-8590-1ddbacbe5b93.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-front-winter-intact.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-9d9f982c-c48e-4ef8-b248-0f15c084decb.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-rear-summer-intact.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-95f3df4d-01c1-4969-91c7-2d8b431ed7f9.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-front-winter-damaged.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-00a6e228-607e-495b-afc2-d1f2752630f7.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-rear-summer-damaged.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-27a87168-84ae-4f5f-924f-34ea99493dcf.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-rear-winter-intact.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-55446cff-6bc6-442f-99e4-b58299361a0d.png`
- `native/macos/Sources/RazesMac/Resources/Art/house-upgraded-rear-winter-damaged.png`
  - Built-in original: `/Users/gheorghecojocaru/.codex/generated_images/01a16b04-8b32-70f1-9387-71dd11949d6a/exec-9cc87fa7-8bf9-4ffc-b8a3-c14e56f681bc.png`

## Generation prompts

### Front summer intact

```
Use case: stylized-concept
Asset type: transparent isometric building sprite for the Razes macOS settlement strategy game.
Input images: Image 1 props.png and Image 2 settlement-rear-v2.png are STYLE REFERENCES only. Match their warm painterly realistic miniature game-building style, materials, camera elevation and light.
Primary request: Draw ONE upgraded level-2 Moldovan rural cottage, front three-quarter view, summer, fully intact. A modest white lime-plaster home with golden thatch gabled roof, chimney, clearly improved sturdy low rough-stone foundation, dark timber framing, and a small covered timber porch around the front doorway. The porch must visibly distinguish this upgraded house from the simple reference cottage. The left side and front facade are visible, front door on right-facing wall; near foundation corner points toward bottom center. Same compact rectangular house footprint as reference, no second floor.
Scene/backdrop: genuinely transparent alpha background, isolated sprite, no terrain patch, no backdrop, no surrounding objects or characters.
Composition/framing: one centered whole house, isometric orthographic view from above at about 30 degrees, all roof/chimney/foundation/porch fully visible with clear transparent margin on every side, no clipping. House fills approximately 85% of image width. Ground-contact foundation centered horizontally, house base stays level.
Lighting: soft warm light from upper left, restrained contact shadow only.
Materials: textured plaster, timber beams, individual rough foundation stones, layered golden thatch. Detailed hand-painted game art coherent with references; no outlines, no pixels.
Constraints: one house only; no text, no watermark, no label, no border, no scene or grass carpet. Summer intact state only.
```

### front-summer-damaged

Reference: front-summer-intact.

```
Use case: precise-object-edit
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change only condition: this same front summer house now needs repairs. Show several localized holes/missing thatch areas exposing dark roof battens, cracks and small missing patches of plaster, slightly worn porch rails. Keep structurally upright and recognizably the identical house. No collapsed walls or rubble spilling outward.
Invariants: preserve the house identity, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for easy matching across gameplay states.
```

### front-winter-intact

Reference: front-summer-intact.

```
Use case: lighting-weather
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change only season to winter: natural white snow resting on the existing thatch roof, porch roof, foundation ledges, chimney cap, and steps. Maintain visible roof detail and plaster/timber. Fully intact.
Invariants: preserve the house identity, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for easy matching across gameplay states.
```

### rear-summer-intact

Reference: front-summer-intact.

```
Use case: precise-object-edit
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Show this IDENTICAL house from the opposite rear three-quarter view, 180 degrees around its foundation. Rear exterior has white lime plaster, timber framing and a modest wooden-framed small rear window; no front porch visible, the porch is around the far unseen front. Chimney at the opposite roof end because camera rotated. Same height, thatch roof, stone foundation, compact footprint, material quality, orthographic camera elevation, and lighting style. Summer intact.
Invariants: preserve the house identity, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for easy matching across gameplay states.
```

### front-winter-damaged

Reference: front-summer-damaged.

```
Use case: lighting-weather
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change only season to winter: natural white snow on existing thatch and porch roofs, chimney cap, foundation ledges and steps. Keep the existing damage clearly readable: roof holes expose dark battens beneath, plaster cracks and missing patches stay visible. Keep snow away from holes enough to show worn condition.
Invariants: preserve house identity, exact front/rear camera view, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for matching across gameplay states.
```

### rear-summer-damaged

Reference: rear-summer-intact.

```
Use case: precise-object-edit
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change only condition: this identical rear summer house now needs repair. Several localized thatch holes expose dark roof battens, and cracked plaster has small missing patches. Keep upright with identical foundation, outline, rear window and timber framing. No rubble extending outside footprint.
Invariants: preserve house identity, exact front/rear camera view, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for matching across gameplay states.
```

### rear-winter-intact

Reference: rear-summer-intact.

```
Use case: lighting-weather
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change only season to winter: natural white snow rests on the existing thatch roof, chimney cap, window ledge and foundation ledges. Fully intact. Keep the exact rear view and house identity.
Invariants: preserve house identity, exact front/rear camera view, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for matching across gameplay states.
```

### rear-winter-damaged

Reference: rear-summer-intact.

```
Use case: precise-object-edit
Asset type: transparent isometric building game sprite.
Edit target: attached house image. Change this identical rear house to damaged winter state: several localized thatch holes exposing dark roof battens, cracked plaster with small missing patches, natural white snow on the intact thatch roof areas, chimney cap, window ledges and foundation ledges. Damage must be clearly visible despite snow. Keep upright with identical foundation, outline, rear window and timber framing. No rubble extending beyond footprint.
Invariants: preserve house identity, exact front/rear camera view, scale, compact rectangular footprint, painterly detailed miniature-game art, materials, single-story height and chimney, camera elevation. Preserve genuinely transparent background and clear margins. One isolated whole building only, no ground patch, scenery, people, text, labels, watermark or borders. Base foundation contact centered horizontally. Maintain source image framing and object width for matching across gameplay states.
```

## Validation

All eight generated images were visually inspected for transparent background, uncut silhouette, matching house identity, porch differentiation, rear view, readable damage and snow. HouseArtworkTests checks level-1/2 texture distinction, every rotation/season/condition, level-3–5 reuse, stable node/anchor/width and load warnings, and catalogue images with visible center pixels without a SpriteKit renderer.
