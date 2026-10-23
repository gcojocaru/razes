# Native macOS validation — 2026-10-23

Validated on the development Apple Silicon Mac running macOS 27.0.1 with Apple Swift 6.4. The deployment target is macOS 14; this does not establish macOS 14 or Intel hardware compatibility.

## Automated results

- **47 XCTest cases passed**: 28 native/session/scene cases and 19 core cases. Coverage includes the unchanged 40 deterministic TypeScript reference years, three additional complete construction years, assignment changes/cancellation, costs, next-season benefits, outgoing conversation/review snapshots, and reduced-motion actions throughout the scene tree.
- Schema 1 migration covers every phase; schema 2 migration retains construction and adds backed-up layout data. Schema 3 tests reject missing or impossible building records, duplicate construction and malformed versions (including JSON booleans). Filesystem tests verify one migration backup before replacement and preserve existing bytes when backup or recovery fails.
- Terrain tests verify 1,024 projected material tiles, cached seasonal texture changes without replacing nodes, and a construction patch returning to grass after cancellation. Scene tests verify persistent layers, frontmost hit selection, tool depth and no replay of completion effects on load.
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

Screenshots are local generated artifacts under `build/strategy-validation/`, including `textured-winter-ending.png`, `textured-spring-construction.png` and `expanded-settlement.png`; they are excluded from Git.

## Expanded settlement checks

- A fresh isolated household starts with the house and people; the barn, well, stores and fence are absent. Farmland appears when worked.
- Chose a woodshed location through the native map. The inspector recorded plot `(10, 7)` and resources remained 18 food / 12 money. Assigned Ana, then used the debug workshop to finish construction. Spring stayed in work phase, Ana became unassigned, and money remained 12. The schema-3 save records the chosen location and debug completion explicitly; both restored after relaunch.
- Native zoom-out changed the visible zoom percentage from 111% to 93%; Home restored 111%. The Pan menu's directional action was exercised. Camera tests cover scale/position bounds, pointer anchoring and reset; scene-input tests verify dragging moves the camera without committing a placement. Physical pinch ergonomics were not assessed. Coordinate automation intermittently returned a window-service error; scenery placement/persistence has unit-test coverage, while the palette and instant completion were exercised through native accessibility controls.
- Unit tests cover scenery placement/persistence, rejected overlaps and bounds without revision changes, plot removal cancelling a builder, debug completion without seasonal-history changes, and v2 migration backup preservation.
- A damaged save containing a later structure at `Int.max` initially trapped while building an occupancy set. A regression reproduced the trap; validation now checks all coordinates before occupancy arithmetic. Extreme positive and negative coordinates reject cleanly.
- Moving an assigned plot initially left tools and dust at the old position. Its regression now passes, with effect position/depth following the worker. Resource feedback is camera-relative, and Escape cancels optional debug placement during conversations while keeping mandatory dialogue visible.

## Review and fixes

Independent read-only review found two depth issues in the new scene: tools derived depth from raised hands and could disappear behind the cottage; hit priority selected the cottage ahead of overlapping foreground crops. Both were reproduced by failing tests and fixed by using ground depth for tools and frontmost rendered depth for hit selection. The reviewer rechecked both fixes and the textured terrain and reported no remaining actionable findings. Tests and native interaction were run by the implementing agent.

The existing outgoing-conversation snapshot fix is retained, and phase overlays also receive immutable state snapshots. Missing-art warnings reach SwiftUI without blocking command controls. The scene preserves its backdrop, terrain, world, weather, smoke, selection and feedback containers across assignment changes.

## Limits

No Intel or macOS 14 hardware run, Windows/mobile build, physical trackpad-pinch assessment, end-to-end VoiceOver audit, enlarged system text or minimum-window-size visual audit. Audio controls were exercised during the earlier native-port validation; subjective sound quality and device-disconnection behavior were not rechecked in this pass. No browser E2E rerun because browser runtime code is unchanged. Save corruption and write failures were exercised in tests rather than by damaging the live household.

Terrain uses repeating painted materials, fixed paths and protected farmland; building plots can be placed throughout available cells. There is no terrain sculpting, walking/pathfinding or custom Metal renderer or historical certification of the generated artwork. Pacing and enjoyment still need player testing. This is a local playable development build, not a notarized release.
