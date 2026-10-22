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

Choose the opening conversation, give each adult one task, review the forecast and confirm work. The evening conversation resolves consumption and weathering. Continue through winter for the ending. The field, house and stores open task sheets; equivalent buttons and worker pickers support keyboard use. Escape dismisses sheets. Command-J opens the journal. Sound starts off. Reduce motion freezes optional scene animation; the system accessibility setting takes priority.

Accepted choices and draft assignments save to `~/Library/Application Support/Razes/household-v1.json`. Saves use atomic writes and validate progression before resuming. An unreadable save blocks gameplay until retry or explicit fresh start. Restart preserves existing bytes in a uniquely named `household-recovery-*.json` beside the save. A failed preservation leaves the original untouched. Write failures retain the live run with an explicit warning. Browser saves are separate and are not imported.

## Reference parity

`RazesCore` contains portable Swift rules, types, authored content, presentation mapping and validation. `RazesMac` owns the session, native views, audio and scene. Authored data is exported at development time; no JavaScript runs in the app.

Regenerate content and the 40 deterministic reference years using existing npm dependencies:

```sh
node_modules/.bin/esbuild scripts/native-parity.ts --bundle --platform=node --outfile=/tmp/razes-parity.cjs
node /tmp/razes-parity.cjs
swift test --package-path native/macos
```

Fixtures cover all four ox outcomes, all three endings and six field states. Tests compare every action's state, forecast and presentation with TypeScript results; negative tests cover rejected actions, contradictory saves, failed writes and recovery. Re-exporting after deliberate browser balance changes makes that new reference explicit.

Artwork is reused from `public/art/`; see the root README and `docs/art/2026-10-21-painterly-pass.md` for provenance. Bundled DM Sans and Cormorant Garamond font licenses are in `Sources/RazesMac/Resources/Fonts/`.

This first port does not implement mobile/Windows, custom Metal rendering, browser-save migration, new gameplay, cloud saves or store distribution. See the [native validation report](VALIDATION.md) for checks actually performed.
