# Fences, paths and weather implementation plan

**Goal:** Add dirt paths, woven wattle fences and reliable placement rotation; preserve building identity and snow in all views.

**Architecture:** Extend existing settlement types/session, infrastructure drawing and directional texture selection. Use schema 6 for safe migration and new painted seasonal resources.

**Spec:** `docs/superpowers/specs/2026-10-23-fences-paths-weather-design.md`

- [x] Add regression checks for rear winter art and rotated infrastructure placement, then run them to observe the missing behavior.
- [x] Add dirt-path and fence-style persistence, v1–5 migration with backup, placement/duplicate/erase rules and tests for malformed saves and reserved money.
- [x] Add material buttons, explicit fence edge control, shared R handling, dirt tiles, wattle rendering and preview/commit tests in all map rotations.
- [x] Correct the rear artwork and add winter atlases. Wire consistent seasonal crops for house, scenery, buildings and ghosts; retain foundation art in every facing.
- [x] Run the complete Swift suite, package/sign the native app, inspect rendered native proof and document actual validation and art provenance.

Checks cover mixed-style duplicate edges, overlapping surfaces, protected/out-of-bounds placement, older-save backup, paint costs, reduced motion, repeated seasonal changes and upright labels. Work stays in the current clean checkout and is not committed or published automatically.
