# Ion Survival and Skills

Approved in chat on 2026-10-23. Native Mac only; no save migrations or new dependencies.

## Rules

- Health/energy start at 100, hunger at 0; all range 0–100.
- Work rewards precede a weekly meal of 1 food. Winter month end adds 1 for shelter below 40 and subtracts 1 for an active woodshed.
- Physical work costs 20 energy; wages/provisions cost 10. Health below 25 adds 10. Rest always remains available, restoring 35 energy or 25 with winter exposure.
- Missing food adds 25 hunger per unit; a supplied week removes 25. Hunger at least 75 damages health by 15; winter exposure damages it by 10, stacking. Rest heals 10 when neither damages health.
- Use post-repair, pre-weathering shelter and beginning-week building benefits. Zero health ends the run with its final report/date.
- Farming, gathering and building start at level 1. Productive weekly work grants 1 XP, capped at 12; each 3 XP raises a level to maximum 5. Starting-week level determines gains.
- Each level above 1 adds 2 harvest food, 1 gathered unit before storage limits, or 5 shelter repair. No XP from ineffective repairs, full-storage gathering or instant actions.

## Implementation tasks

1. Add shared character state/outcomes and pure weekly rules; integrate forecasts, resolution and skill-adjusted gains. Prove meals, energy, recovery, skills and death.
2. Add schema 10 and settlement-v10.json, validating character/report/death consistency and skill-aware hauls. Preserve restart recovery protections; no migrations.
3. Integrate terminal action guards, character HUD/inspector, forecasts/reports, restart and animation changes. Keep inspection, camera and help available after death.
4. Update obsolete shortage fixtures and help/docs. Prove a three-year survival routine, starvation/exposure, persistence, session and scene behavior. Run full native tests and packaging; inspect minimum-size UI and reduced motion.

## Validation focus

Forecast/resolution equality; first-week level-up rewards; pre-wear winter exposure; capped storage XP; rejected actions leaving saves untouched; death report surviving reload; restart failure retaining the run; strict malformed-save rejection.

## Execution notes

Work in the requested checkout on codex/ion-survival-skills. No commit, push or PR is required. Progress and verification logs are in /tmp/razes-survival-*.

## Validation completed

- 113 native tests pass: 60 core and 53 Mac. The three-year routine survives with matching forecasts and save round-trips.
- Debug and Release app packaging, resources and local signatures pass. Swift formatting and diff checks pass.
- Independent read-only review found no actionable issues.
- Live validation with isolated temporary saves exercised normal weekly recovery, forecast/report agreement, fatal confirmation, the death report, disabled Build/Debug controls, restart confirmation and restart. Escape closes the inspector. HUD and inspector expose numeric accessibility values.
- Inspected 1000×700 captures of the HUD and planning/fatal/death panels. These offscreen captures exclude the Metal-backed SpriteKit scene; scene behavior and reduced-motion/death transitions have separate tests.
- Full VoiceOver traversal, a complete physical-keyboard pass, Intel/macOS 14 hardware and player balance remain unverified.
