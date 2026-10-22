# Painterly presentation pass

The user selected “Richer painterly visuals and animation” as the next priority. Implement the visual pass in the existing checkout, preserving the deterministic rules, UI controls, and save format.

## Design

Use generated hand-painted storybook assets as separate runtime layers: four matching empty landscapes; intact/damaged cottages, barn, well, provisions and fence; six field stages; five household/visitor figures and matching portraits. Use the same composition, camera and palette across variants. Winter props have actual snow cover. Assets are bundled locally with no runtime service or account dependency.

Keep the renderer responsible only for presentation. Derive field/roof/supply/visitor state in a small pure module. Show the actual visitor who is speaking, including Dumitru during the autumn consequence. Retain equivalent HTML controls for every essential action. Update scene labels to fit the painted composition.

Use reusable task-specific tools and work motions, subtle breathing, chimney smoke, spring blossom/light rain, summer motes, autumn leaves and winter snow. Motion reduction freezes all optional movement; it must not affect rules or suppress state changes. Avoid rebuilding particles/tweens when a journal or sound control redraws the interface.

## Acceptance and steps

- [x] Add regressions for field/roof/supply changes and correct visitor identity without mutating state.
- [x] Integrate bundled landscape and sprite atlases; inspect transparent edges, frame boundaries, scale, perspective and portrait crops.
- [x] Add task-specific motions and seasonal effects, with an actual static-canvas check under reduced motion.
- [x] Exercise complete years, save/resume and the six scene states; inspect laptop/desktop screenshots.
- [x] Document asset sources and update the preview image and run instructions.

## Limits

The fictional medieval-inspired assets do not establish an exact historical period. There has not been a five-player test. The balance audit and playtest pack are postponed behind the user's selected visual priority; no numerical tuning is changed in this pass.

## Asset provenance

Generated with OpenAI image generation on 21 October 2026 for this project. `public/art/spring.png`, `summer.png`, `autumn.png`, and `winter.png` share a fixed composition. `props.png` and `props-winter.png` hold separate buildings and objects; `fields.png` holds six crop treatments; `people.png` holds five figures and matching portraits. Original PNGs are preserved; Phaser atlas frames and SVG portrait viewports select regions at runtime. No external requests are required during play.

The bundled originals total approximately 25 MB, so first-load optimization remains useful before public release. The work loop animates painted figures and attached tools rather than using hand-painted frame-by-frame character animation. Provisions use zero, one, or two visible supply groups.
