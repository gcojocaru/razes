# Ștefan main menu

Approved by the user: 24 October 2026 ("yes, do it").

Create a Godot desktop application showing a dark parchment menu, restrained gold
ornament inspired by medieval Moldavian manuscripts, the title ȘTEFAN, one Play
button, and v0.1.0 in a bottom corner. Activating Play by mouse or keyboard changes
to an empty black game screen. No gameplay, saves, extra menus, sound or animation.
Lettering and ornament are artistic interpretations, not certified period artifacts.

## Approach

Use Godot Controls and a bundled openly licensed ornamental font, with scalable
vector decoration. This keeps text and the button accessible to keyboard input
and avoids raster title artwork. A painted background was considered but adds
asset weight without helping this first slice. Reuse the retained Godot engine
configuration selectively, without reviving the old simulation or assets.

Version comes from project settings. Keep title, button and version readable at
1000×700 and larger; use stretch mode for proportional layout. Play receives
initial focus and a visible focus style. The empty game scene has no visible UI.

Include the approved workspace reset and this new application in one local
commit; preserve Git history and origin. Do not push or rewrite history.
