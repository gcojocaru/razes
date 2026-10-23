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

| Building    | Build price | Level 1 production per minute |
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

Choose a type and click free ground. Green footprints fit; red footprints are occupied, outside the map or protected house/farm space. The price is paid immediately, preserving coins reserved for seasonal assignments. Construction takes 10 seconds per base coin (30–90 seconds). Workers retain their seasonal jobs. Select any building to inspect condition, move its plot, upgrade or repair it. There is one structure of each type per household.

Upgrades cost the base price times the target level and take 60 seconds per target level. Production multiplies by level. Buildings lose four condition per real hour; at zero, a structure above level 1 loses a level and returns to 60 condition. Level 1 stays at zero and produces nothing until repaired. Repairs cost half the base price rounded up and take 20 seconds. Work pauses both production and wear and restores condition to 100 on completion. Resources cap at 100000.

Timers and fractional production save locally and catch up on reopening, with a maximum 24 hours per absence. Backwards clock changes do not replay time. The clock runs through conversations, seasons and the year ending. The starter house retains its original seasonal shelter/repair rules. The woodshed's winter food/wear protection and cellar's improved provisions begin in the season after actual completion and require positive condition. Old seasonal build assignments still finish when their season resolves.

Drag the map, right/middle-drag, or scroll to pan. Pinch or Option-scroll to zoom. The Pan menu, zoom buttons, percentage and Home reset provide explicit camera controls. A drag does not trigger selection or placement. Escape cancels placement or closes optional commands.

The Debug workshop places any type instantly, finishes construction/upgrades/repairs, edits levels 1–5 and condition, grants 100 coins/food, and advances the building clock by one or 24 hours. These debug actions cost nothing and leave the story season unchanged. Optional barn, well, stores and fence scenery still uses space without producing resources. Debug changes save with the household.

Accepted commands and clock progress save to `~/Library/Application Support/Razes/household-v1.json`. Schema 4 records levels, condition, work timers, production fractions and the clock alongside plot locations and scenery. Clock progress saves every 15 seconds and when work completes; commands save immediately. Schema 1–3 saves migrate on load and receive a uniquely named byte-for-byte migration backup before first replacement. Schema 1–2 also restore legacy scenery/locations; the filename stays the same. Saves validate progression before reading and writing and use atomic replacement. Unreadable data blocks gameplay until retry or explicit fresh start. Restart preserves existing bytes in a uniquely named recovery copy. Failed preservation retains the original; write failures retain the live run with an explicit warning. Browser saves remain separate.

## Reference parity

`RazesCore` contains portable Swift rules, types, authored content, presentation mapping and validation. `RazesMac` owns the session, native views, audio and scene. Authored data is exported at development time; no JavaScript runs in the app.

Regenerate content and the 40 deterministic reference years using existing npm dependencies:

```sh
node_modules/.bin/esbuild scripts/native-parity.ts --bundle --platform=node --outfile=/tmp/razes-parity.cjs
node /tmp/razes-parity.cjs
swift test --package-path native/macos
```

Fixtures cover all four ox outcomes, all three endings and six field states. Tests compare every action's state, forecast and presentation with TypeScript results; negative tests cover rejected actions, contradictory saves, failed writes and recovery. Native construction extends these baseline rules; three additional complete construction years check timing, costs and benefits. The TypeScript game has no construction changes. Re-exporting after deliberate browser balance changes makes that new reference explicit.

The SpriteKit scene composes persistent backdrop, terrain, world, weather, smoke, selection and feedback nodes. A shared 2:1 projection places the household; world sprites, tools and hit targets use ground depth. Selection and assignments preserve these containers. The ground uses 1,024 reusable diamond tiles with cached grass, earth and snow textures. Paths, the field soil and construction patches are composed per tile, rather than baked into one ground picture. Seasonal materials and completed building textures swap in place. Ten building silhouettes reuse the original artwork and a new painted atlas; level storage layers, wear marks, condition bars and construction progress compose independently. Construction dust, tools, completion flashes and resource feedback respect reduced motion; loading does not replay completion effects. SwiftUI draws the HUD separately. This is a painted 2D scene with validated grid placement and a bounded camera.

Artwork is reused from `public/art/`; see the root README and `docs/art/2026-10-21-painterly-pass.md` for provenance; the new ground and construction assets are documented in `docs/art/2026-10-22-native-construction.md` and `docs/art/2026-10-23-settlement-buildings.md`. Bundled DM Sans and Cormorant Garamond font licenses are in `Sources/RazesMac/Resources/Fonts/`.

This first port does not implement mobile/Windows, custom Metal rendering, browser-save migration, pathfinding, cloud saves or store distribution. See the [native validation report](VALIDATION.md) for checks actually performed.
