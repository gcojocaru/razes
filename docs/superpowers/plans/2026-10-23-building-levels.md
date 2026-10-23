# Real-Time Building Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Ten buildable types with five real-time upgrade levels, decay, repairs and visible progression.
**Architecture:** Extend the current catalog/records and add a deterministic time integrator in RazesCore. The existing session owns wall-clock catch-up and saving; SpriteKit composes persistent building layers and SwiftUI presents commands.
**Tech Stack:** SwiftPM, SwiftUI, SpriteKit, AppKit; no new dependencies.
**Spec:** docs/superpowers/specs/2026-10-23-building-levels-design.md

## Global Constraints

- Preserve v1–v3 save bytes before first schema-4 write; retain all seasonal rules and legacy build assignments.
- Ten buildable types, levels 1–5, four condition/hour, 60-second production cycles, 24-hour offline cap.
- Keep browser gameplay unchanged and validate with an isolated macOS save.

## Review Focus

- Tick subdivision and work/downgrade boundaries must produce the same result.
- A sleeping/restarted app or reversed wall clock must not duplicate rewards.
- Costs must not invalidate already assigned seasonal work or consume future earnings.
- Malformed current and migrated save records must fail closed without overwriting bytes.
- Repeated scene updates, movement, reduced motion and upgrades must not leak overlays or hide selection targets.

### Task 1: Core progression and schema migration

**Files:** RazesCore Construction.swift, new BuildingProgression.swift, Types.swift, Rules.swift, SaveCodec.swift, Settlement.swift; core tests; fixture normalization; SaveStore.swift/tests.
**Interfaces:** Construction.start/upgrade/repair(state:inout GameState); advance(state:inout GameState, seconds:Double); catchUp(state:inout GameState, now:Double). BuildingRecord gains level/condition/work/production/realtime fields.

- [x] Add failing tests for ten catalog entries, timed construction, five-level cap, paid repairs, ruin and multiple downgrades, fractional time equivalence, clock rollback/catch-up, costs and migration validation.
- [x] Run Swift tests and observe missing APIs/assertions fail.
- [x] Implement catalog, deterministic progression and schema-4 migration; retain legacy task paths and historical wear.
- [x] Run full native suite; expected zero failures, including unchanged reference years.

### Task 2: Session and command UI

**Files:** GameSession.swift, ContentView.swift, BuildPanel.swift, SelectionInspector.swift, DebugBuildPanel.swift; session tests.
**Interfaces:** session.tick(now:), upgradeBuilding/repairBuilding, debugSetBuilding/debugAdvance/debugResources; existing placement remains the shared mutation path.

- [x] Add failing session tests for paid timed placement, persistence/reload, completion after restart, invalid commands preserving state and debug changes.
- [x] Implement one-second ticks, quiet periodic saves, upgrades/repairs, inspector and catalog status, debug controls and help copy.
- [x] Run full native suite; expected zero failures.

### Task 3: Layered rendering and runnable proof

**Files:** HomesteadScene.swift, navigation extension, new BuildingArtwork.swift, scene tests, README.md, VALIDATION.md.
**Interfaces:** shared building texture factory, level/condition/work overlays reused by normal sprites and placement previews.

- [x] Add failing scene tests for all ten visible/clickable types, all five level cues, wear/working/reduced-motion state and stable node count.
- [x] Implement distinct silhouettes and overlays without replacing existing supplied artwork.
- [x] Run native tests, browser tests/build/format, package/sign, isolated app inspection. Expected passing checks and a usable app.
- [x] Obtain one independent final review, fix material findings, commit the bounded change.
