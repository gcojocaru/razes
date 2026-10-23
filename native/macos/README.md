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

Use Build to plan a woodshed (3 money) or root cellar (4 money) on its fixed plot. One adult builds each during spring, summer or autumn; change or cancel the assignment before confirming. Work charges once and finishes construction. Benefits begin the following season: woodshed winter base consumption is 6 rather than 9 and wear is 6 rather than 14; a cold-house surcharge still applies. The cellar raises each provisions purchase from 7 to 10 food for the same 4 money.

Accepted choices and draft assignments save to `~/Library/Application Support/Razes/household-v1.json`. Schema 2 saves record completed buildings and their season. Schema 1 saves migrate on load and receive a uniquely named migration backup before their first replacement; the filename stays the same. Saves use atomic writes and validate progression before resuming. An unreadable save blocks gameplay until retry or explicit fresh start. Restart preserves existing bytes in a uniquely named `household-recovery-*.json` beside the save. A failed preservation leaves the original untouched. Write failures retain the live run with an explicit warning. Browser saves are separate and are not imported.

## Reference parity

`RazesCore` contains portable Swift rules, types, authored content, presentation mapping and validation. `RazesMac` owns the session, native views, audio and scene. Authored data is exported at development time; no JavaScript runs in the app.

Regenerate content and the 40 deterministic reference years using existing npm dependencies:

```sh
node_modules/.bin/esbuild scripts/native-parity.ts --bundle --platform=node --outfile=/tmp/razes-parity.cjs
node /tmp/razes-parity.cjs
swift test --package-path native/macos
```

Fixtures cover all four ox outcomes, all three endings and six field states. Tests compare every action's state, forecast and presentation with TypeScript results; negative tests cover rejected actions, contradictory saves, failed writes and recovery. Native construction extends these baseline rules; three additional complete construction years check timing, costs and benefits. The TypeScript game has no construction changes. Re-exporting after deliberate browser balance changes makes that new reference explicit.

The SpriteKit scene composes persistent backdrop, terrain, world, weather, smoke, selection and feedback nodes. A shared 2:1 projection places the household; world sprites, tools and hit targets use ground depth. Selection and assignments preserve these containers. The ground uses 256 reusable diamond tiles with cached grass, earth and snow textures. Paths, the field soil and construction patches are composed per tile, rather than baked into one ground picture. Seasonal materials and completed building textures swap in place. Construction dust, tools, completion flashes and resource feedback respect reduced motion; loading does not replay completion effects. SwiftUI draws the HUD separately. This is a painted 2D scene with fixed plots.

Artwork is reused from `public/art/`; see the root README and `docs/art/2026-10-21-painterly-pass.md` for provenance; the new ground and construction assets are documented in `docs/art/2026-10-22-native-construction.md`. Bundled DM Sans and Cormorant Garamond font licenses are in `Sources/RazesMac/Resources/Fonts/`.

This first port does not implement mobile/Windows, custom Metal rendering, browser-save migration, free placement, cloud saves or store distribution. See the [native validation report](VALIDATION.md) for checks actually performed.
