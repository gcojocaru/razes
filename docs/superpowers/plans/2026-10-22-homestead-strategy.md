# Homestead Strategy Interface and Construction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for the selected inline execution. Steps use checkbox syntax for tracking. One independent review follows implementation.

**Goal:** Make the painted homestead the native game's main screen and add two visually distinct, strategically useful buildings without losing existing households.

**Architecture:** Extend the existing Foundation rules with two construction assignments, completion seasons and shared benefit calculations. SwiftUI owns a compact HUD and transient selection/overlays; SpriteKit owns stable world nodes, selection markers and presentation effects. Versioned save migration preserves original bytes before replacement.

**Tech Stack:** Swift 6, SwiftUI, SpriteKit, existing AVFoundation audio, XCTest, bundled painted PNG assets. No third-party Swift dependencies or direct Metal rendering.

**Spec:** `docs/superpowers/specs/2026-10-22-homestead-strategy-design.md`

## Global Constraints

- Native macOS only, macOS 14 minimum, offline operation; browser gameplay and generated reference expectations remain unchanged.
- Keep the four-season story, three existing workers, crop/event/ending rules and existing task values unless the approved building benefit explicitly changes them.
- Woodshed: 3 money and one worker; in subsequent winter, base consumption 6, wear 6; existing cold surcharge remains 3.
- Root cellar: 4 money and one worker; provisions assignments in subsequent seasons yield 10 food at the existing 4-money price.
- Construction only in spring/summer/autumn work phases, one worker per building, editable drafts, one completion per building, benefits from the following season.
- Fixed plots; no workshop, free placement, demolition, upgrades, new materials, real-time timers, walking simulation or multi-year economy.
- Default window 1280 by 850, minimum 1000 by 700; no scrolling outer page; at least 80% of the world unobscured with optional overlays closed and no conversation.
- Native keyboard equivalents, visible costs/errors, deliberate work/restart confirmations, system/app reduced motion and inactive audio suspension remain mandatory.
- Schema version 2; validate legacy version 1, migrate in memory, preserve original bytes before replacement, retain existing save location and atomic-write/recovery behavior.
- Deliver a locally runnable development-signed app and honest validation report; no publishing/notarization.

## Review Focus

- Same-turn construction/purchases must not receive future benefits: Task 1 timing assertions.
- A valid-looking completion record must not grant an impossible building: Task 2 progression-validation tests.
- Failed migration preservation must leave the original v1 bytes unchanged: Task 2 filesystem/session tests.
- Resuming completed saves must not replay rewards or completion effects; selection must not restart weather: Task 3 scene identity/effect tests and Task 5 relaunch checks.
- Small windows, long conversations and outgoing SwiftUI views must retain readable, reachable controls without trapping: Task 4 lifecycle tests and Task 5 native layout checks.

## File map

- Create `native/macos/Sources/RazesCore/Construction.swift`: building IDs/definitions/completion records, native task lookup and shared effective-cost/gain helpers.
- Modify core `Types.swift`, `Rules.swift`, `SaveCodec.swift`, `Presentation.swift`: construction state/actions, forecasts/resolution, schema validation and derived plot stages.
- Modify `native/macos/Sources/RazesMac/SaveStore.swift`, `GameSession.swift`: migration preservation, observable selection, accepted-action changes supplied to presentation.
- Create app `GameHUD.swift`, `SelectionInspector.swift`, `BuildPanel.swift`, `PhaseOverlay.swift`, `PortraitView.swift`: fixed viewport HUD, contextual commands, construction controls, conversations/reviews and existing-atlas portraits.
- Modify app `ContentView.swift`, `ConversationView.swift`, `WorkView.swift`, `HomesteadScene.swift`, `Ambience.swift`: replace page layout, retain shared commands, stable scene layers and restrained feedback. Delete helpers/views made redundant by the final layout.
- Add six painted PNGs in app `Resources/Art/`: `woodshed-construction.png`, `woodshed-complete.png`, `woodshed-winter.png`, `cellar-construction.png`, `cellar-complete.png`, `cellar-winter.png`.
- Add `ConstructionTests.swift`, `MigrationTests.swift`, `SceneConstructionTests.swift`; extend existing rules/save/store/session/conversation/resource tests without changing stored TypeScript outcomes.
- Update native `README.md`, `VALIDATION.md`, packaging resource checks; add `docs/art/2026-10-22-native-construction.md` for provenance and visual limitations.

### Task 1: Construction and benefits in the rules

**Interfaces:**

- Consume existing `GameState`, `Action`, `Task`, `Projection`, `Rules` and `Content.shared`.
- Produce `BuildingID: String, Codable, CaseIterable` with `woodshed`, `cellar`; `BuildingRecord` with `id: BuildingID` and `completedSeason: Int`; `GameState.buildings: [BuildingRecord]` initially empty.
- Add `TaskID.buildWoodshed`, `.buildCellar`; expose `Construction.definition(_ id: BuildingID) -> BuildingDefinition`, including title, task ID, money cost and benefit copy.
- Centralize native lookup as `Rules.task(_ id: TaskID) -> Task`, `Rules.consumption(_ state: GameState, house: Int) -> Int`, `Rules.weathering(_ state: GameState) -> Int`, and `Rules.suppliesGain(_ state: GameState) -> Int`. All rules/UI/validation/report lookups use those helpers for native tasks.

