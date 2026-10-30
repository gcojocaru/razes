# Ștefan

A fresh Godot desktop game, starting with a medieval Moldavian inspired main menu.
Select **Play** or press **Enter/Space** to create your peasant and choose the land, then **Begin**
(or **Enter** in the name field) to open the strategy field: a 16×16 grid
of 10×10 m plots (100 m² each, 2.56 hectares in total).
Hover or click a square to highlight or select it. Move with WASD/arrows, rotate
with Q/E or right-drag, zoom with the mouse wheel or trackpad pinch/scroll. Time runs at one day every
10 minutes at 1×, starting at 06:00 (a year is 4 seasons × 3 months × 4 weeks × 7 days); Space pauses and
1/2/3 pick 1×/2×/4× speed. In debug builds, F3 opens a panel to set the day length.
Each day rolls seeded weather (Clear, Cloudy, Rain, Storm, Snow) and a temperature
tuned to modern Moldovan (Chișinău) climate normals, with multi-day warm, cold,
wet and dry spells. Rain and snow fall as particles, storms flash lightning, and
fog, sky, sunlight, wet ground and lying snow blend in as the weather turns.
The sun follows its path at Chișinău's latitude: spring and autumn begin at the
equinoxes, with sunrise at 06:00, and days last 15.7 hours at midsummer and 8.3
at midwinter, so shadows lengthen and swing through the day. Dawn and dusk tint
the sky gold and violet, a full moon opposite the sun lights the night, the camp
fire glows and flickers in the dark, and the time panel shows the moon on clear
nights.

Each new game generates playable hills and ponds inside the field from the land
chosen before it starts: **Steppe** (hills up to 7 m, one pond: the most
farmland), **Hills** (18 m, two ponds; the default), **Lakeland** (11 m, four
ponds: the least farmland) or **Custom** (0–24 m and 0–4 ponds). Farm dry,
gentle slopes as usual; water, wet banks and steep plots show why they cannot
be worked. The farmer follows dry routes around ponds for jobs, hauling, meals
and sleep. A new game first pauses for you to click dry, gentle ground for the camp;
the camp menu's **Move** shifts it until a permanent shelter is completed (Escape cancels). People, crops, picking and the camera follow the terrain. The ledger lists
usable plots and water; the field covers 2.56 hectares, with its farmable area
varying by land and seed. Each start uses a fresh seed, with repeatable terrain
for a given seed and land; **Restart** keeps the land on a fresh seed.

Woodland now grows in seeded groves on about a quarter of usable plots. Select
wooded plots and choose **Chop** in the field wheel, the axe button or **F**.
Six game hours clears a plot and leaves **240 kg of usable wood** on the ground;
the farmer then hauls it home in trips of at most **15 kg**. Ground piles and
carried logs cannot fund construction or cooking. Cancellation keeps unfinished
chopping and remaining piles; **Haul wood** resumes collection. Once the pile
is gone, farm the cleared grass normally. Unused cleared grass regrows woodland
after two game years; cultivation and camp occupation keep it clear. Trees are
walkable and use the terrain's metre scale, seasonal leaves, wind and snow.
Their models and texture licenses are in [woodland credits](godot/assets/woodland/SOURCE.md).

Plowing and chopping keep their progress per plot when interrupted, including
**Clear jobs**. Select a plot to see its percentage complete and work hours left;
order the same work again to resume. Progress lasts for the current game only.

At camp, **Build shelter** reserves **300 kg wood** for **8 hours of work**.
Meals, sleep and recovery preserve its progress and queued field jobs. Clear
jobs cancels unfinished construction and returns its reserved wood; moving an
unfinished camp does the same. The completed timber hut becomes permanent.
Its roof keeps rain and snow off, reduces wind and cold exposure, and shades the
farmer. Comfortable sleep clears full fatigue in **6 hours** inside, **8 hours**
outdoors. Its roof and walls fade while the farmer is home so the interior stays
visible. The hut is an artistic interpretation inspired by a Romanian pastoral shelter.

You begin with **48 kg wood**. Camp heating is enabled and burns **0.5 kg per
game hour only while the farmer is home**. Toggle **Heat on/off** in the camp
wheel; turn it off in hot weather. **Eat** reserves grain and cooking fuel
atomically: a 300 g portion takes 30 minutes and 250 g of wood, sharing its
fire with heating. A fractional-gram burn remainder retains precision. **Cancel
pending meal** in Prepare food refunds unprepared grain and unused reserved
fuel. Clear jobs preserves pending meals. The camp shows wood and burn duration;
the flame and light extinguish when fuel runs out. Time controls pause fuel too.

