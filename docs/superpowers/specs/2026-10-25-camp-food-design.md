# Camp food preparation

The user specified: click the camp, choose Eat from its context menu, then
choose an inventory ingredient and grain quantity to prepare porridge.

Use the existing inventory's bag visuals and shared HUD-window style. Extract
its bag slot into a reusable Button used by both inventory and food selection;
the bag renderer remains unchanged. The camp uses the shared segmented action wheel for Eat and Sleep (updated by the camp-wheel follow-up).
Left click and right click open it; G focuses camp and opens the same menu for
keyboard access. Selecting Eat opens Prepare food; Escape closes either view.
Camp clicks do not change field selection, and outside menu dismissal does not
issue field orders. Right-drag retains camera rotation.

The food window shows available grain, the selected crop, a whole-gram quantity
(default 300 g), and porridge calories/time before Prepare & Eat Porridge.
Only existing unreserved grain is available. Choosing or closing spends
nothing. The confirm action rechecks the current stock, chosen crop and
positive integer grams, reserves exactly that amount and sends the farmer to
camp to prepare and eat it. No direct Eat control remains in the farmer HUD.

Preparation takes 0.5 game hours per 300 g; calories use each grain's dry
edible energy density from Farm.CROPS (see the camp-wheel/grain-energy spec). One pending meal at a time. Reserved meal
grain cannot be spent on fields, and meal output appears only on completion.
Do not introduce other recipes, prepared-food storage, water/fuel systems or
new starting food. Sleep stays manual (see `2026-10-25-camp-sleep-design.md`)
and Game Over freezes all new controls.

Model interface: `eat(farm: Farm, crop: String, grams: Variant) -> bool`;
`porridge(crop: String, grams: int) -> Dictionary` provides `hours` and `calories`. Public
`meal_crop` and `meal_grams` describe the reserved pending meal. Reject malformed,
zero, negative, insufficient and duplicate requests without spending resources.

Verify with model tests and actual camp/menu/window input: selection, fractional
kilograms, quantity commitment, opening/closing without consumption, stale stock,
reserved seed, repeated confirmation, keyboard access and Game Over. Inspect
GPU captures at normal and minimum window sizes. Preserve existing edits and
foreign export settings; no saves or migrations.
