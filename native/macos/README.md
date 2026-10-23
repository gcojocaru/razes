# Răzeș for macOS

Native SwiftUI + SpriteKit port of the complete four-season browser game. Requires macOS 14 or later and a Swift 6 toolchain (Xcode 16 or later). No backend, web server, accounts, or third-party Swift packages.

Open `Package.swift` in Xcode and run `RazesMac`, or from the repository root:

```sh
swift test --package-path native/macos
native/macos/Scripts/package_app.sh
open native/macos/build/Razes.app
```

The packaging script builds for the current Mac's architecture, copies the resource bundles, signs for local development, and checks the bundle and signature. The generated app lives in `build/Razes.app`. It is not notarized or signed for public distribution. Intel Macs and macOS 14 have not been tested on hardware.

In a restricted workspace, use writable caches and disable SwiftPM sandboxing:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/razes-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/razes-swift-cache \
swift test --package-path native/macos --disable-sandbox --scratch-path /tmp/razes-swift-build
```

## Playing and saves

Choose the opening conversation, give each adult one task, review the forecast and confirm work. The evening conversation resolves consumption and weathering. Continue through winter for the ending. Select a portrait or a place to open its command inspector. The large isometric household stays behind a fixed resource strip and portrait command bar; temporary conversations and reviews occupy only the space they need. The Places menu provides keyboard alternatives to scene targets. Escape closes optional commands. Command-J opens the journal. Sound starts off. Reduce motion freezes optional scene animation; the system accessibility setting takes priority.

New households start with the house and three adults. Build offers ten types on the 16×16 isometric map, each with levels 1–5:

| Building    | Build price | Level 1 production per season |
| ----------- | ----------: | ----------------------------- |
| Woodshed    |     3 coins | 1 coin                        |
| Root cellar |     4 coins | 2 food                        |
| Barn        |     5 coins | 1 food + 1 coin               |
| Well        |     3 coins | 1 food                        |
| Granary     |     6 coins | 2 food + 1 coin               |
| Workshop    |     5 coins | 2 coins                       |
| Bakery      |     7 coins | 3 food + 1 coin               |
| Smithy      |     8 coins | 3 coins                       |
| Stable      |     9 coins | 1 food + 2 coins              |
| Apiary      |     4 coins | 2 food + 1 coin               |

Choose a type and click free ground. Green footprints fit; red footprints are occupied, outside the map or protected house/farm space. The price is paid immediately, preserving coins reserved for seasonal assignments. Foundations complete at the end of the season, after the evening conversation. Workers retain their jobs. There is one structure of each type per household.

Select a building to inspect condition, rotate or move it, upgrade or repair. Upgrades cost the base price times the target level and apply immediately; production multiplies by level. Repairs cost half the base price rounded up and restore condition immediately. Existing completed buildings produce the catalog yield once per season, included in the forecast. They then lose 20 condition after seasonal consumption. At zero, a structure above level 1 loses a level and returns to 60 condition; level 1 stays inactive until repaired. New construction first produces the following season. Resources cap at 100000. The starter house retains its original shelter rules. Woodshed winter protection and improved cellar provisions require positive condition and begin the season after completion.

There are no construction, upgrade, repair, production or decay clocks, including while the app is closed. After the authored first-year ending, Next settlement season advances building-only seasonal turns; the original story, journal and worker assignments remain. This allows ongoing development without replaying authored conversations.

Drag the map, right/middle-drag, or scroll to pan. Pinch or Option-scroll to zoom. The Pan menu, zoom buttons and Home reset provide explicit camera controls. Rotate map left/right cycles four views while the HUD stays upright. Each placed building/scenery has its own facing. A building inspector can rotate it; R or Rotate placement changes facing before placement. Rotation updates projected ground, depth, people, tools, smoke, selection and inverse map picking together. Painted front/rear facades and mirrors provide four directional views, with shared seasonal crops and snow on roofs, ledges and bases in every view. The rear artwork preserves building materials and features; foundations retain construction artwork when rotated. This is 2D artwork, not a continuous 3D orbit.

Build offers Stone pavement, Dirt path, Rail fence, Wattle fence and Erase. Both path surfaces cost one coin per tile; both fence styles cost one per cell edge. Click or drag to paint connected runs; the tool stays active. R or Rotate fence edge selects the north/east/south/west edge, including when the map owns keyboard focus. The painted preview matches the chosen fence style and edge in all four map views. Path surfaces cannot overlap each other; a path and a fence can coexist. A shared edge cannot be charged twice, even using a different fence style from the opposite side. Erase removes either path surface and bordering fences with no refund. Buildings cannot cover infrastructure. House/farmland stay protected. Escape cancels a tool or closes optional commands.

The Debug workshop places buildings instantly, finishes foundations, edits levels/condition and grants resources. Season preview changes painted ground, seasonal art and weather without changing story events, resources, simulation season or workers. Actual season restores the real view. Legacy barn/well/stores/fence debug scenery is retained. Debug edits save with the household.

Commands save atomically to `~/Library/Application Support/Razes/household-v1.json`. Schema 6 adds dirt paths and rail/wattle fence styles to directions, pavement/fence edges, visual preview, seasonal buildings and extra post-story turns. Schema 1–5 original bytes receive a unique migration backup before first replacement. Already-paid v4 upgrades/repairs complete on load; pending builds become seasonal foundations. Old fractional minute production is discarded (less than one former cycle), while resources/levels/condition/positions/history remain. Old timer data is validated before conversion, and invalid saves fail closed. Unreadable data blocks gameplay until retry or explicit fresh start; restart preserves a recovery copy. Browser saves remain separate.

## Reference parity

`RazesCore` contains portable Swift rules, types, authored content, presentation mapping and validation. `RazesMac` owns the session, native views, audio and scene. Authored data is exported at development time; no JavaScript runs in the app.

Regenerate content and the 40 deterministic reference years using existing npm dependencies:

```sh
node_modules/.bin/esbuild scripts/native-parity.ts --bundle --platform=node --outfile=/tmp/razes-parity.cjs
node /tmp/razes-parity.cjs
swift test --package-path native/macos
```

Fixtures cover all four ox outcomes, all three endings and six field states. Tests compare every action's state, forecast and presentation with TypeScript results; negative tests cover rejected actions, contradictory saves, failed writes and recovery. Native construction extends these baseline rules; three additional complete construction years check timing, costs and benefits. The TypeScript game has no construction changes. Re-exporting after deliberate browser balance changes makes that new reference explicit.

The SpriteKit scene composes persistent backdrop, terrain, world, weather, smoke, selection and feedback nodes. A shared 2:1 projection places the household; world sprites, tools and hit targets use ground depth. Selection and assignments preserve these containers. The ground uses 1,024 reusable diamond tiles with cached grass, earth and snow textures. Paths, the field soil and construction patches are composed per tile, rather than baked into one ground picture. Seasonal materials and completed building textures swap in place. Ten building silhouettes reuse the original artwork and painted front/rear atlases; level storage layers, wear marks, condition bars and construction progress compose independently. Construction dust, tools, completion flashes and resource feedback respect reduced motion; loading does not replay completion effects. SwiftUI draws the HUD separately. This is a painted 2D scene with validated grid placement and a bounded camera.

Artwork is reused from `public/art/`; see the root README and `docs/art/2026-10-21-painterly-pass.md` for provenance; the new ground and construction assets are documented in `docs/art/2026-10-22-native-construction.md` and `docs/art/2026-10-23-settlement-buildings.md` and `docs/art/2026-10-23-directional-buildings.md`. Bundled DM Sans and Cormorant Garamond font licenses are in `Sources/RazesMac/Resources/Fonts/`.

This first port does not implement mobile/Windows, custom Metal rendering, browser-save migration, pathfinding, cloud saves or store distribution. See the [native validation report](VALIDATION.md) for checks actually performed.
