# Răzeș implementation design

The user-provided MVP Design Brief v0.1 is the product authority. The subsequent instruction “ok, lets implement the plan” authorizes implementation. Use the existing isolated checkout.

## Outcome

A playable browser household strategy game: three adults, four deliberate seasonal turns, deterministic resource management, remembered promises, a complete ending, and versioned local saves. English interface with Romanian names. Attractive layered 2D visuals belong to this deliverable. No server, accounts, external AI service, second year, combat, or deployment.

## Architecture

Vite + strict TypeScript, Phaser 3 for the scene, conventional HTML/CSS for all interaction. A pure rules module owns authoritative state and validates actions. Content and tuning are typed data. Scene animations never mutate state. The UI commits reducer actions and saves snapshots; repeat clicks use an expected revision so stale actions are rejected.

State tracks version, revision, season (0–3), phase (opening/work/consequence/summary/ending), food, money, house, three named workers, assignments, agricultural flags, ox outcome, trust, named memories, history, hardship and seasonal summaries. Work is previewed without mutation. Confirm applies tasks once, then presents the consequence event; committing that event applies consumption and wear once. Continue advances the season. An explicit autumn honour action reserves one named worker; no second labour deduction.

## Initial balance (centralized, subject to playtesting)

Start: 18 food, 12 money, 55/100 shelter. Seasonal food consumption: 9. Spring seed: 4. Repairs: 3 money, 20 condition. Paid work: 6 money. Supplies: 4 money, 7 food. Wear: 6/5/8/14. Winter consumption +3 if shelter below 40. Crop: 20 base harvest, +10 for ox, +8 if tended; harvest needs two adults. Help needs one adult. Seed reserve target 4. Crisis: any food deficit or final shelter below 20; secure: no hardship, food at least 4 and shelter at least 40; otherwise survived at a cost. Money never negative; food clamps to zero after recording deficit. Three equal workers; personalities through dialogue.

## Content and interaction

12 authored event definitions with conditional selection: one opening and consequence each season (8/run). Mandatory ox chain: spring borrow/pay/decline; autumn honour/break if borrowed; winter assistance depends on memory. Inheritance/brother/spouse choices affect resources, dialogue and ending. Explicit costs and commitments, disabled unaffordable choices. Named journal entries and three highlighted ending decisions.

Observe → opening event → assign/revise → preview/confirm → consequence → consumption/wear → summary → next season → ending. Every scene hotspot has an equivalent labelled control. Keyboard focus, reduced motion, mute and a gesture-started procedural ambient soundtrack. Save after every accepted action (including work drafts), explain invalid/incompatible saves, offer deliberate restart. Storage failures show a warning without losing the current run.

## Visual approach

Original layered storybook vector art: wooded hills, seasonal ground and field, house and barn, fence and stores, five matching portraits/figures, smoke and seasonal particles. Warm parchment UI, deep forest green and muted terracotta; serif editorial headings. Fixed elevated view; no walking simulation. Four palettes, distinct field states, damaged/repaired roofs and visible food stores. Spring establishes the composition used for subsequent seasons. Historical exactitude and final period-specific asset review remain outside this first implementation.

## Validation

Vitest: bounds, invalid assignments, agriculture, ox paths, exactly-once actions, ordering, consumption, endings, save validation and exhaustive feasible one-year paths. Playwright: complete years, reload, invalid saves, keyboard, reduced motion, all seasonal scenes and no browser errors. Build and strict type checks. Actual timing and emotional success require the five-person playtest and cannot be claimed by automated checks.
