# Settlement Placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Expand the household into a navigable map with freely placed construction and a debug palette.

**Architecture:** Keep scene composition and portable seasonal rules. Add validated layout data to GameState and a bounded SpriteKit camera; SwiftUI selects a placement tool, scene previews it, and the session validates and persists its result.

**Tech Stack:** Swift, SwiftUI, SpriteKit, XCTest; macOS 14+; no dependencies.

**Spec:** docs/superpowers/specs/2026-10-23-settlement-placement-design.md

## Global Constraints

- Continue in the existing checkout and inline workflow; preserve live household data.
- 16×16 logical cells, 32×32 material tiles; fixed house and protected farm cells.
- Keep normal costs, workers and next-season benefits; debug completion skips cost/time, not history.
- Schema 3; back up v1/v2 originals before replacement.

## Review Focus

- Out-of-map and overlapping footprints reject without changing state or revision.
- Migrated construction and seasonal history remain valid, including winter.
- Debug completion never changes prior consumption or report history.
- Dragging and zooming do not place or select accidentally.
- Camera scale/position remain bounded and reset remains accessible.

### Task 1: Validated settlement data and migration

Files: add RazesCore/Settlement.swift and SettlementTests; update Types, Construction, Rules, SaveCodec, migration/reference/save-store tests and SaveStore.

- [x] Write failing tests for bounds, occupied house/farm/scenery, uniqueness, round-trip, v1/v2 migration and instant debug completion during winter.
- [x] Add GridPosition, placements/scenery/layout and footprint validation; auto-position construction assigned through core actions.
- [x] Migrate schema 1/2 with legacy scenery/plots; require and validate layout in schema 3 and back up older saves once.
- [x] Run full native suite and preserve no-building reference parity.

### Task 2: Camera and placement scene

Files: IsometricLayout, TerrainLayer, HomesteadScene; add CameraState.swift/CameraTests and placement scene tests.

- [x] Write failing checks for enlarged tile count, sparse new settlement, placement coordinates and camera bounds/zoom anchoring.
- [x] Compose scenery and buildings from saved positions; derive terrain patches, workers and selection from the same layout.
- [x] Add bounded camera, scroll/pinch/drag controls and click suppression after pan.
- [x] Add placement ghost/footprint, snapping, rejection and callback. Run native tests.

### Task 3: Construction and debug commands

Files: GameSession, GameUIState, ContentView, BuildPanel, SelectionInspector, GameHUD; add DebugBuildPanel and session tests.

- [x] Write failing session checks for persisted layout, rejected placement, free debug completion and cancellation.
- [x] Add validated atomic layout edits, placement UI, move/remove plans, debug scenery and instant completion, plus camera controls.
- [x] Build/run an isolated native profile; inspect house-only start, arbitrary placement, collisions, pan/zoom and debug construction; relaunch and verify layout.
- [x] Run native/browser/build/format checks, independent final review, package/sign app and document actual limits.
