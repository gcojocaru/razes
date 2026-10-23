# Native macOS validation — 2026-10-23

## Materials and shared storage — 2026-10-23

- Native suite: 84 tests passed (39 core, 45 macOS), including 11 material rules tests and 2 material session/save tests. Existing forty reference years and legacy construction paths pass with schema-7 normalization.
- Covered mixed gathering truncation/forecast equality, gathering only at resolution, immediate purchases/crafting, reserved coins and building supplies, atomic failure, invalid quantities, house expansion, storehouse completion/downgrade overflow, explicit discard, post-story gathering without replaying story work, v6 migration and original-byte backup failure protection.
- Independent static review reported no actionable findings.
- DEBUG and Release packaging, bundled-resource checks and strict ad-hoc signature verification passed. Release required a sandbox escalation for Apple’s debug-symbol generator. Packaged and ad-hoc signed DEBUG app. Launched a separate `com.razes.materialsvalidation` bundle with `build/materials-validation/household.json`; did not use the live player's household. Materials sheet and main HUD were visually inspected. UI actions bought 1 wood (6 → 7, coins 12 → 11), crafted 1 plank (wood 7 → 5, plank 0 → 1), upgraded house storage (20 → 30, coins 11 → 3), assigned Ion to timber and confirmed the 6/6 forecast. Work resolution increased wood 3 → 9 and occupied storage 5 → 11, matching the forecast.
- Initial market prices, gathering yields and storage progression have not been playtested for balance. No end-to-end VoiceOver, Intel/macOS14 hardware or browser test run in this increment. Storehouse artwork reuses the granary; roads/fences retain coin-only prices.


## Fence styles, dirt paths and directional snow

- Full native suite: **71 tests passed** (28 core, 43 macOS). New coverage checks dirt/wattle placement costs, overlapping surfaces, mixed-style duplicate edges, protected ground, erasing, save round trips, schema-5 migration backup, malformed styles/extreme coordinates, all four fence edges in all four map views, preview/commit agreement, seasonal texture selection and rotated foundations. Existing reference years, recovery, camera, construction, reduced-motion and progression checks also pass.
- Debug and Release packaging, resource assertions and local signature verification passed, including all three new seasonal/directional atlases. The Release build needed permission to run dSYM generation outside the sandbox; the app was then packaged and its signature independently reverified.
- Inspected the native construction panel: Stone pavement, Dirt path, Rail fence, Wattle fence and Erase are exposed. Selecting Wattle fence displays Rotate fence edge (R); pressing R changes North edge to East edge. Native 180-degree summer/winter inspection showed snowy rear roofs/ground restoring to warm materials/grass. UI captures were small window previews, so they do not establish a full-resolution art audit.
- Used a new `build/strategy-validation/fences-weather-household.json`, copied from an existing isolated test household. It migrated from schema 5 to 6 with an original-byte backup. The actual story remained spring/work while seasonal preview and map rotation changed. The player's household was not edited. A separately identified validation app ran the UI checks.
- Alpha/pixel inspection of source art confirmed twelve distinct major sprites in each rear atlas and six in each front atlas; all eighteen seasonal pairs gained more than ten percentage points of light neutral snow coverage. Shared crop rectangles avoid seasonal rescaling and neighboring-sprite leakage. Cropped SpriteKit textures did not provide readable `CGImage` data in the test runner, so source image inspection performed the pixel check; scene tests check actual selected textures and node behavior.
- No new dependencies or browser runtime changes. No Intel/macOS 14 hardware, full VoiceOver, minimum-window-size or large-text audit in this pass. Directional facades remain painted 2D approximations; construction weather, prices and seasonal simulation retain their existing rules. Browser E2E was not rerun.


Validated on the development Apple Silicon Mac running macOS 27.0.1 with Apple Swift 6.4. The deployment target is macOS 14; this does not establish macOS 14 or Intel hardware compatibility.

## Automated results

- **65 XCTest cases passed**: 38 native/session/scene cases and 27 core cases. Coverage includes the unchanged 40 deterministic TypeScript reference years, three additional complete construction years, assignment changes/cancellation, costs, next-season benefits, outgoing conversation/review snapshots, and reduced-motion actions throughout the scene tree.
- Schema 1 migration covers every phase; schema 2 migration retains construction and adds backed-up layout data. Current-schema tests reject missing or impossible building records, duplicate construction and malformed versions (including JSON booleans). Filesystem tests verify one migration backup before replacement and preserve existing bytes when backup or recovery fails.
- Terrain tests verify 1,024 projected material tiles, cached seasonal texture changes without replacing nodes, and a construction patch returning to grass after cancellation. Scene tests verify persistent layers, frontmost hit selection, tool depth and no replay of completion effects on load.
- Strict Swift format lint reports the existing `ReplaceForEachWithForLoop` warning in unchanged `Tests/RazesCoreTests/SaveTests.swift:27`; touched Swift files format cleanly.
- Browser suite: **66 tests passed**; strict TypeScript and production build passed. Browser runtime code is unchanged.
- The release packaging script checks its executable, Info.plist, original and new resource assets, and local ad-hoc signature. Public distribution signing and notarization are outside this build.

## Rotation, infrastructure and seasonal turns

- All building progression now runs on seasonal turns. Regression coverage checks construction at season end, instant paid upgrades/repairs, seasonal production and condition loss, winter forecast consistency, replay rejection, resource caps and post-story settlement seasons.
- Forty unchanged TypeScript reference years and the three legacy construction years still pass. Obsolete real-time tests were replaced by seasonal and migration coverage.
- Schema 5 migrates v1–v4 data. V4 tests finish already-paid repair/upgrade jobs once, convert foundations, reject invalid timers and retain existing resources. Original-byte migration backups and invalid-replacement protection remain covered.
- Four-view projection tests roundtrip corners/interior/fractional grid points; scene tests align rotated ground, buildings, depth and inverse placement. Rotated non-square scenery bounds reject invalid rotations without changing the save.
- Pavement and fence tests cover prices, duplicate shared edges, erasing, saved/reloaded directions and visual season preview isolation. Drag painting tests fill skipped cells in every view without double charging.
- Rendering tests exercise all directional textures, upright status labels, stable pavement/fence nodes, season changes and reduced motion. Existing front art plus a newly generated RGBA opposite-corner atlas supply the four facades.
- New native validation uses `build/strategy-validation/rotation-household.json`, copied from the previous isolated schema-4 test household. The live player's save is not used. Native inspection confirmed quarter-turn map rotation with upright facades/HUD and the four-season preview picker. The migrated household contains 31 pavement tiles and 10 fence edges placed through native interaction, retains spring/work, and saves a winter visual override. Native screenshot capture later timed out; a process sample showed the app running normally with an idle/event-driven main thread. Quarter-turn rendering was visually inspected before those capture failures, while winter/road materials have scene-test coverage.
- Independent review found that later settlement income could change the first-year ending. The reproduced cost-to-secure regression now uses the preserved winter report to keep the authored judgment stable after settlement begins.
- Browser suite: 66 tests and production build pass; browser runtime remains unchanged. Balance and continuous 3D orbit, hardware trackpad ergonomics, Intel/macOS14 execution and an end-to-end VoiceOver pass remain outside this change.

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

Terrain uses repeating painted materials, fixed dirt trails and protected farmland; building plots can be placed throughout available cells. There is no terrain sculpting, walking/pathfinding or custom Metal renderer or historical certification of the generated artwork. Pacing and enjoyment still need player testing. This is a local playable development build, not a notarized release.
