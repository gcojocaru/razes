# Rotation, infrastructure and seasonal construction

The user requests building rotation, rotation of the whole isometric map, player-built pavement/fences, debug seasons and instant upgrades/repairs. They explicitly selected moving ALL building progression to seasonal turns.

Use four quarter-turn map views; HUD/text remain upright. Persist map orientation and individual building/scenery facing. Projection and inverse placement, ground, depth, people, fields, markers, effects and fences use the same rotation. Front/rear painted sprites and horizontal mirrors provide four consistent directional views. Preserve existing art and add a rear-view atlas; this remains 2D, not a 3D camera.

Pavement costs one free coin per tile; fences cost one per edge. Repeat click/drag placement paints connected runs, cannot spend coins reserved for seasonal work, and rejects buildings/protected ground/out-of-bounds. Pavement and edge fences may coexist. Equivalent opposite edges are one fence. Erase removes pavement and surrounding fence edges without refunds. Preview and R/rotate controls share the committed facing.

Building construction pays immediately and completes at the end of the current story season. Existing completed buildings produce their level-scaled catalog yield once per season and lose 20 condition after seasonal consumption. At zero they lose one level and return to 60 condition; level 1 remains inactive. Upgrades and repairs apply immediately for their existing prices, with no timers. After the first-year ending, a Next settlement season command cycles building-only seasons for ongoing construction/production/wear; the authored year and worker history remain intact.

Debug season preview overrides visual weather/ground/art only and is clearly labeled. Clearing it restores the actual story/settlement season. No clock-based production, catch-up, construction, repairs or degradation remain.

Schema 5 preserves v1–v4 original bytes before first replacement. Paid v4 upgrades/repairs complete during migration; pending builds become seasonal foundations. Validate the old timer data before conversion. Discard old fractional production (less than one former minute), retain all resources/levels/condition/plots/history. New fields have explicit migration defaults. Reject malformed rotations, extreme coordinates, duplicate roads/fence edges and impossible progression.

Keep macOS 14+, current SwiftPM packaging, browser source untouched, no new dependencies, and use an isolated test household for native proof.
