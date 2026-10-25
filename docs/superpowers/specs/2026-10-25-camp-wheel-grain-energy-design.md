# Camp wheel and grain energy

The user requests the existing action-wheel design for camp actions and each
grain's caloric value. Reuse action_wheel.gd through the existing camp_menu.gd
subclass: same rings, annular hit targets, icons, keyboard controls, edge fit,
outside dismissal and Game Over behavior. Camp shows Eat and Sleep, resetting
focus to Eat on opening. The existing food/sleep windows and command semantics
remain. Add original 64px gold bowl/spoon and bedroll/moon SVG icons.

Keep rendering/input shared. The base wheel provides small tooltip and summary
hooks; camp overrides its own effects and activation, without farm validation.
This avoids a second radial renderer or a new menu framework.

Store kcal_per_100g in Farm.CROPS: barley 354, oats 389, millet 378, wheat 327,
rye 338. Source: USDA SR28 cereal report (2015), dry edible portion, records
20004, 20038, 20031, 20072, 20062. Wheat uses hard red winter as a modern proxy.
These describe edible grain, not husks or wet cooked weight. The existing
processing abstraction means no new dehulling/milling losses; water adds no
calories. Do not claim verified medieval cultivars or complete nutrition.

Human.porridge(crop: String, grams: int) returns hours and calories from the
chosen crop. Preparation retains 30 minutes per 300g; energy = grams × the
crop's kcal_per_100g / 100. The preview, bag tooltip and completed meal share
that data. Preserve gram/fractional calorie precision and latched ingredient
through travel/cooking, with no food before completion. Remove the blanket
1,020-kcal meal constant. No saves, migrations, dependencies or commits.

Verify all five grains with literal expected energies, partial portions,
completed meals and UI selection. Test the actual camp wheel's mouse/key
paths, dead hub/outside dismissal, selection preservation, resize and death.
Run all nine suites and inspect GPU captures at normal/minimum sizes.