- [ ] Add failing `ConstructionTests` before implementation: draft assignment leaves money unchanged; resolving a woodshed costs 3 once; a second worker/rebuild/winter construction is rejected; reserved Petru is rejected; cancelling restores ordinary assignments; two different builders cost 7 with no double completion. Run the tests and confirm missing construction behavior is the failure.
- [ ] Implement definitions, state and the two assignment tasks. Construction cost joins the existing pre-income affordability check; completion records are appended only on successful resolve. Task options retain an already selected draft and exclude completed buildings. Update existing UI task-name lookups to the shared helper and give the old scene a safe construction-worker position until Task 3 supplies plot positions; no forced lookup may crash on the new task IDs.
- [ ] Add failing benefit tests using legal action sequences: woodshed completed by autumn yields winter consumption 6 at shelter 40, 9 below 40, and winter wear 6; no woodshed yields 9/12 consumption and wear 14. Cellar completion plus a provisions assignment still yields 7 that season; subsequent-season purchases yield 10 each. Preview, actual report and final resources must agree.
- [ ] Implement shared effective helpers in preview and evening settlement; construction never receives its own future benefit. Preserve report worker ordering and include readable construction task names.
- [ ] Extend the test fixture loader to add an empty native buildings collection to raw reference states before typed decoding, without changing stored fixture data. Run the full native suite and no-construction reference replay. Require all original projections/numeric outcomes/endings to remain identical; do not change generated JSON or TypeScript expected results to make tests pass. Commit this rules increment.

### Task 2: Version 2 saves and preservation of legacy households

**Interfaces:**

- Consume Task 1 state, task lookup and effective weathering.
- Preserve `SaveCodec.encode(_:)`, `SaveCodec.decode(_:)`, `SaveStore.load()`, `save(_:)`, `startFresh(_:)`, and session error behavior.
- New saves encode version 2 with required `buildings`. Legacy version 1 validates its original tasks/relationships before returning a normalized version 2 state with no buildings. Direct reference-fixture decoding normalizes version and empty buildings explicitly for comparisons.

- [ ] Add failing migration tests from the existing raw v1 fixtures at every phase: decoded stocks/history/revision/phase/assignments unchanged, version becomes 2, buildings empty, source bytes unchanged. Assert missing v2 buildings, malformed/duplicate/unknown records, winter completion, future completion, duplicate builders and v1 construction tasks are rejected.
- [ ] Implement schema-aware decoding. Missing construction data is acceptable only for version 1; version 2 requires valid records. Retain existing bounds and history/ox/crop/affordability checks, using shared task and weathering helpers where building benefits affect them. Preserve strict rejection of unsupported versions.
- [ ] Add phase relationship tests: opening/work accepts only earlier-season completion; resolved phases require a matching current-season assignment for a current completion and vice versa. Round-trip construction drafts, completions, later seasons and endings. Test winter-hearth/cold history validation with reduced wear.
- [ ] Add filesystem tests using temporary directories: loading v1 never writes; the first successful replacement creates a unique migration backup containing identical v1 bytes; later v2 writes do not create repeated migration backups; a forced preservation failure leaves original bytes unchanged and session retains live progress with a save warning. Test fresh-start protection of a legacy save too.
- [ ] Implement preservation before v1 replacement using the existing scoped file-copy seam and atomic write path. Keep `household-v1.json` as the established filename; schema version is carried inside JSON. Surface any failure through existing session warnings, never a fallback save location.
- [ ] Run all native rules/migration/store/session tests plus baseline reference comparisons. Commit schema/migration support.

### Task 3: New building art and stable world presentation

**Interfaces:**

- Consume Task 1 completion records and assignment state.
- Add `BuildingStage` (`empty`, `planned`, `complete`) derived from state; `SceneSelection` (`worker(WorkerID)`, `hotspot(Hotspot)`, `building(BuildingID)`) is transient app state.
- Replace the scene's global teardown with stable named terrain, prop, worker, building, selection, weather and feedback layers. Expose `HomesteadScene.update(state: GameState, reducedMotion: Bool)`, `select(_ selection: SceneSelection?, buildMode: Bool)` and `onSelection: ((SceneSelection) -> Void)?`.

