# First human: a single farmer

## Intent and scope

The user chose a realistic single-person homestead, no village expansion,
and asked to add the human before vegetables. The agreed first loop is
movement, timed farming, carrying, simple food preparation, fatigue and sleep.
Preserve the current uncommitted 100 m² plot changes and unrelated export settings.

Updated by the user's follow-up: eating and rest are manual, there is no
starting flour, depleted energy drains health, and zero health ends gameplay
with a visible Game Over screen.

## Approach

Direct character controls would replace the current strategy controls. An
autonomous farmer instead carries out work ordered through the existing plot
selection, F key, buttons and action wheel. Use that approach as the default.
Keep deterministic state separate from rendering, following Farm's pattern.

## Simulation

- One adult, called Farmer, begins at a small camp just west of the field.
  No other people, relationships, skills, reproduction or village growth.
- Plot side is 10 m; coordinates and travel use metres. Existing scene units
  represent 5 m. A 1.7 m human and cereal heights use that same conversion.
- Default day length becomes 600 real seconds, with existing pause, 1×/2×/4×
  controls, F3 tuning and F4 skips. Start at 06:00. The HUD displays the hour.
  Simulation and animation pause together; daily weather/crop updates still
  occur once per day. Skips advance the person as well as crops.
- Farm commands enqueue eligible plots in selection order. One job per plot;
  duplicate, invalid and off-grid orders have no side effects. Queue at most
  the 256 plots. Costs are reserved on ordering, so subsequent orders and
  meals cannot spend the same seed. Waiting reservations remain at camp.
- Walk at 4,500 m per game hour. Per 100 m², plowing takes 3 hours, sowing
  0.5 hours and harvest 2 hours. These are initial game tuning, not verified
  historical work rates. Recheck stage, season and frost before committing.
- A sowing job collects its reserved seed at camp, carries it to the plot,
  then consumes it through Farm.act at completion. Unused carried seed comes
  home; cancellation immediately releases waiting seed and returns the person
  home with their carried stock. Failed/stale jobs cannot lose resources.
- Harvest goes into the person's bag, then into Farm.stock only on arrival at
  camp. Capacity is 15 kg, above the existing cereals' maximum plot harvest.
  Keep a one-line shortcut for extending haul trips before larger yields exist.
- Fatigue is 0–100. The camp Sleep follow-up replaces indefinite Rest/Resume:
  choose a duration, walk home, sleep for those hours and resume preserved jobs.
  Sleep recovers 20 fatigue points/hour and burns 60 kcal/hour, day or night.
  Preview needs/travel/death before confirming; Wake up ends sleep early.
  Hunger, exhaustion and night never start sleep automatically. See
  `2026-10-25-camp-sleep-design.md`.
- Food energy starts at 2,000 kcal. Use 60 kcal/hour sleeping, 90 idle/resting,
  160 walking, 220 working/cooking. Energy needs are game tuning informed by
  activity, not a medical or historical reconstruction. Camp → Eat opens grain
  and quantity selection; confirmation reserves an explicit porridge meal.
  300 g unreserved cereal takes 0.5 hours; calories use each grain's dry
  edible energy density and scale with the chosen amount. Repeated requests cannot duplicate a pending meal or
  spend reserved seed. See `2026-10-25-camp-food-design.md` for the follow-up.
- No initial flour or substitute provisions. Cooking water, firewood,
  milling losses and weather exposure are explicitly abstracted in this first
  loop, documented in code and wiki; do not claim a complete survival model.
- Energy can become negative. At depleted energy, health falls by 2 per game
  hour, charged only for time after depletion. Zero health stops the entire
  simulation at the exact death time, including during long skips. A centred
  Game Over screen offers Restart/Enter; no other input can resume play. No saves
  exist and no migrations are needed.

## Presentation and controls

An original low-poly human has a linen-coloured tunic, dark trousers, boots,
belt, head, hair, hands and a carried sack. Animate walking, work, resting and
sleep using the same rig. A small marker helps locate the person at field zoom.
Clothing is an artistic interpretation, not a verified 1495 reconstruction.
The camp has a bedroll, cooking pot/fire and grain sacks, with no building UI.

A small Farmer panel shows activity, progress/queue, fatigue, food energy,
health, reserved seed and carried grain. Focus (H) moves the camera to the
person; G focuses camp and opens its Eat/Sleep menu. R configures sleep or
wakes early; Backspace clears jobs. The HUD offers Wake up during pending sleep.
Existing field camera and selection controls continue to work. The inventory
remains the grain store; the panel explicitly shows food and grain in transit.
Time and needs continue while the wheel is open. Explain queuing in tooltips.

## Verification

Test real model behavior: no instant work, walking before work, exact seed
reservations, duplicate/refused commands, cancellation, stale season/stage,
harvest in transit before deposit, timed sleep and early waking,
explicit cooking, negative energy, exact death timing, and frame subdivision.
Test scene actions via actual input,
pause/speed/debug skips, person focus and the changed crop UI expectations.
Run all existing suites; inspect real GPU captures at normal/minimum sizes,
zoomed human poses, working crops, the camp and inventory/ledger overlays.
