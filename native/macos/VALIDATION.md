# Native macOS validation — 2026-10-22

Validated on the development Apple Silicon Mac running macOS 27.0.1 with Apple Swift 6.4. The package deployment target is macOS 14; this does not establish macOS 14 or Intel hardware compatibility.

## Automated results

- Browser baseline and final suite: **66 tests passed**. Browser production build and repository Prettier check passed.
- Native final suite: **13 XCTest cases passed** across rules/reference parity, save decoding, persistence, session failures, resources and outgoing conversation lifecycle.
- Initially compared **400 complete reference years** in Swift: every action's state, projection, presentation and ending matched TypeScript. Retained **40 deterministic years** (about 2.7 MB) in the repository; those cover honoured/broken/paid/declined ox outcomes, all three ending categories and all six field states. Regeneration is byte-identical.
- Reference snapshots round-trip through Swift save validation. Tests reject malformed/unsupported and contradictory saves, protect reserved labour and reject repeated/stale actions. Filesystem tests exercise failed writes and failed recovery preservation without destroying original bytes.
- Resource tests load bundled art, verify optional scene actions stop under reduced motion, and exercise a missing art directory. Missing-art warnings are copied into SwiftUI state.
- Release package builds and passes its executable, Info.plist, resource-presence and `codesign --verify --deep --strict` checks. The package is host-architecture arm64, approximately 26 MB, with a local ad-hoc signature.

## Native app checks

Using the packaged app through native accessibility controls:

- Chose the borrowed ox route; assigned sowing to Ion and repairs to Ana.
- Quit and relaunched; both draft assignments and the work phase resumed.
- Completed spring, summer, autumn and winter through the native interface and reached the final ending. Summer deliberately had no work, producing food hardship and a crisis ending even though later stores recovered.
- Honoured the autumn promise: Petru's assignment was disabled and reserved for Vasile. Ion and Ana were both assigned to harvest; the preview and resulting stocks reflected the harvest.
- Verified native task sheets, work confirmation, journal with Command-J, Escape dismissal, and sound/reduced-motion toggle states. Audio toggling did not block or crash gameplay; subjective audio quality was not assessed.
- Confirmed fresh start returned to spring. The previous run is retained as a recovery file by the same path exercised in persistence tests.
- Inspected painted scenes and native text/controls in screenshots. All four seasons render; scene assets load from the packaged bundle without a development server.

Screenshots are local generated artifacts under `build/validation/`: `spring.png`, `summer.png`, `autumn.png`, `winter.png`, `ending.png`, and the final handoff screenshot when available. They are intentionally excluded from Git.

## Fixes found during validation

The first native playthrough exposed an outgoing SwiftUI conversation view reading the already-transitioned session phase. It trapped in event selection. Passing an immutable state snapshot to the conversation view fixes this; an XCTest regression covers outgoing-view evaluation after phase change, and the fresh rebuilt app completed the remaining year. Launch Services briefly reused a stale running binary during rechecks; executable UUIDs distinguished that process from the rebuilt package.

Independent code review found that a missing-art warning could remain invisible because SKScene state is not observable. The warning now updates SwiftUI state after scene refresh, with a missing-resource regression test. The reviewer rechecked both fixes and reported no remaining actionable findings.

## Limits

Not verified on Intel or macOS 14 hardware, with VoiceOver end-to-end, enlarged system text, minimum-size window resizing, audio-device failure/disconnection, or other platforms. Accessibility labels, keyboard actions, reduced-motion scene behavior and failure handling have the narrower evidence listed above. Invalid-save recovery and write failures were exercised in tests rather than by damaging the development app's live household file. No browser E2E rerun was needed because browser runtime code is unchanged.

This is a first playable local build, not a notarized release. Distribution signing, App Store submission, browser-save import, player enjoyment, historical review and pacing validation remain outside this port.