- [ ] Use the imagegen skill and built-in image generation to produce each of the six required transparent painted assets. Inspect existing art with `view_image` first and label it as style/perspective reference. Inspect every output for real alpha, grounded perspective, usable edges, visual distinction and matching seasonal treatment; copy accepted files into the app resources and document provenance. Do not use programmatic image editing as a substitute for generated painted assets.
- [ ] Add failing scene tests for both plots' derived stages and bundled textures; a missing asset produces the observable warning while native controls remain usable. Choose fixed footprints on unused ground after inspecting the full scene; record those coordinates once beside rendering and hit targets so they cannot drift apart.
- [ ] Implement stable scene layers and update only changed properties. Keep the existing background composition and all essential places in view at supported aspect ratios. Position construction workers at their plots, preserve existing worker/visitor identity and expose all scene targets through the selection callback.
- [ ] Add failing identity/effect tests: selecting a worker, opening Build, assigning unrelated work or toggling sound preserves existing weather node identity; initial load of a completed state produces no completion feedback; a live incomplete-to-completed transition produces feedback exactly once; repeated update does not repeat it.
- [ ] Implement plot previews/selection outlines, scaffolding stages, completed/winter textures, short hammer/dust/completion feedback and restrained seasonal lighting. Resource-change feedback uses accepted state differences and is not emitted on load/retry. Reduce motion removes optional actions while retaining static progress/selection; restoring motion resumes presentation without replaying completion.
- [ ] Run native scene/resource/rules tests, inspect the packaged scene with both buildings and capture art-state evidence. Commit art and world presentation.

### Task 4: Replace the page with strategy controls

**Interfaces:**

- Consume Tasks 1–3 state, selection and scene callback; all mutations still call `GameSession.send(_:)` with the displayed revision.
- `ContentView` owns the fixed SpriteView viewport, transient `selection`, `buildMode`, optional review visibility and journal/help presentation. Child controls receive immutable phase snapshots and action closures wherever phase changes can invalidate their contents.
- `GameHUD` presents resources and worker portraits; `SelectionInspector` presents the selected place/worker/building; `BuildPanel` presents the two definitions; `PhaseOverlay` presents mandatory conversations and optional forecast/report/ending views.

- [ ] Add failing selection/phase tests: opening conversation hides optional inspector; Escape clears optional selection/Build but not mandatory dialogue; an outgoing conversation/forecast/summary can re-evaluate safely after session phase changes; reopening a dismissed summary still exposes Continue. Reuse the existing outgoing-conversation regression pattern.
- [ ] Replace the outer ScrollView, heading, resource cards, footer, permanent sidebar and below-scene household with the full-window viewport. Add the approximately 48-point resource strip and 96-point floating command area. Preserve the 1280-by-850 default and 1000-by-700 minimum.
- [ ] Implement portraits from existing atlas crops and compact assignment commands. Clicking a world target and its keyboard-accessible command select the same object; worker assignment, cancellation, obligations and unavailable-action explanations all use the shared rule functions. Build mode reveals plot previews and cost/timing/benefit details; selecting a completed building shows its benefit status.
- [ ] Implement temporary dialogue overlays and internally scrolling contextual/review panels, with at most 300-point inspector width at the default window. Keep cost copy, disabled explanations, deliberate forecast confirmation, journal, help, restart confirmation, sound, reduced motion and persistent save/resource warnings. Retain Command-J and focus indication.
- [ ] Remove obsolete page helpers and update contextual help for construction. Ensure toggling UI state does not reinitialize the scene/session. Wire optional audio feedback through the existing sound/inactivity controls, with no gameplay dependency on sound or animation completion.
- [ ] Run the full native suite. Inspect default/minimum layouts with long conversation text and task errors: no horizontal scrolling, choices/forecast/confirmation reachable, scene targets remain usable, and the unobscured work view meets the 80% world target. Commit the interface.

### Task 5: End-to-end checks, review and packaged handoff

**Files:** Native README, validation report, packaging checks and any fixes substantiated by this task; no new gameplay scope.

- [ ] Extend the packaging self-check to require all six new art resources as well as the existing bundles, executable and signature. Document construction controls, exact benefits, schema migration and legacy backup names in the native README.
- [ ] Run `npm test`, `npm run build`, `npm run format:check`, `swift test --package-path native/macos`, release packaging and `git diff --check`. In the restricted environment, use the established writable module caches and `--disable-sandbox`; record environment-only limitations separately.
- [ ] Use native app controls to play representative complete years with each building. Verify a build competes with labour, costs once, displays each stage and applies its benefit only in a later season. Quit/relaunch during a draft and after completion; verify no reward/effect replays. Preserve the user's live household; use safe test fixtures/directories for destructive failure checks.
- [ ] Check keyboard commands, all phase transitions, internal scrolling at minimum size, visible warning states, system/app reduced motion and inactivity/sound. Capture HUD, inspector, construction, completed buildings and winter screenshots. Report checks that could not be exercised rather than implying they passed.
- [ ] Request the selected independent whole-change review with this spec, plan, diff and validation results; emphasize migration, benefit timing, stable scene nodes and outgoing views. Fix actionable findings with focused regression tests and rerun affected checks.
- [ ] Update `native/macos/VALIDATION.md` with exact commands/results, screenshots, known limits and art provenance. Commit the complete change, leave the local feature branch intact, and provide the runnable `.app` path. Do not publish or merge.

## Execution handoff

The user already selected inline implementation followed by independent review earlier in this chat; preserve that method. This plan is ready for written-plan review. Implementation starts after that review, with no further execution-method selection or per-task approval pauses.
