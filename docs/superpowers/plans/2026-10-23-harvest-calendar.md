# Harvest Calendar Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add weekly settlement turns with seeds and a complete grain growth/harvest cycle.

**Architecture:** Keep the existing immutable rules and native session/view boundaries. Add a focused Farming rules file; retain season ordinals for building records and gate seasonal effects at week 12.

**Tech Stack:** Swift 6, SwiftUI, SpriteKit, XCTest; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-harvest-calendar-design.md`

## Global Constraints

- Native Mac settlement only; browser story remains independent.
- 3 months × 4 weeks per season; 48 weeks per year.
- Save resets are allowed; schema 9, no migrations.
- No timers, dependencies, additional fields or crop types.

## Review Focus

- Month/season/year boundaries must charge upkeep exactly once.
- Draft edits, duplicate resolution and reload must not duplicate seeds or harvest.
- Late spring sowing must mature later in autumn and fail safely at winter.
- Malformed calendar/crop state and overflowing quantities must reject before arithmetic.
- Existing construction, reservations, rotations and storage must keep working.

### Task 1: Weekly rules and farming

**Files:** `RazesCore/{Types,Content,Rules,SaveCodec,Presentation,Materials,Construction}.swift`, new `Farming.swift`; core tests.

**Interfaces:** `GameState.week`, `month`, `weekOfMonth`, `isMonthEnd`, `isSeasonEnd`; `Farming.stage`, `label`, `buySeeds`; projection seed costs/gains.

- [x] Write tests for twelve weekly advances per season, 48 per year, monthly food and seasonal buildings, growth/tending/harvest, purchase bounds and save validation; run and observe failures.
- [x] Implement state, rules and validation; update old seasonal test fixtures to weekly calendar boundaries.
- [x] Run the entire native test suite and inspect failures before continuing.

### Task 2: Native calendar, seed controls and growth presentation

**Files:** Native HUD, content/help, phase overlay, field inspector, materials panel, session, scene, SaveStore; native tests; README/validation docs.

**Interfaces:** Use Task 1's calendar, farming and projection values; session `buySeeds(quantity:)` preserves atomic edits and persistence. Preserve main’s painted farmland, placement protection and house stocks; include seeds in house stocks.

- [x] Add session persistence/rejected seed purchase and field-stage scene tests; observe failure.
- [x] Show calendar and seeds; change work/report buttons to weekly; expose immediate seed buying and crop progress; extend painted farmland with a shorter sprouting stage.
- [x] Update instructions and save filename, run native tests, browser checks and release packaging; review complete diff and inspect the app if available.
