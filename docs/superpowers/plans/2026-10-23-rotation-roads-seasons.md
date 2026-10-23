# Rotation, Roads and Seasonal Turns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline, with one final independent review.

**Goal:** Four-view rotation, building facing, pavement/fence painting, season preview and fully seasonal building progression.
**Architecture:** Extend existing layout/projection and construction rules, removing real-time work. Keep authored story validation and add building-only post-story turns. Native scene layers share one rotated projection and directional sprite lookup.
**Tech Stack:** SwiftPM, SwiftUI, SpriteKit, AppKit; no dependencies.
**Spec:** docs/superpowers/specs/2026-10-23-rotation-roads-seasons-design.md

## Global Constraints

- Preserve v1–v4 backups and legacy seasonal drafts; strictly validate migration input.
- Four orientations, 20 condition per resolved season, instant paid upgrade/repair, one coin per pavement tile/fence edge.
- Preserve browser runtime and live player's save; macOS validation uses a separate bundle/profile.

## Review Focus

- Rotated inverse projection and depth must agree for every map corner and placement orientation.
- Shared fence edges and dense infrastructure must not duplicate, overflow or cause invalid saves.
- Seasonal production/decay must run exactly once and match forecasts, including winter and cap boundaries.
- V4 migration must finish already-paid jobs once and reject invalid timers before discarding fields.
- Visual debug seasons must not change events, survival rules, story progression or worker assignments.

### Task 1: Rules and persisted layout

Files: RazesCore Construction/BuildingProgression, Settlement, Types, SaveCodec, Rules, Presentation; core tests and reference normalization; SaveStore threshold/tests.

- [x] Add failing tests for instant paid upgrades/repairs, seasonal production/wear once, construction completion, post-story seasons, valid/invalid v4 conversion, facing and road/fence invariants.
- [x] Replace wall-clock rules with seasonal resolution; schema 5 migrations, rotation/infrastructure validation and visual season override.
- [x] Native core/reference tests pass.

### Task 2: Placement, projection and native commands

Files: GameSession, GameUIState, IsometricLayout, ContentView, BuildPanel, BuildingInspector, DebugBuildPanel, SelectionInspector, PhaseOverlay, GameHUD; app tests.

- [x] Add failing tests for all-four-view projection roundtrips, rotated footprint placement, paid infrastructure/eraser, facing persistence and season preview isolation.
- [x] Remove timer hooks, implement instant inspector commands, repeat road/fence tools, rotation controls, debug picker, post-story season command.
- [x] Full native tests pass.

### Task 3: Rendering, proof and delivery

Files: HomesteadScene/navigation, TerrainLayer, BuildingArtwork, infrastructure renderer and directional atlas; scene tests, documentation/package checks.

- [x] Add failing tests for rotated ground/world/selection alignment, all directional textures, stable infrastructure nodes and reduced motion.
- [x] Compose pavement and fence edges; use consistent rotated positions/depth and directional facades, preserving HUD.
- [x] Run native/browser tests, builds and format checks; package/sign; verify native rotation, roads, seasons and instant upgrades in isolated app.
- [x] Obtain one read-only review, regress/fix material issues, commit bounded feature.
