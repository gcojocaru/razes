# Smaller Plots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every existing plot represent 100 m² with proportionate, precise crop quantities.

**Architecture:** Retain the Farm model and existing grid. Use integer grams throughout crop state and one `Farm.kg(grams: int) -> String` formatter at display boundaries.

**Tech Stack:** Godot 4.7.2, GDScript; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-25-smaller-plots-design.md`

## Global Constraints

- 100 m² per plot; existing 16 × 16 grid.
- Seed costs, harvests and initial stocks scale by 0.1; bag capacities do not.
- Integer grams internally; kilograms with up to three decimal places in UI.
- No migrations, vegetables or human simulation in this change.

## Review Focus

- Exact seed stock sows the last affordable plot without rounding or overdraft.
- Low-fertility harvests remain below one kilogram when appropriate.
- Partial bags preserve fractional kilograms; full bags retain their capacity.
- Previews, tooltips and year records show kilograms rather than raw grams.
- Debug stock additions and the wiki remain consistent with the model.

### Task 1: Resize the farming economy and its displays

**Files:** `godot/farm.gd`, `godot/farm_hud.gd`, `godot/action_wheel.gd`,
`godot/ledger.gd`, `godot/inventory.gd`, `godot/agri_debug.gd`,
`godot/tests/test_crops.gd`, `godot/tests/test_wheel.gd`,
`godot/wiki/wiki.html`, `README.md`, `godot/VALIDATION.md`.

**Interfaces:** Existing Farm actions and records retain integer quantities,
now grams. `Farm.PLOT_AREA_M2` is 100; `Farm.kg(grams: int) -> String` formats
those quantities for all existing displays.

- [x] Add an independently calculated sow/harvest fixture and observe failure.
- [x] Scale crop and starting mass; add the formatter and update all consumers.
- [x] Update existing fixtures and cover exact stock, low yields and partial bags.
- [x] Update wiki and README area, crop tables and initial stocks.
- [x] Run crop, wheel, menu and audio tests, then inspect GPU captures.
- [x] Review the final diff and record validation. Leave changes uncommitted.
