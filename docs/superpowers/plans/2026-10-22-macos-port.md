# Native macOS Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver a playable native macOS Răzeș app preserving the browser game's complete year and validated local saves.

**Architecture:** A Foundation-only `RazesCore` target owns value types, content, rules, presentation and save validation. A SwiftUI executable owns one main-actor session, SpriteKit presentation, filesystem persistence and optional procedural sound. Native rules are checked against fixtures produced by the existing TypeScript implementation.

**Tech Stack:** Swift Package Manager, SwiftUI, SpriteKit, AVFoundation, XCTest; existing TypeScript/Vitest for reference fixtures. No third-party Swift dependencies.

**Spec:** `docs/superpowers/specs/2026-10-22-macos-port-design.md`

## Global Constraints

- Target macOS 14 or later; create an Xcode-openable package under `native/macos/`.
- Preserve current English copy, Romanian names, balance and stable identifiers; current TypeScript is behavioral authority.
- Preserve the browser application; only add documentation and a narrowly scoped reference-fixture generator there.
- Bundle existing painted artwork, fonts and applicable licenses; no runtime repository paths or network dependencies.
- No new gameplay, custom Metal renderer, browser-save migration, Windows or mobile implementation.
- Save at Application Support `Razes/household-v1.json`; validate before resuming; write atomically.
- One household session; sound initially off; honor system reduced motion.
- Deliver a locally runnable development-signed `.app`; distribution signing, notarization and store submission are outside scope.

## Review Focus

- A stale control or repeated confirmation must not apply work or consumption twice: Task 1 negative action tests.
- A save with valid JSON but contradictory progression must not resume or be overwritten: Tasks 2 and 3 recovery tests.
- An unwritable save location or failed recovery backup must preserve existing bytes and the live run: Task 2 filesystem tests.
- Resizing and enlarged text must leave choices, forecasts and hotspot alternatives reachable: Tasks 3 and 4 runtime checks.
- Missing art, audio initialization failure and app inactivity must not block gameplay: Task 4 failure checks.

## File map

- `native/macos/Package.swift`: core, app, and test targets; macOS floor and bundled resources.
- `native/macos/Sources/RazesCore/{Types,Balance,Content,Rules,Presentation,SaveCodec}.swift`: direct counterparts of existing game modules.
- `native/macos/Sources/RazesMac/{RazesApp,GameSession,SaveStore,ContentView,ConversationView,WorkView,JournalView,HomesteadScene,Ambience}.swift`: app lifecycle, state ownership, persistence and native presentation.
- `native/macos/Sources/RazesMac/Resources/`: painted PNGs, font files and licenses.
- `native/macos/Tests/RazesCoreTests/`: rules, parity, presentation and codec tests plus JSON fixtures.
- `native/macos/Tests/RazesMacTests/`: persistence/session tests; app target must be importable by its test target.
- `scripts/native-parity.ts`: deterministic TypeScript fixture generation, executed through existing Vitest tooling with a small dedicated test entry if required; no added npm dependency.
- `native/macos/Scripts/package_app.sh`: build, bundle resources, emit Info.plist and ad-hoc sign.
- `native/macos/README.md`, root `README.md`, `.gitignore`: local usage, native entry point and generated-output exclusions.

### Task 1: Reference fixtures and a matching Swift game core

**Interfaces:**
- Consume the types and functions in `src/game/{types,balance,content,rules}.ts` and `src/scene/presentation.ts`.
- Produce Codable/Equatable Swift state/action/content types mirroring the reference fields and stable raw identifiers.
- Produce `Rules.newGame() -> GameState`, `Rules.dispatch(_ state: GameState, action: Action) throws -> GameState`, `Rules.preview(_ state: GameState) -> Projection`, `Rules.currentEvent(_ state: GameState) -> GameEvent`, `Rules.ending(_ state: GameState) -> Ending`, `Rules.taskOptions(_ state: GameState) -> [Task]`, `Rules.choiceProblem(_ state: GameState, choice: Choice) -> String?`, and `Rules.assignmentProblem(_ state: GameState, worker: WorkerID, task: TaskID) -> String?`.
- Produce `Presentation.init(state: GameState)` exposing field, house, stores, visitor and weather values equivalent to the reference mapping. Preserve subtitle and field-label copy as pure state-derived helpers.

