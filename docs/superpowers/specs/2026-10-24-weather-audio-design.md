# Weather soundscape and controls

## Intent
Make the existing Godot field feel alive through varied wind, rain and winter ambience, with sound controls available in the menu and game. My proposed tone is peaceful in ordinary weather, with stronger storms.

## Approaches
- Recommended: bundle openly licensed field recordings and layer them with Godot audio players. Natural texture, offline playback, documented provenance; requires sourcing and listening checks.
- Generate all sounds: avoids recording selection, but realistic rain and wind are harder to achieve and assess.
- One loop per condition: simplest playback, but repetition works against the requested richness.

The user's “yes” is interpreted as agreement with the recommended recording approach. Exact assets remain an implementation choice, subject to verified redistribution terms.

## Sound and weather
- Wind plays softly in clear weather and varies through smooth gusts. Rain, storms and snow change its character and strength.
- Rain combines a continuous bed with intermittent drop/splash detail. Storms bring heavier rainfall and varied thunder after lightning, with bounded volume.
- Snow is quiet: hushed wind and gentle airy gusts, without pretending falling flakes make loud impacts.
- Use several compatible layers or variants, staggered starts and restrained gain variation. Crossfade weather changes; do not restart every game day. Audio follows real time so simulation speed does not accelerate sounds.
- Add smoothly changing wind strength/direction to precipitation and existing crop motion where supported. Keep the current weather probabilities, crop rules, seasons and lightning look.
- Suppress queued storm details when leaving a storm. Stop scene-owned ambience when leaving the field.

## Controls
A compact Sound button opens a keyboard-accessible panel in both menu and game. Provide master mute and master, weather and music volume sliders, with labels and percentages. Persist preferences in a separate user configuration file; no gameplay saves or migrations. Muting preserves slider values. Existing menu music routes through the music control.

## Scope and validation
Touch weather playback/effects, scene integration, shared audio preferences/controls, bundled assets and source notes, tests and user documentation. Use built-in Godot audio facilities without new dependencies. Verify asset import, weather transitions, lightning/thunder scheduling, controls and persistence, plus existing menu and crop tests. Listen to representative mixes and inspect the panel in the running app where available; report any listening or device checks not completed.

No new weather-driven crop penalties, music tracks, footsteps, building sounds, or full settings system. Retain the project's no-migrations rule. Existing menu music permission status is outside the weather asset selection.
