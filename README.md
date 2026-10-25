# Ștefan

A fresh Godot desktop game, starting with a medieval Moldavian inspired main menu.
Select **Play** or press **Enter/Space** to open the strategy field: a 16×16 grid
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

Farming is the first gameplay loop. Click a plot or drag over a rectangle of
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
the camp menu, **R** opens Sleep (or wakes the farmer early), and **Backspace**
or Clear jobs cancels work.
The Farmer panel shows activity, work left, food energy, fatigue, health,
reserved seed and their carried grain. Orders reserve seed immediately;
the farmer collects it at camp, walks to the plot and completes the work before
the field changes. Duplicate orders on a plot are ignored. Plowing takes
3 game hours per plot, sowing half an hour and harvesting 2 hours. Harvested
grain travels in the farmer's sack before it reaches the store; cancelled or
unusable seed is returned. These are initial manual-work tuning values.

Eating and resting require your command. The farmer does not stop work for
hunger, exhaustion or night. Click the camp to open the same segmented action
wheel used for fields, with **Eat** and **Sleep** icons. Choose **Eat**, then select a grain
bag and a quantity in whole grams in the inventory-style **Prepare food** window.
It previews calories and preparation time. **Prepare & Eat Porridge** reserves
exactly that grain and sends the farmer to camp to cook and eat it; energy is
added when preparation finishes. A 300 g portion takes half an hour; time scales
with quantity, and calories also depend on the grain. Only unreserved grain is
available, with one meal pending at a time. Opening or closing the window spends
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
24, with quarter-hour controls). Its live preview shows restedness, food energy,
health and total time including the walk to camp. Sleep recovers 20 fatigue
points per hour and burns 60 kcal per hour; it does not create food calories.
Confirmation preserves field work, walks home and sleeps for the chosen hours,
including during daytime. Work resumes when that time ends; **Wake up** or
**R** ends sleep early. Opening or closing the window starts nothing. Finish a
pending meal before sleeping, and wake before preparing another meal.
Food energy supports daily life and work and can
fall below zero. Once depleted, health starts falling. At zero health a centred
**Game Over** message appears and gameplay, time and debug skips stop. Restart
or Enter begins a fresh farm. F4 skips otherwise advance the farmer as well as
the crops. Pause stops both; weather audio continues. Water, cooking fuel, milling losses,
diet quality and weather exposure are still abstracted, and food/work rates
are game tuning rather than a verified historical survival model.

The person and cereal heights share the plot's metre scale; **H** zooms in to
make the farmer easy to see. The camp and clothing are original low-poly art,
not a verified reconstruction. The grass outside the grid grounds the camp
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
30 kg/ha). You start with 10 kg of barley, 8 of oats and rye, 7.5 of wheat and
1.8 of millet, seed for five plots each and six of millet; the inventory shows
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
`wiki/*.html` (Export → Resources → filters to export non-resource files).

The field uses CC0 grass and ploughed-soil textures (see their
[sources](godot/assets/textures/SOURCE.md)); crops are instanced stalks sized
and coloured on the GPU from a per-plot data texture.
Current version: **0.1.1**. No saves yet.

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
```

The menu test checks title spelling/font coverage, version, initial keyboard focus,
visible focus styling, layouts at three sizes, real keyboard/mouse activation
the grid field, cell picking, camera rotation and pinch zoom, automatic menu music, loop wraparound and stopping
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
The human tests cover exact reservations and refunds, timed work, walking,
hauling, stale orders, timed sleep and meals, food exhaustion and death,
subdivision of time, physical mesh scale and poses, and actual scene input,
pause, focus, cancellation and debug skips.
The camp food test follows real camp clicks, menu and bag selection, typed
portions and their live previews, exact grain reservation, proportional cooking,
stale stock, dismissal, viewport resizing and Game Over input isolation.
It also checks wheel hit targets, first-opening keyboard focus, left/right camp
clicks and the calorie preview for all five grains. Model tests verify each
grain's actual completed meal and one-gram precision.
The sleep test follows camp and keyboard choices, typed duration, live recovery
and starvation predictions, pause, early waking, preserved work, meal conflicts
and Game Over/Restart. Model checks compare predictions with real travel and
sleep, including death and non-frame-aligned waking across midnight.
To capture actual GPU-rendered screens:

```sh
./godot/run.sh --script tests/capture_menu.gd -- /tmp/stefan-menu
./godot/run.sh --script tests/capture_wheel.gd -- /tmp/stefan-wheel
./godot/run.sh --script tests/capture_human.gd -- /tmp/stefan-human
./godot/run.sh --script tests/capture_weather.gd -- /tmp/stefan-weather
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
