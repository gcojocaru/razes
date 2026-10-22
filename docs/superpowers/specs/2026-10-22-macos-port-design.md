# Răzeș native macOS port

## Outcome and authority

The user selected Swift and macOS first, then approved the proposed full-year port scope. Deliver an offline native macOS app preserving the current browser game's choices, balance, assignments, consequences, journal and endings. This document describes that port; implementation follows written-spec and plan review.

The current TypeScript implementation is the behavioral reference. Earlier browser design documents describe intent but do not override current rules, content or balance. The browser app remains usable and unchanged apart from documentation and a narrowly scoped fixture-generation command if needed for parity verification.

## Scope and delivery

Create an Xcode-openable Swift package under `native/macos/`, targeting macOS 14 or later. Use SwiftUI for the interface and SpriteKit for the homestead. Use no third-party Swift dependencies. Package a locally runnable `.app` with bundled assets and an ad-hoc development signature. Distribution signing, notarization and store submission are outside scope.

Deliver the complete four-season loop, native local persistence, restart confirmation, journal, help, sound and reduced-motion controls. Preserve existing English copy and Romanian names. Reuse the current painted artwork and bundled fonts, including their applicable license files. No new gameplay, custom Metal renderer, general engine, browser-save migration, Windows or mobile implementation.

## Structure and state ownership

- `RazesCore`: Foundation-only value types, balance, content, pure rules, presentation mapping, and save decoding/validation. No SwiftUI, SpriteKit, AppKit or filesystem access.
- `RazesMac`: SwiftUI app, a main-actor observable session owning the current state and presentation settings, local save access, SpriteKit scene and audio.
- Core tests and checked-in parity fixtures; a small packaging script and local build/run instructions.

Translate `src/game/` and `src/scene/presentation.ts` directly rather than redesigning the rules. Preserve stable event/task/person identifiers, action revision checks, action ordering, affordability and exactly-once work/consumption behavior. Preview calculations remain pure. Rejected actions leave state and saved data unchanged.

SwiftUI actions and scene hotspots call the same session action handler. The scene receives state-derived presentation updates and never owns authoritative game state. The session persists every accepted action, including draft assignments, then updates the visible status. There is one household session; prevent separate windows from independently writing the same save.

## Interface

Use a resizable single main window with an initial size around 1280 by 850 points and a minimum size of 1000 by 700. A resource header, painted homestead and household/task information share the window with the current conversation or season report. Allow scrolling where text exceeds available height; support enlarged text without clipping essential controls.

Native buttons, pickers and sheets replace HTML controls. Show costs and obligations before confirmation. Disable invalid choices and explain assignment/forecast errors. Expose journal, help, restart, sound and motion through labelled controls. Restart requires explicit confirmation.

Every scene hotspot has an equivalent native control. Support keyboard navigation, Escape to dismiss sheets, accessible names/values and readable contrast. After a phase transition, direct accessibility focus to the new conversation/report heading where supported. Respect system reduced motion; an app control may additionally reduce animation but cannot override a system request to reduce it. Sound is off initially and starts only after enabling it. Suspend optional sound while the app is inactive.

## Homestead and sound

Recreate the existing 1200 by 760 scene composition using the current atlas crops and proportional scaling. Preserve layer ordering and hotspot alignment when resizing. Show seasonal landscapes, crop progression, damaged/intact house, stores and appropriate visitors. Use subtle existing-style smoke, weather and character/tool animation; freeze optional motion under reduced motion. No walking animation is implied by static character art.

Load resources from the package bundle, never from the repository at runtime. Missing artwork must leave the game controls usable and display a useful warning. Recreate quiet procedural ambience and the action cue using Apple audio APIs; audio failures cannot block play. SpriteKit manages rendering; direct Metal code is unnecessary for this scope.

## Persistence and failures

Store a versioned JSON snapshot at the user Application Support directory under `Razes/household-v1.json`. Keep the logical state fields aligned with the reference game, but do not promise binary or JSON compatibility with browser saves. Codable decoding is followed by structural bounds and progression validation equivalent to `src/game/save.ts`.

Write snapshots atomically. On write failure, retain the live run and show a persistent saving warning; do not claim the action was durably saved. When a save exists but cannot be read, is invalid, or has an unsupported version, show recovery UI and prevent gameplay from silently replacing it. Recovery offers retry and a confirmed fresh household. Starting fresh preserves the original file under a unique recovery name before replacing it; if preservation fails, leave it untouched and report the failure. A missing save starts a new household normally.

## Validation and acceptance

1. Generate deterministic action sequences and expected states/projections/endings from the current TypeScript rules. Swift tests replay those fixtures and compare decoded values rather than JSON formatting. Cover borrow/honour, borrow/break, pay, decline, agricultural success/failure and all ending categories.
2. Test stale revisions, invalid assignments, affordability, reserved autumn labour and exactly-once seasonal resolution. Port meaningful invalid-save cases, including contradictory progression. Test save round trips, failed reads/writes and recovery without overwriting the original file.
3. Run the existing browser unit tests to confirm the reference remains intact; build and test the Swift package.
4. Package and launch the app. Verify bundled artwork without a running web server, keyboard controls, resize behavior, reduced motion, sound toggle and no blank seasonal scene. Complete a year in the native app and verify quit/relaunch resumes a saved phase and draft assignments. Record screenshots of representative seasonal states.
5. Verify bundle structure and development signature. Report any unavailable runtime/accessibility checks separately from passing automated tests. An ad-hoc signature does not establish Gatekeeper distribution readiness.

Success means the current game can be played to an ending in the native macOS app, its rules match the reference fixtures, and accepted progress survives relaunch. Player enjoyment, historical accuracy and the original pacing targets remain unvalidated by this port.

## Principal risks

Translation can change subtle progression or save invariants; parity fixtures and focused negative tests address this. Atlas coordinates and different text metrics can change composition; native screenshots and resize checks address this. The package is structured to keep rules portable, but future iOS UI work and non-Apple presentation stacks require separate designs.
