# Ștefan

A fresh Godot desktop game, starting with a medieval Moldavian inspired main menu.
Select **Play** or press **Enter/Space** to open the strategy field: a 16×16 grid of building plots.
Hover or click a square to highlight or select it. Move with WASD/arrows, rotate
with Q/E or right-drag, zoom with the mouse wheel or trackpad pinch/scroll. Time runs at one day every
2 seconds (a year is 4 seasons × 3 months × 4 weeks × 7 days); Space pauses and
1/2/3 pick 1×/2×/4× speed. In debug builds, F3 opens a panel to set the day length.
Each day rolls seeded weather (Clear, Cloudy, Rain, Storm, Snow) and a temperature
tuned to modern Moldovan (Chișinău) climate normals, with multi-day warm, cold,
wet and dry spells. Rain and snow fall as particles, storms flash lightning, and
fog, sky, sunlight, wet ground and lying snow blend in as the weather turns.

Farming is the first gameplay loop. Click a plot or drag over a rectangle of
plots; hold **Shift** to add to the selection. Without a mouse, move the view
and press **Enter** to select the plot at its centre (**Shift+Enter** adds). The
farm panel shows illustrated icons for each action the selection allows; hover
for plot counts and the kilograms of grain it costs or brings; **F** does all of them. Plow grass, stubble or
dead crops (not in winter), sow plowed land, and harvest ripe crops. Sowing uses
the crop pictured on the sowing icon, whose tooltip names it and lists its needs.
Right-click a plot, click the **Actions** wheel icon, or press **C** to open a segmented action
wheel. Right-clicking a plot selects it unless it is already in the selection.
The wheel offers **Plow** on grass, stubble and dead crops; individual crop
icons on plowed land; and **Harvest** on ripe crops. It shows only actions that
can be done now, with plot counts and seed costs or harvest yields in kg. Growing
crops, frozen ground and seed shortages show an explanation instead. Mixed
selections offer work for each eligible part of the selection.
Click a segment, or use arrows/Tab and **Enter**. Choosing a crop sows it and
remembers it for the sowing icon and F. **Escape** or an outside click dismisses
the wheel; a right-drag still rotates the view. Time continues while it is open,
and availability refreshes as days change.

| Crop | Sown | Grows above | Needs | Dies at | Seed → harvest a plot | Bag |
| --- | --- | --- | --- | --- | --- | --- |
| Barley | Spring months 1–2 | 4°C | 60 warm days | -3°C | 20 → 70 kg | 45 kg |
| Oats | Spring months 1–2 | 4°C | 75 warm days, likes rain | -4°C | 16 → 56 kg, copes with poor soil | 32 kg |
| Millet | Spring month 3 – Summer month 1 | 10°C | 50 warm days, hardy in drought | 1°C | 3 → 40 kg | 50 kg |
| Wheat | Autumn months 1–2 | 3°C | a winter, then 110 warm days | -8°C | 15 → 75 kg, wears soil most | 55 kg |
| Rye | Autumn months 1–3 | 2°C | a winter, then 95 warm days | -16°C | 16 → 64 kg, copes with poor soil | 50 kg |

Across 50 weather seeds, barley ripens in early summer, oats mid-to-late
summer, millet late summer to early autumn, rye the next early summer and wheat
after it; about one winter in five is cold enough to kill wheat. Each crop has
its own store: sowing uses that crop's grain as seed and its harvest goes back
to it. Grain is counted in kilograms: a plot is a tenth of a hectare, sown at
medieval manor rates of 2–4 bushels an acre (130–215 kg/ha; millet, sown thin,
30 kg/ha). You start with 100 kg of barley, 80 of oats and rye, 75 of wheat and
18 of millet, seed for five plots each and six of millet; the inventory shows
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
To capture actual GPU-rendered screens:

```sh
./godot/run.sh --script tests/capture_menu.gd -- /tmp/stefan-menu
./godot/run.sh --script tests/capture_wheel.gd -- /tmp/stefan-wheel
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
