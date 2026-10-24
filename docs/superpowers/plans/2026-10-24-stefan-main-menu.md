# Ștefan Main Menu Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline in this session. User authorized implementation and the first local commit.

**Goal:** A medieval Moldavian inspired title screen whose Play button opens an empty black screen.

**Architecture:** Two Godot scenes, one menu script, scalable vector ornament and bundled font. Project settings own version 0.1.0. No game state or dependencies.

**Tech Stack:** Godot 4.7.2, Compatibility renderer, GDScript, SVG, openly licensed font.

**Spec:** docs/superpowers/specs/2026-10-24-stefan-main-menu-design.md

## Global Constraints

- Title ȘTEFAN, button Play, version v0.1.0; blank black game screen after Play.
- Mouse and keyboard activation, visible focus, readable at 1000×700 and larger.
- No gameplay, extra menus, sound, animation or save migrations.
- Keep Git history and origin; first Ștefan commit includes the authorized reset; no push.

## Review Focus

- Romanian Ș renders without a missing glyph.
- Button has initial keyboard focus and a visible focus indicator.
- Resizing cannot clip the title, button or version.
- Starting a game removes all menu decoration and controls.
- Version text matches project settings.

### Task 1: Menu, blank scene and verification

**Files:** Create `godot/project.godot`, `godot/main.tscn`, `godot/game.tscn`, `godot/menu.gd`, `godot/assets/menu.svg`, font/license under `godot/assets/fonts/`, `godot/tests/test_menu.gd`; reuse `godot/run.sh`; update README.

**Interfaces:** `main.tscn` exposes Title, Play and Version controls; Play changes to `res://game.tscn`. Test uses the real input event path and scene tree.

- [x] Write headless menu test: title, version, Romanian glyph, initial focus, layout bounds at minimum/default/large sizes, keyboard activation and mouse activation each reach an empty scene.
- [x] Run it and observe failure because menu is absent.
- [x] Implement project, menu, blank scene and vector decoration; bundle font and license.
- [x] Run the full headless test; capture and inspect rendered menu at default/minimum sizes and blank scene. Fix material defects.
- [x] Document run/test commands and validation limits; review final changes and commit reset plus menu as `feat: start Ștefan with a medieval main menu`.