The farmer now gets wet and cold or overheats. The panel and **Body** show core
temperature, wetness and exposure health. Hourly temperature varies around the
daily crop mean; weather, wind, exertion, sweating, body mass, shivering, shelter
and fire affect thermal balance. Cold costs extra calories. Warnings begin below
36°C or above 38°C; damage begins below 35°C or above 39°C. Both starvation and
exposure can end the game. These rates are game tuning, not medical predictions;
[exposure notes](docs/historical-research.md#exposure--26-october-2026) record assumptions.

**Recover** in the camp wheel preserves work and returns home to rest until wetness
is at most 10% and temperature is 36.5–37.5°C. It provides no sleep bonus; **R** or
Stop recovery ends it early. Recovery may need a roof, wood, or heating switched
off. Warnings never automatically abandon work. Sleep previews now replay the
actual walk, future weather, shelter and fuel exhaustion and show temperature,
wetness and remaining wood. Clothing choices remain cosmetic; water, diet quality,
illnesses and individual cold injuries are still abstracted.

Farming is the farming loop. Click a plot or drag over a rectangle of
plots; hold **Shift** to add to the selection. Without a mouse, move the view
and press **Enter** to select the plot at its centre (**Shift+Enter** adds). The
farm panel shows illustrated icons for each action the selection allows; hover
for plot counts and the kilograms of grain it costs or brings; **F** queues all of them. Plow grass, stubble or
dead crops (not in winter), sow plowed land, and harvest ripe crops. Sowing uses
the crop pictured on the sowing icon, whose tooltip names it and lists its needs.
Right-click a plot, click the **Actions** wheel icon, or press **C** to open a segmented action
wheel. Right-clicking a plot selects it unless it is already in the selection.
The wheel offers **Plow** on grass, stubble and dead crops; individual crop
icons on plowed land; and **Harvest** on ripe crops. It shows only actions that
can be done now, with plot counts and seed costs or harvest yields in kg. Growing
crops, frozen ground and seed shortages show an explanation instead. Mixed
selections offer work for each eligible part of the selection.
Click a segment, or use arrows/Tab and **Enter**. Choosing a crop queues sowing and
remembers it for the sowing icon and F. **Escape** or an outside click dismisses
the wheel; a right-drag still rotates the view. Time continues while it is open,
and availability refreshes as days change.

One **Farmer** carries out these orders. **H** or Focus finds them; **G** opens
the camp menu, **R** opens Sleep (or wakes the farmer early), **B** or Body
opens the Body window, and **Backspace** or Clear jobs cancels work.
The Farmer panel shows activity, work left, energy, stomach, weight and BMI,
fatigue, health, reserved seed and their carried grain. Orders reserve seed immediately;
the farmer collects it at camp, walks to the plot and completes the work before
the field changes. Duplicate orders on a plot are ignored. Plowing takes
3 game hours per plot, sowing half an hour and harvesting 2 hours. Harvested
grain travels in the farmer's sack before it reaches the store; cancelled or
unusable seed is returned. These are initial manual-work tuning values.

Eating and resting require your command. The farmer does not stop work for
hunger, exhaustion or night. Click the camp to open the same segmented action
wheel used for fields, with **Eat** and **Sleep** icons. Choose **Eat**, then select a grain
bag and a quantity in whole grams in the inventory-style **Prepare food** window.
It previews calories, preparation time and stomach room. **Prepare & Eat
Porridge** reserves exactly that grain and sends the farmer to camp to cook and
eat it; the porridge then fills the stomach and digests into energy. A 300 g
portion takes half an hour; time scales with quantity, and calories also depend
on the grain. A meal must fit the stomach, at most 375 g of grain when empty.
Only unreserved grain is available, with one meal pending at a time. Opening or closing the window spends
nothing. **G** opens the same camp menu; **Escape** closes the menu or window.
There is no starting flour. Arrows/Tab and Enter choose either wheel action;
the first focused action is Eat. The hub/outside click dismisses it.

| Dry edible grain | kcal per 100 g | kcal in 300 g porridge |
| --- | --- | --- |
| Barley | 354 | 1,062 |
| Oats | 389 | 1,167 |
| Millet | 378 | 1,134 |
| Wheat | 327 | 981 |
| Rye | 338 | 1,014 |

These are modern reference values from [USDA SR28, cereal grains](https://www.ars.usda.gov/ARSUserFiles/80400535/Data/SR/SR28/reports/sr28fg20.pdf),
using hard red winter wheat as the wheat proxy. Bag tooltips and the food
preview show the selected grain's calorie density; meal output uses the same
data and retains fractional calories. Added water contributes no energy.
Quantities stand for dry edible grain; dehulling/milling losses are abstracted.
See [nutrition source notes](docs/historical-research.md#grain-calorie-reference--25-october-2026).

Choose **Sleep** in the camp menu to enter the hours you want to sleep (up to
24, with quarter-hour controls). Its live preview shows restedness, energy,
weight, health and total time including the walk to camp. Eight comfortable hours outdoors or six in the shelter
clear a full day's fatigue; sleep burns basal metabolism and creates no calories.
Confirmation preserves field work, walks home and sleeps for the chosen hours,
including during daytime. Work resumes when that time ends; **Wake up** or
**R** ends sleep early. Opening or closing the window starts nothing. Finish a
pending meal before sleeping, and wake before preparing another meal.

Peasant creation opens over the menu, its music still playing. Name your peasant
(up to 24 characters; a blank name cannot begin) and choose the body the needs
below run on: height 1.55–1.85 m, weight in whole kilograms from a BMI of 18.5
(full health) to 30 at that height, and 8–30% body fat. A summary shows BMI,
lean and fat mass, basal metabolism, ready energy and an hour of hoeing: lean
mass raises the metabolism and holds more ready energy, fat lasts longer without
food, and every kilogram makes walking and work dearer. Looks are skin, hair,
beard (none, moustache or full) and clothes, beside a turning preview at the
chosen height and build. Under **Land**, a preset shows its hills and ponds on
locked sliders; **Custom** unlocks them. **Escape** or × returns to the title. The name heads
the Farmer panel and floats above the farmer, who widens or thins as their
weight changes; the Body window measures change from the chosen start, and
**Restart** keeps the same peasant. Choices are not saved between launches.

Needs follow from a simulated body, by default 1.72 m and 65 kg with 15% body fat (BMI 22).
Lean mass sets basal metabolism (Katch–McArdle, 1,563 kcal a day) and each
activity burns a multiple of it (FAO physical activity ratios): sleep 1.0, idle
1.4, cooking 2.1, walking 3.2, sowing and harvesting 4.1, hoeing 5.0. Moving
adds about 1 kcal an hour per kilogram moved for each step above rest, so a
heavier body or a load costs more. The stomach holds 375 g of grain as
porridge, and the gut absorbs at most 2.5 times basal metabolism (Thurber et al.
2019), about 160 kcal an hour, into glycogen, the ready energy (about 2,000
kcal); work harder than that runs the body down. A surplus is stored at two
thirds efficiency, two thirds of the gain as fat, so 84,000 kcal of overeating
adds about 8 kg; a deficit burns fat and lean tissue by Forbes' rule. Weight and
BMI change with both. The Body window (**B**) shows build, change since the
start, stores, tiredness and each activity's cost, live. Health is full down to
a BMI of 18.5 and gone at 12.5: an idle
farmer with no food dies after about two months, as in the 1981 hunger strike.
Sixteen idle hours awake build 70% fatigue and a day with nine hours of hoeing
100%; eight hours of sleep clear it. From 70% fatigue the farmer works and walks
at 80% pace, from 90% at 60%. At zero health a centred **Game Over** message
appears and gameplay, time and debug skips stop. Restart or Enter begins a fresh
farm. F4 skips otherwise advance the farmer as well as the crops. Pause stops
both; weather audio continues. Water, hulls and milling losses,
diet quality and illnesses are still abstracted, and the fatigue and pace
figures are game tuning. See the
[body sources](docs/historical-research.md#body-and-needs-model--25-october-2026).

The person and cereal heights share the plot's metre scale; **H** zooms in to
make the farmer easy to see. The camp, clothing and the creation screen's skin,
hair and cloth colours (such as madder red and woad blue) are original low-poly
art, not a verified reconstruction. The grass outside the grid grounds the camp
and cannot be farmed.

| Crop | Sown | Grows above | Needs | Dies at | Seed → harvest a plot | Bag |
| --- | --- | --- | --- | --- | --- | --- |
| Barley | Spring months 1–2 | 4°C | 60 warm days | -3°C | 2 → 7 kg | 45 kg |
| Oats | Spring months 1–2 | 4°C | 75 warm days, likes rain | -4°C | 1.6 → 5.6 kg, copes with poor soil | 32 kg |
| Millet | Spring month 3 – Summer month 1 | 10°C | 50 warm days, hardy in drought | 1°C | 0.3 → 4 kg | 50 kg |
| Wheat | Autumn months 1–2 | 3°C | a winter, then 110 warm days | -8°C | 1.5 → 7.5 kg, wears soil most | 55 kg |
| Rye | Autumn months 1–3 | 2°C | a winter, then 95 warm days | -16°C | 1.6 → 6.4 kg, copes with poor soil | 50 kg |

Across 50 weather seeds, barley ripens in early summer, oats mid-to-late
summer, millet late summer to early autumn, rye the next early summer and wheat
after it; about one winter in five is cold enough to kill wheat. Each crop has
its own store: sowing uses that crop's grain as seed and its harvest goes back
to it. Grain is shown in kilograms, accurate to one gram: a plot is 100 m², sown at
medieval manor rates of 2–4 bushels an acre (130–215 kg/ha; millet, sown thin,
30 kg/ha). You start with last year's grain: 50 kg of barley, 40 of oats and
rye, 37.5 of wheat and 9 of millet, seed for 25 plots each and 30 of millet, and
the food to last until the first barley ripens, about day 110; the inventory shows
the total and each crop. Harvests vary with the season: each growing
day's rain or sun counts towards the grain, so most years give 70–110% of the
table's full harvest and a wet year up to a third more, oats fall to half in a
dry year and millet barely changes (50 weather seeds). On average that returns
three to five times the seed (490–690 kg/ha), as in medieval manor accounts and
18th-century Russian black-earth records, and millet about thirteen times. Select a growing plot and hover its status to see the kilograms it is on course
for. **I** or the Inventory button shows the store as an inventory grid of
grain bags: a bag holds about 70 litres, so 55 kg of wheat but 32 kg of oats.
Each is an open burlap sack rendered once as a small lit 3D scene
([`godot/bag_icons.gd`](godot/bag_icons.gd), cloth from `godot/sack.gdshader`),
with a heap of separate kernels and the crop's initial stamped on; a crop's
last, part-filled bag sits lower and wider. **Stats** toggles each crop's kilograms, bags, the plots it can
sow, and this year's sowing and harvest.
These cereals and numbers are game tuning, not verified crops or yields for
fifteenth-century northern Moldavia.

Land wears and goes wild. A harvest leaves stubble that must be plowed again,
and takes 25–35% of the soil's fertility depending on the crop; poorer soil
yields less, least so for oats and rye. Resting land recovers a quarter per
year, so cropping barley or millet every year halves its yield within about
nine years (oats fall more slowly), while resting one year in three holds it. Plowed land stays plowed;
stubble and dead crops left untended go back to grass after about 40 warm days.
Rain darkens the ground and leaves puddles in the furrows until it dries. **L**
or the Ledger button opens three tabs: Fields (each crop's plots, growth, soil
and expected harvest, plus idle land), Years (each year's sown, frost-killed and
harvested plots, kilograms gathered and net after seed, with per-crop detail on hover)
and Crops (each crop's sowing months and needs). In debug builds, **F4** opens
an agriculture window to add 100 kg of each crop, skip days, months or to the
next season, and set the crop, stage, growth and soil of the selected plots.

**F1** or the Wiki button opens an in-game wiki: controls, the year and weather,
working the land, how crops grow, a crop table, soil, the ledger and inventory,
and a first-year walkthrough. It shows [`godot/wiki/wiki.html`](godot/wiki/wiki.html),
which also opens in any browser; the game converts its headings, paragraphs,
lists, tables, bold, italics and keys to RichTextLabel BBCode, so the page keeps
to those tags. It is not a Godot resource, so an export preset must include
`wiki/*.html, assets/woodland/*.txt, assets/woodland/*.md` (Export → Resources →
filters to export non-resource files), so the wiki and bundled art licenses travel
with the game.

The field uses CC0 grass and ploughed-soil textures (see their
[sources](godot/assets/textures/SOURCE.md)); crops are instanced stalks sized
and coloured on the GPU from a per-plot data texture.
Current version: **0.1.2**.

The game autosaves each dawn and when the window closes to one slot,
`user://save.dat`. **Continue** on the title screen (focused when a save exists)
resumes it paused: the field, woodland, camp and hut, stores, the farmer's body,
exposure and unfinished jobs, on the same land, terrain and weather. Saves are
written beside the slot and renamed over it, so a failed write keeps the last
good save; an unreadable save is set aside as `save.dat.bad` and the menu offers
only Play. Death deletes the save. Restart and Play begin a fresh game, whose
first dawn replaces the old save. Saves from an older version are rejected, not
migrated, while the game is unreleased.

The menu loops **Drumul Dracului – (Moldavian Medieval Song)** from the
[user-selected recording](https://www.youtube.com/watch?v=HdnlsAkVnmk), at -14 dB.
Playback stops on Play. The track is bundled for offline playback; see its
[source and permission status](godot/assets/audio/SOURCE.md).

Wind, rain and winter ambience now play in the field, with long layered rain
recordings, changing gusts, smooth weather transitions and delayed thunder after
lightning. Wind also steers precipitation and crop sway. Sound continues at normal
speed while the calendar is paused or accelerated. **Sound** (top right) or **F10**
opens master mute and master/weather/music volumes in both menu and game; arrow
keys adjust focused sliders and Escape closes the panel. Preferences are saved
separately in `user://sound.cfg`. Weather recordings and licenses are documented
in [weather audio credits](godot/assets/audio/weather/SOURCE.md).

## Run

Use **Godot 4.7.2** with its Compatibility renderer. Open `godot/project.godot`
and press F5, or run from the repository root:

```sh
# First checkout: import bundled assets once.
./godot/run.sh --headless --editor --import --quit
./godot/run.sh
```

The launcher finds Godot in Applications, Downloads or PATH. Set `GODOT_BIN`
if your executable is elsewhere. No Node.js installation or network is needed.

## Verify

Import assets once after a fresh checkout (and after adding a `class_name`
script), then run the tests:

```sh
./godot/run.sh --headless --editor --import --quit
./godot/run.sh --headless --script tests/test_menu.gd
./godot/run.sh --headless --script tests/test_crops.gd
./godot/run.sh --headless --script tests/test_audio.gd

./godot/run.sh --headless --script tests/test_wheel.gd
./godot/run.sh --headless --script tests/test_human.gd
./godot/run.sh --headless --script tests/test_human_actor.gd
./godot/run.sh --headless --script tests/test_person_scene.gd
./godot/run.sh --headless --script tests/test_camp_food.gd
./godot/run.sh --headless --script tests/test_camp_sleep.gd
./godot/run.sh --headless --script tests/test_terrain.gd
./godot/run.sh --headless --script tests/test_terrain_scene.gd
./godot/run.sh --headless --script tests/test_terrain_human.gd
./godot/run.sh --headless --script tests/test_woodland.gd
./godot/run.sh --headless --script tests/test_shelter.gd
./godot/run.sh --headless --script tests/test_exposure.gd
./godot/run.sh --headless --script tests/test_woodland_scene.gd
./godot/run.sh --headless --script tests/test_save.gd
```

The menu test checks title spelling/font coverage, version, initial keyboard focus,
visible focus styling, layouts at three sizes, real keyboard/mouse activation
of Play and peasant creation (its fit at three sizes, typed and blank names,
weight limits per height, the body summary, swatch clicks, land presets, Custom
hills and ponds and their limit, and Escape), Begin into the grid field as the
chosen peasant on the chosen land and Restart keeping both, cell picking, camera rotation and pinch zoom, automatic menu music, loop wraparound and stopping
playback when the game starts. The crop test checks each crop's sowing months,
warmth, rain, frost and winter needs, the plow/sow/harvest rules, stubble, plowed
land staying plowed, returning grass, soil wear and rest, yearly records, that
action previews match outcomes and refused actions change nothing, harvest kg
by soil and season, bag filling, every crop's
ripening across 50 weather seeds, a nine-year rotation, and selection, the F
and Enter keys, the action wheel from C, the keyboard and right-click (and not from
a right-drag), each crop's own seed, ledger tabs, the bag inventory, the wiki
converter, that the wiki's crop table matches the game, the F1 wiki window, the
agriculture debug window and the field texture in the running game screen.
The wheel test also covers seed shortages, season changes, mixed states, live
refresh, keyboard activation and dismissal, and viewport-edge placement.
The human tests cover the body's metabolism, load, digestion and its daily
limit, fat and lean gain and loss, two-month starvation, refeeding, tired pace
and the live Body window, exact reservations and
refunds, timed work, walking, hauling, stale orders, timed sleep and meals,
death at the limit of survival, created bodies (their BMI, metabolism, death and
sleep forecasts at their own height), subdivision of time, physical mesh scale,
height, build, looks, bedroll fit and poses, and actual scene input, pause, focus, cancellation and debug skips.
The camp food test follows real camp clicks, menu and bag selection, typed
portions and their live previews, stomach room, exact grain reservation,
proportional cooking, digestion,
stale stock, dismissal, viewport resizing and Game Over input isolation.
It also checks wheel hit targets, first-opening keyboard focus, left/right camp
clicks and the calorie preview for all five grains. Model tests verify each
grain's actual completed meal and one-gram precision.
The sleep test follows camp and keyboard choices, typed duration, live recovery
and starvation predictions, pause, early waking, preserved work, meal conflicts
and Game Over/Restart. Model checks compare predictions with real travel and
sleep, including death and non-frame-aligned waking across midnight.
Terrain tests cover 30 seeded fields, farmable hills, ponds, connected dry routes,
each preset and the flat and highest Custom lands (pond counts, reachable
farmland, Steppe > Hills > Lakeland in farmable plots), a camp on high ground,
mesh/sampler agreement, edge/vertex picking, blocked plot previews, reservations,
route cancellation and sleep forecasts while already returning home. The scene
test checks hill/water picking, grounded people and camera clearance; run it
without `--headless` to also inspect actual crop instance transforms, which the
dummy renderer discards.
The save test writes only under `/tmp/stefan-save` (test runs never touch the
player's slot). It saves a game mid-job, restores it into a fresh scene, checks
every saved field and that both games stay identical for 48 game hours, and
checks the dawn autosave, eight kinds of corrupt save, the menu's Continue and
deletion at death.
To capture actual GPU-rendered screens:

```sh
./godot/run.sh --script tests/capture_menu.gd -- /tmp/stefan-menu
./godot/run.sh --script tests/capture_wheel.gd -- /tmp/stefan-wheel
./godot/run.sh --script tests/capture_human.gd -- /tmp/stefan-human
./godot/run.sh --script tests/capture_weather.gd -- /tmp/stefan-weather
./godot/run.sh --script tests/capture_terrain.gd -- /tmp/stefan-terrain
```

The default window is 1280×800; the minimum is 1000×700. The title uses bundled
[Cormorant Unicase](https://github.com/google/fonts/tree/main/ofl/cormorantunicase),
licensed under the included SIL Open Font License. Button/version text uses a
system serif font. Vector artwork is original; its aurochs, star, rosette and
moon are an artistic Moldavian-inspired emblem, not a period reconstruction.

## Project notes

- [Lessons learned](docs/lessons-learned.md) and [historical research](docs/historical-research.md).
- [Preserved configuration](configuration/README.md) and [project rules](AGENTS.md).
- [Menu design](docs/superpowers/specs/2026-10-24-stefan-main-menu-design.md).
- [Validation](godot/VALIDATION.md) and [reset recovery archive](docs/RESET.md).

The working directory and existing GitHub origin remain `razes` to preserve
connections and Git history. Ștefan is the project name; `stefan` is its ASCII
spelling for technical identifiers. The previous browser, Swift/macOS and Godot
game implementations were removed. No remote rename, push or deployment is
part of this reset and first menu.

The menu now uses a generated fortress landscape and aurochs game icon. See
[artwork and generation prompts](godot/assets/ART.md) for the bundled assets and
how the painting, gold ornament and accessible controls fit together.

For terrain/weather survival checks and native captures:

```sh
LAND=Hills TARGET=20 WORK=6 YEARS=2 ./godot/run.sh --headless --script tests/sim_first_year.gd -- 3 plan
./godot/run.sh --rendering-method gl_compatibility --script tests/capture_survival.gd
```

`LAND` accepts Steppe, Hills, Lakeland and Custom (the highest hills/four ponds).
The scripted player explicitly orders chopping, building, food, sleep and recovery;
it does not grant these decisions to the in-game farmer. Captures and frame-time
comparisons are written to `/private/tmp/razes-survival-captures` and stdout.
