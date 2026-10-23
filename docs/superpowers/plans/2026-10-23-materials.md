# Household Materials Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans; use test-driven-development and verification-before-completion.

**Goal:** Make buildings depend on gathered, bought and crafted supplies with shared expandable storage.
**Architecture:** RazesCore owns inventory, costs, gathering projections and atomic actions; GameSession persists accepted edits; SwiftUI exposes Materials and construction costs.
**Tech Stack:** Swift 6, SwiftUI, SpriteKit, XCTest; no new dependencies.
**Spec:** docs/superpowers/specs/2026-10-23-materials-design.md

## Global Constraints
- Native macOS only; preserve browser behavior, existing household history and live saves.
- Gathering is seasonal; buying and crafting are immediate and worker-free.
- Shared capacity, reservation-safe payments and no destructive overflow.
- Initial tuning is specified in the design; no selling/depletion.

## Review Focus
- Mixed gathering at nearly full capacity: forecast equals actual haul.
- Legacy drafts reserve materials; purchases/crafting/building cannot steal them.
- Failed actions are atomic and malformed save values fail closed.
- Storehouse downgrade preserves inventory; first storehouse fits starter capacity.
- Gathering remains usable after the first-year story without replaying story tasks.

### Task 1: Core materials, construction and saves
Files: create RazesCore/Materials.swift and MaterialsTests.swift; modify Types, Rules, Construction, BuildingProgression, SaveCodec and relevant tests.
- [x] Add failing gathering/catalog and construction affordability tests; verify RED with swift test.
- [x] Implement MaterialStock, MaterialID and Materials helpers; add gatherWood/gatherStone tasks, forecast/resolution, storehouse, material reservations and costs, instant market/crafting/house upgrades.
- [x] Migrate schema 7 and extend reference normalization; preserve pre-v7 bytes in SaveStore.
- [x] Test capacity, transactions, migration, malformed saves, mixed gathering, post-story gathering and all-level construction. Run native suite.

### Task 2: Native controls and visual integration
Files: MaterialsPanel, GameSession, ContentView, SelectionInspector, BuildingInspector, BuildPanel, PhaseOverlay, BuildingArtwork and native session tests.
- [x] Test session persistence, rejected edits, storehouse art and gathering after the story.
- [x] Wire existing editSettlement actions, inventory panel, costs, forecast/report and storehouse art reuse.
- [x] Run full native suite, package local app, inspect using isolated validation save if UI access is available.

### Task 3: Review and documentation
- [x] Review final diff against capacity/reservation/migration cases; fix consequential findings with regression tests.
- [x] Update native README and validation notes; record verified checks and untested balance/hardware behavior.

## Progress
- Plan and design recorded from approved conversation. Executing in clean existing feature checkout; no push/merge requested.

- Verification: 84 native tests green; DEBUG/Release app packaging and strict ad-hoc signature checks pass; independent static review found no actionable issues; isolated native UI verified buy/craft/house upgrade/gathering forecast and resolution. No commits, push or merge requested.
- Ruling: retain coin-only infrastructure in this increment; materials apply to buildings/upgrades/repairs. Storehouse reuses granary art. Added explicit discard to avoid a full-inventory deadlock.