- [ ] Create the package and core test target, ignore `.build/`, `.swiftpm/` and native build output. Add a failing `testInitialStateMatchesReference` comparing decoded fixture state with `Rules.newGame()`; confirm failure is missing implementation.
- [ ] Implement a deterministic reference generator using real dispatch/preview/ending functions. Include complete borrow/honour, borrow/break, pay and decline paths; cover tended/untended/unplanted/unharvested crops and all three ending categories. Export initial state, each action, each resulting state and projection, presentation, and final ending. Assert route/category coverage during generation and verify byte-identical output on repeated generation.
- [ ] Implement `Types.swift`, `Balance.swift` and `Content.swift` directly from current source. Preserve optional-effect semantics and ordered worker iteration; do not derive report order from dictionary iteration.
- [ ] Add failing parity tests replaying every fixture action and comparing all state, projection, presentation and ending values. Add rejection tests for stale revision, actions after ending, wrong event/phase, unaffordable choices, duplicate planting/tending, one/three harvesters and reserved Petru reassignment; assert input state unchanged after rejection.
- [ ] Implement `Rules.swift` and `Presentation.swift` with immutable state transitions. Check current rules tests for additional invariants; do not fix or rebalance reference behavior during translation.
- [ ] Run `npm test` and `swift test --package-path native/macos --filter RazesCoreTests`; require passing parity, negative and presentation tests. Commit the core and fixtures as one independently reviewable change.

### Task 2: Validated saves and loss-preserving recovery

**Interfaces:**
- Consume `GameState` from Task 1.
- Produce `SaveCodec.encode(_ state: GameState) throws -> Data` and `SaveCodec.decode(_ data: Data) throws -> GameState` in the core.
- Produce `SaveStore.init(url: URL)`, `SaveStore.load() throws -> GameState?`, `SaveStore.save(_ state: GameState) throws`, and `SaveStore.startFresh(_ state: GameState) throws` in the app. The default location is resolved with FileManager's user Application Support URL, appending `Razes/household-v1.json`.

- [ ] Add failing codec tests for round trips at every fixture phase and rejection of malformed data, unsupported version, missing fields, negative stocks, invalid enum values, out-of-order history, false ox/reservation relationships, impossible crops and unaffordable draft assignments. Mirror current `src/game/save.ts` bounds and relationships.
- [ ] Implement `SaveCodec.swift` using Codable plus explicit relationship validation. Verify integer bounds and collection/string limits; decoding alone is insufficient. Require all valid fixture states to decode without applying gameplay effects.
- [ ] Add temporary-directory persistence tests: missing file returns nil; save/reload preserves state; invalid existing bytes remain untouched after load; replacing a snapshot leaves valid complete JSON; a regular file used as a parent causes a reported write failure. Add recovery tests confirming original bytes survive under a unique recovery filename and that a forced backup failure leaves the original unchanged.
- [ ] Implement `SaveStore.swift` with directory creation, atomic writes, and unique recovery copies before a confirmed fresh start. Provide a narrowly scoped injectable file operation only if necessary to exercise otherwise unreliable failure cases; do not introduce a general storage framework.
- [ ] Run both native test targets and confirm all valid fixture snapshots round-trip. Commit codec and persistence behavior.

### Task 3: A complete playable SwiftUI year

**Interfaces:**
- Consume Task 1 rules and Task 2 persistence.
- Produce `@MainActor @Observable final class GameSession`, owning `state: GameState`, `error: String?`, `storageWarning: String?`, and recovery status; methods `send(_ action: Action)`, `retryLoad()`, and `startFresh()`.
- Produce `ContentView(session: GameSession)` and dedicated conversation, work and journal views. Scene and sound integration follow in Task 4.

