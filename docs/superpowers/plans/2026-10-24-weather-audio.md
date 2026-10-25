# Weather Audio Implementation Plan

**Goal:** Varied offline weather audio and persistent sound controls.
**Architecture:** A shared Audio autoload owns buses/preferences. Field-owned audio blends looping layers and schedules thunder from lightning; a shared panel controls buses in both scenes.
**Tech Stack:** Godot built-in audio, GDScript, Ogg recordings.
**Spec:** ../specs/2026-10-24-weather-audio-design.md

## Constraints
No dependencies, gameplay changes or save migrations. Document recording licenses.

## Review focus
Rapid weather changes cancel pending thunder; repeated days do not restart loops; muted preferences restore; malformed settings clamp; scene exit stops playback.

## Tasks
- [x] Source licensed wind/rain/thunder recordings and bundle offline Ogg layers with provenance.
- [x] Add tests for preferences, weather targets, repeated transitions and thunder cancellation; run failing test.
- [x] Implement Audio autoload and shared keyboard-accessible panel; connect menu music and field.
- [x] Implement layered weather playback and coordinated wind motion, with delayed lightning thunder.
- [x] Import assets and run audio, menu and crop tests; inspect rendered controls and document limitations.

## Execution notes
Implemented inline after explicit user authorization. Used licensed recordings;
wind uses CC BY 4.0 with runtime credit details, rain/thunder use CC0. Rain detail
comes from an independent long recording rather than synthesized splash events.
Read-only independent review found preference-test aliasing, keyboard camera
interaction, and export attribution gaps; all corrected and rechecked.
Verification and remaining limitations: godot/VALIDATION.md.
