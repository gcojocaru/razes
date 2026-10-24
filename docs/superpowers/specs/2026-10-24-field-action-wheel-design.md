# Contextual field action wheel

## Intent

Replace the Godot crop popup with a contextual, segmented wheel so players can
see and perform the actions their selected land currently allows. Each action
has a distinct icon, a readable name, and its affected plot count and seed cost
or harvest yield. Use the existing ink, parchment, and gold HUD style.

## Approaches

- A: separate orbit buttons. More room for labels and a smaller single-action layout.
- B: a segmented ring. Larger continuous targets and a stronger wheel appearance.

The user selected **B** after trying the browser comparison.

## Behavior proposed for implementation

- Right-click opens the wheel at the pointer, shifted inside the viewport when
  necessary. Clicking an unselected plot first selects it; clicking a selected
  plot keeps the existing group selection. Right-drag continues to rotate.
- Grass, stubble, and withered crops offer Plow when permitted.
- Plowed land offers a separate Sow action for each crop that can be planted
  now with the available seed. Use distinct crop icons and names.
- Ripe crops offer Harvest. Growing crops show their crop and growth in the hub.
- Mixed selections offer every applicable action, with counts and costs for only
  the plots it affects. A chosen crop is remembered as it is today.
- Omit unavailable actions. When nothing can be done, explain why in the hub,
  such as frozen ground, missing seed, next sowing season, or crops not yet ripe.
- The hub describes the selection; hovering or focusing a segment describes its
  effect. A single action occupies the ring around the hub, as shown in B.
- Left-click or keyboard activation performs one action and dismisses the wheel.
  Arrow keys cycle actions, Enter activates, and Escape or an outside click
  dismisses without working or changing the selection.
- C and the existing crop-picker button open the same contextual wheel above the
  bottom HUD. Existing direct action buttons and F remain available.
- Refresh availability while open as days and stocks change; validate again on
  activation using the existing farm rules. Menu input must not reach the field.

## Scope and verification

Reuse Farm.action, Farm.preview, and Farm.work; gameplay rules and save data do
not change. Work reaches the menu control/icons, farm HUD, game input routing,
crop/menu tests, README, wiki instructions, and validation notes. No dependencies,
nested wheels, or hold-and-flick gestures are needed.

Check land states, mixed selections, seed shortages, season changes, selection
preservation, keyboard activation/dismissal, viewport edges, and right-drag
rotation. Visually verify icon and label legibility in the running Godot game.

Approved by the user with “lets do it”; implemented in this worktree.
