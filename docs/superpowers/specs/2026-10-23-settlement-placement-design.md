# Expandable settlement placement

The user requested a larger playing area, scroll/pan and zoom, a simple-house start, free placement throughout available ground, and building/construction debug controls. They explicitly included barn, well, stores and fences in the debug palette. Continue the existing inline implementation workflow.

Keep SwiftUI + SpriteKit on macOS 14+, with no dependencies. Use the existing textured isometric composition, expanded from 8×8 to 16×16 logical cells (32×32 material tiles). New households show the house and people; farmland becomes visible when worked. Existing saves retain their construction, draft work and legacy scenery through a backed-up schema-3 migration.

Use grid-based placement with visible green/red footprints, map-boundary and occupancy checks, and protected house/farm cells. A click places; Escape cancels. Normal woodshed/cellar plots can be positioned and moved before or after construction. Existing worker assignments, costs and next-season benefits remain authoritative. Positioning a plot alone spends nothing.

Camera: drag empty ground, right/middle drag, or scroll to pan; pinch or Option-scroll to zoom. Explicit zoom buttons and reset provide accessible alternatives. Clamp scale and camera movement, and suppress click selection after dragging.

Debug palette: place the four scenery types freely, spawn either functional building complete, finish a selected construction instantly, and clear debug scenery. Debug completion charges nothing and benefits start next season, recorded explicitly in the save. It does not resolve or rewrite seasonal history. Scenery has no resource bonus.

Approaches: one larger background would remain static; arbitrary pixel placement would complicate occupancy. Reusable material tiles plus a logical grid reuse the current projection and provide predictable placement. A custom engine or 3D port is outside this pass.

Persist layout in GameState so positions and construction remain atomic. Validate coordinates, counts, IDs, footprints, overlaps and building/layout relationships. Preserve v1/v2 bytes before replacement. Test migration, collisions, draft persistence, debug completion, camera bounds, zoom anchoring and drag-versus-click; inspect a new native household, placement rejection, pan/zoom and debug construction.
