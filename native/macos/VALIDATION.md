# Native macOS validation — 2026-10-23

Validated on the development Apple Silicon Mac running macOS 27.0.1 with Apple Swift 6.4. The deployment target is macOS 14; this does not establish macOS 14 or Intel hardware compatibility.

## Automated results

- **34 XCTest cases passed**: 20 native/session/scene cases and 14 core cases. Coverage includes the unchanged 40 deterministic TypeScript reference years, three additional complete construction years, assignment changes/cancellation, costs, next-season benefits, outgoing conversation/review snapshots, and reduced-motion actions throughout the scene tree.
- Schema 1 migration covers every phase. Schema 2 tests reject missing or impossible building records, duplicate construction and malformed versions (including JSON booleans). Filesystem tests verify one migration backup before replacement and preserve existing bytes when backup or recovery fails.
- Terrain tests verify 256 projected material tiles, cached seasonal texture changes without replacing nodes, and a construction patch returning to grass after cancellation. Scene tests verify persistent layers, frontmost hit selection, tool depth and no replay of completion effects on load.
- Browser suite: **66 tests passed**; strict TypeScript and production build passed. Browser runtime code is unchanged.
- The release packaging script checks its executable, Info.plist, original and new resource assets, and local ad-hoc signature. Public distribution signing and notarization are outside this build.

## Native app checks

The construction playthrough used a separate DEBUG validation bundle and an explicit test save file. The main player's household was not reset or replaced. The release app ignores the validation launch argument.

- Restored summer work after relaunch: Ion tending, Ana planning the woodshed, Petru planning the cellar. Draft assignments retained all 12 money.
- Confirmed work once: money changed from 12 to 5 and both buildings became complete. Continued through the summer evening and summary.
- Honoured the ox promise in autumn; Petru was reserved for Vasile. Assigned Ion and Ana to the harvest and continued to winter.
- Relaunched with both completed buildings. In winter, a provisions assignment changed food from 33 to 43 for 4 money, confirming the cellar's 10-food benefit. The evening and season report then consumed 6 food and applied 6 weathering, confirming the woodshed benefit. Reached the year ending with food 37, money 1 and shelter 50. Earlier summer hardship correctly remained part of the ending.
- Fresh start preserved that test year in a recovery copy. A new spring household shows separate grass, path, field soil and construction patches, with both build drafts editable.
- Inspected native screenshots of the large isometric scene, compact conversation/command panels, build mode, construction and snowy completed buildings. Journal opens with Command-J. Escape dismisses the journal and optional inspectors; the game-window key handler leaves sheets and confirmation dialogs to their own controls. Early immediate accessibility captures preceded the SwiftUI redraw; a subsequent combined screenshot/tree confirmed dismissal.

Screenshots are local generated artifacts under `build/strategy-validation/`, including `textured-winter-ending.png` and `textured-spring-construction.png`; they are excluded from Git.

## Review and fixes

Independent read-only review found two depth issues in the new scene: tools derived depth from raised hands and could disappear behind the cottage; hit priority selected the cottage ahead of overlapping foreground crops. Both were reproduced by failing tests and fixed by using ground depth for tools and frontmost rendered depth for hit selection. The reviewer rechecked both fixes and the textured terrain and reported no remaining actionable findings. Tests and native interaction were run by the implementing agent.

The existing outgoing-conversation snapshot fix is retained, and phase overlays also receive immutable state snapshots. Missing-art warnings reach SwiftUI without blocking command controls. The scene preserves its backdrop, terrain, world, weather, smoke, selection and feedback containers across assignment changes.

## Limits

No Intel or macOS 14 hardware run, Windows/mobile build, end-to-end VoiceOver audit, enlarged system text or minimum-window-size visual audit. Audio controls were exercised during the earlier native-port validation; subjective sound quality and device-disconnection behavior were not rechecked in this pass. No browser E2E rerun because browser runtime code is unchanged. Save corruption and write failures were exercised in tests rather than by damaging the live household.

Terrain uses repeating painted material textures with fixed paths and plots. There is no free placement, terrain sculpting, walking/pathfinding, custom Metal renderer or historical certification of the generated artwork. Pacing and enjoyment still need player testing. This is a local playable development build, not a notarized release.
