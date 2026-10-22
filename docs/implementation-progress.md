# Implementation progress

Plan: docs/superpowers/plans/2026-10-21-razes-mvp.md

- User authorized implementation after supplying the design brief. Proceed with proposed browser/English/art defaults and implement inline.
- Existing checkout is empty, isolated, on unborn `work` branch. No AGENTS.md found.
- Preflight: tasks 1→2→3 share GameState and reducer; task 3→4 uses DOM role/label interfaces. No conflicting interfaces.
- Art decision: original layered vector illustrations, with painterly grain and seasonal palettes; final historical reference pass remains separate. Risk: art preference needs real player feedback.

- Task 1 complete: 22 rules tests pass, including four ox paths and eight encounters per completed run. Test itinerary corrected to earn wages in the free autumn slot after paying for the ox; the original itinerary overspent in winter, and the engine correctly rejected it.
- Task 2 complete: save tests cover every phase, invalid data and storage exceptions. No effects execute when loading.
- npm cache uses /tmp/razes-npm-cache because the image's default cache directory is not writable.
- Task 3 complete: layered original SVG art loaded into Phaser; DOM controls, journal, preview, audio and motion controls connected. Browser regression caught Phaser treating non-base64 data URLs as base64; switched the loader input to actual base64. Seven browser tests passed, including all four complete ox paths.
- Visual review increased explanatory text sizes for normal-zoom readability.
- Added regression coverage and corrected autumn preview to include Petru’s two food (already applied at resolution). Help tasks now leave named journal memories, including the reserved autumn task. 47 unit tests pass.

## Final verification

- Task 4 complete: `npm ci --cache /tmp/razes-npm-cache --no-audit --no-fund` reproduced the installation; `npm run build` passed TypeScript and production bundling; `npm run format:check` passed.
- Final unit suite: 52 tests passed, including 400 varied legal years with snapshot round trips after every action and coverage of all twelve event definitions and eight task types.
- Final browser suite: 10 tests passed in 1.4 minutes. All four ox paths finish, save, resume and restart. Also verified malformed-save recovery, dialog keyboard/focus, reduced motion, six nonblank seasonal/condition/store scenes, laptop overflow and persistent resources/current season while scrolling.
- Screenshots inspected at desktop and 1024×768 laptop sizes. `docs/preview.png` is captured from the final browser run.
- Independent review identified two important save invariant gaps: chronological event validation and season/task/reserved-worker validation. Four regression tests reproduced those cases before the fix and passed afterward. The complete suite passes with the fixes. No unresolved important review findings.
- A test-run artifact collision occurred when two Playwright commands used the same output directory. That run was not counted as passing; the final full suite ran alone and passed.
- The final scrolling regression exposed hidden resource/season indicators while assigning work; fixed with sticky desktop indicators, then verified the failing test and full suite.
- Saved tested `install_script` and `start_skill` in the environment draft. Publication and fresh-task restoration are user-controlled and unverified.
- Scope decisions: use the brief's browser-first and English-first defaults; original layered textured vector art establishes the storybook composition. Final painterly refinement and period-specific historical review remain art work. Potential cost: visual preferences may change after playtesting.
- Remaining product validation: the five-person playtest, real 20–30-minute pacing, replay intent and balance tuning. Automated runs do not establish those outcomes.
- Work remains in the existing isolated `work` checkout for review. No merge, push or deployment performed.

## Painterly visual pass — 21 October 2026

Implemented the user's selected visual priority: four matching painted landscapes, separate seasonal structures and field stages, five matching figures/portraits, visible provision levels, task tools and work motion, breathing, smoke, and seasonal particles. The actual event speaker controls visitor identity. Reduced motion freezes optional movement; state changes still render. Rules and save format are unchanged.

Verification: 57 unit tests, 11 browser tests, production build and formatting passed. Browser checks include all four ox paths, save/resume, six seasonal/state screenshots, laptop controls, asset loading, and canvas equality with reduced motion enabled and toggled. Reviewed spring, summer, autumn and winter screenshots. Updated `docs/preview.png` and documented asset provenance. Original PNGs total approximately 25 MB; first-load optimization and historical reference review remain. Balance audit and five-player playtesting remain pending.

## Ox balance and historical grounding — 22 October 2026

Audited four ox routes with eight narrative profiles using the production rules, legal task enumeration and resource-dominance pruning. The paid route had no globally nondominated secure resource outcome at a six-money hire in any profile. Lowering hire to five gives every route a distinct secure resource outcome in each profile. Added eight matched-plan regressions (all four routes in each) plus an old six-money snapshot check. Existing savings are preserved rather than retroactively repriced. No other tuning changed. The full reproducible analyzer, method limitations, source hashes and results are in `docs/audits/`.

Completed a first focused historical reference pass using inspected dictionary, National Heritage Institute and museum pages. Selected northern Moldavia in 1495 as the fictional reference setting. Updated Petru’s shared-inheritance dialogue, separated his personal purse from land rights, and made Dumitru a mediator of a witnessed local agreement. The ox payment now explicitly means use rather than purchase of the animal. Updated footer/help/metadata and removed the unsupported fixed household surname. `docs/history/1495-reference-guide.md` documents sources, confidence limits and exact art-reference gaps. Clothing, buildings and tools remain historically unverified illustrations; no new art was generated in this pass.

Verification: 66 unit tests, 11 browser tests and production build passed. Repeated the full audit matrix against the final rules with in-memory prices 6 and 5; 455,942 candidate seasonal work plans were evaluated across retained states, not that many complete playthroughs. No human playtest has occurred. A specialist material-culture review, image-load optimization and the five-player playtest remain.