- [ ] Add failing session tests for accepted draft autosave, rejected actions not writing, failed save retaining updated live state and warning, invalid startup blocking actions, retry loading repaired data, and failed fresh-start preservation keeping recovery active.
- [ ] Implement `GameSession.swift` and `RazesApp.swift`. Create one Window scene and one shared session; do not allow independent writable household windows. Wire session recovery to Task 2 operations.
- [ ] Implement the resizable SwiftUI layout with initial 1280 by 850 and minimum 1000 by 700 dimensions, resource header, household, phase panel and scene placeholder. Register bundled fonts and use existing copy. Use scroll containers for variable-length text.
- [ ] Implement opening/consequence choices with visible costs and disabled explanations, editable worker assignments, preview warnings/errors, explicit work confirmation, summary/continue, and all ending categories. Use action revisions captured for rendered controls.
- [ ] Add journal, task detail/help and restart confirmation sheets. Include accessible labels, keyboard-operable native controls, Escape dismissal and phase-heading accessibility focus where supported. Provide recovery retry and confirmed fresh-start controls without presenting playable new state over an invalid save.
- [ ] Run session/core tests and `swift build --package-path native/macos`. Launch a development build and complete a year through native controls; verify draft assignment and phase survive relaunch, keyboard navigation works, and long text remains reachable at minimum size. Commit the playable interface.

### Task 4: Painted SpriteKit homestead and optional sound

**Interfaces:**
- Consume `Presentation`, `GameState` and the shared session from earlier tasks.
- Produce `HomesteadScene.update(state: GameState, reducedMotion: Bool)` and a hotspot callback carrying `field`, `house`, `visitor` or `stores`. Dispatch task-selection UI through the session/view; scene callbacks never mutate rules.
- Produce main-actor `Ambience.setEnabled(_ enabled: Bool)` and `Ambience.cue()` with failures contained inside the audio implementation.

- [ ] Bundle current PNGs, font resources and licenses. Add presentation tests covering every field state, house threshold, stores threshold and visitor selection before implementing scene behavior.
- [ ] Implement `HomesteadScene.swift` using `src/scene/Homestead.ts` atlas coordinates, composition, crop orientation, layer order and hotspot placement. Use proportional scene scaling inside SpriteView; convert atlas coordinates carefully between top-left source pixels and SpriteKit texture coordinates.
- [ ] Replace the placeholder with SpriteView. Wire hotspots to the same task/detail actions available through native controls, including unavailable field guidance and visitor focus. Report missing resources while retaining playable native controls.
- [ ] Implement modest weather, smoke and character/tool animation. Combine the system reduced-motion setting with the app's additional reduction toggle; freezing optional animation must not prevent state changes.
- [ ] Implement optional procedural ambience/cue in `Ambience.swift`, off at launch and enabled only through an explicit control. Stop/suspend on inactivity and restore according to the user's setting; safely ignore unavailable audio. Cue accepted actions only.
- [ ] Build and launch. Check all four seasons, crop and roof changes, visitors, resize alignment, system/app reduced motion and sound/inactivity. Exercise a missing-resource build and audio failure path without breaking controls. Save representative screenshots. Commit scene/audio integration.

### Task 5: Package, verify and document the macOS app

**Interfaces:**
- Consume the completed `RazesMac` executable and SwiftPM resource bundles.
- Produce `native/macos/build/Razes.app` via `native/macos/Scripts/package_app.sh`; executable display name is Răzeș and bundle identifier is `com.razes.game`.

- [ ] Adapt the existing macOS packaging skill's template to build the release executable, resolve its directory with `swift build --show-bin-path`, copy required SwiftPM resource bundles, create Info.plist with macOS 14 minimum, and ad-hoc sign the resulting app. Avoid update frameworks and distribution tooling. Make errors stop the script.
- [ ] Add a packaging self-check asserting executable permissions, Info.plist identifier/minimum version, expected asset/resource presence and `codesign --verify --deep --strict` success.
- [ ] Document Xcode package opening, build/test/package/launch commands, saves/recovery paths and development-signature limitations in the native README. Link it from the root README.
- [ ] Run final `npm test`, native `swift test`, release package build, packaging self-check and `git diff --check`. Investigate new failures; distinguish environment blockers from product failures.
- [ ] Launch the packaged app with no development server. Verify art loads from the bundle, complete a year, quit/relaunch after a draft assignment and another phase, exercise confirmed restart and invalid-save recovery, and inspect minimum-window/text-size usability and keyboard/accessibility behavior. Record the actual results and screenshot locations.
- [ ] Review the final diff against the spec, commit the completed port and report exact checks, limitations and the local `.app` path. Do not publish or claim notarization/distribution readiness.

## Execution recommendation

Use native execution in this session: these five tasks share tightly coupled rules/session/presentation interfaces, and the current port is small enough to keep one implementation context. A fresh whole-change reviewer should check rule parity, save recovery and app lifecycle after implementation. Execution starts after the user reviews this plan and selects the execution method.
