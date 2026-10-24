# Ștefan main menu validation — 24 October 2026

Godot 4.7.2.stable.official.ed1daf0bf, macOS, Apple M4, Compatibility renderer.

- Asset import and the full headless menu test pass: Romanian Ș glyph, title,
  settings-driven v0.1.0, initial Play focus, focus style, three layout sizes,
  Enter/Space activation, mouse activation and the grid field with
  cell picking, view-centred rotation and trackpad pinch zoom.
- Actual GPU captures of the 1280×800 window, minimum 1000×700 window and blank
  game screen were inspected. Corrected the version position to clear the frame.
- The initial Uncial Antiqua font lacked Ș; replaced it with bundled Cormorant
  Unicase. The test asserts direct glyph coverage, so system fallback cannot
  silently mask missing Romanian support.
- Mouse test events use viewport-local coordinates, avoiding duplicate scaling
  in the input injection path when testing resized windows.

Captures are local artifacts in `/private/tmp/stefan-menu/`; regenerate with the
README command. The capture script activates the real Play button through mouse
input. No screenshots or generated engine caches are committed.

Restricted execution can report macOS certificate/per-user-directory access
errors before the passing test; normal engine execution is used for the final
verification and graphical captures. The app does not use networking or save
state.

Not checked: Windows/Linux execution, Intel/minimum macOS hardware, screen-reader
support, exports, signing or notarization. System button/version fonts may vary
across platforms. Historical fidelity of the ornamental style is not established.

## Menu music follow-up

- Bundled the user's selected Drumul Dracului YouTube recording as a local MP3,
  with source/uploader attribution and unverified permission status recorded in
  `assets/audio/SOURCE.md`. No runtime streaming or downloader dependency.
- The added music test failed before implementation. The full suite then passed
  with automatic playback at -14 dB, loop wraparound across the end of the track
  and music-player destruction after Enter, Space and mouse activate Play.
- FFmpeg decodes the full MP3 without errors; the audio contains a non-silent
  signal. Speaker/headphone listening quality has not been assessed.

## Crop loop follow-up

- Added `farm.gd` rules (plot stages, grain stock, weather growth, frost),
  the bottom farm panel, the F key and a per-cell crop texture in the field shader.
- Growth and frost numbers were tuned against 50 weather seeds before writing
  the rules; `tests/test_crops.gd` keeps those outcomes: mid-spring sowing ripens
  in all 50, first-week sowing sometimes freezes, last-week sowing mostly dies.
- `test_crops.gd` and the existing `test_menu.gd` pass headlessly (exit 0).
  A new `class_name` needs the editor import step first, or tests fail to parse.
- Inspected GPU captures at 1280×800 and 1000×700 with plots in every stage:
  plowed, three growth levels, ripe, withered and a selected plot. Withered was
  first too close to plowed soil and was made greyer.

Not checked: snow-covered or rainy fields with crops, play at real speed,
balance with people, and whether 10 starting grain is a good pace. Grain has no
consumption yet, so the stock only grows.

## Land use, selection, ledger and field graphics follow-up

- Harvests now leave stubble and wear soil fertility; resting land recovers and
  untended land returns to grass on warm days. A nine-year simulation on three
  weather seeds was used to tune wear and rest: yearly cropping falls from 8 to
  2 grain per plot, while resting one year in three repeats 8, 7, rest.
  `test_crops.gd` keeps that outcome with seed 7.
- Drag selects a rectangle of plots and Shift adds to it. Farm panel buttons
  come from `Farm.preview`, which runs the real rules on a copy of the farm,
  so the forecast and the outcome cannot drift apart; the test checks both.
- The L ledger lists worked land by stage and each year's results.
- Textures: CC0 ambientCG Grass004 and Poly Haven farm_furrows (see
  `assets/textures/SOURCE.md`), with mipmaps. Crops are one MultiMesh of
  16,128 three-blade tufts; the crop shader reads the per-plot data texture to
  size and colour them, so nothing is rebuilt as crops grow.
- Both headless tests pass. Inspected GPU captures at 1280×800 (normal and close
  zoom, rotated) and 1000×700 with every stage, worn soil, returning grass, a
  selection and the ledger. Fixed from captures: spiky single stalks, black
  dead crops, blocky regrowth and splayed sprouts.

- Worst case, every plot ripe, ran at 209 fps on the Apple M4 with vsync off.

Not checked: frame rate on slower GPUs (about 290,000 crop vertices plus their
shadows), snow-covered crops, real play at normal speed, and balance with people.

## Generated icon and menu background

- Set the generated square aurochs shield as the project icon and the generated
  fortress landscape as the menu background. Prompts and asset use are recorded
  in `assets/ART.md`. Text/button controls and vector ornament remain separate.
- Inspected real GPU captures at the normal 1280×800 and minimum 1000×700 window
  sizes in `/private/tmp/stefan-menu-art/`. Title, Play, version and frame remain
  readable. Existing keyboard/mouse/music/menu regression checks pass.
- Exit-time leak warnings predate the gameplay work: headless tests already
  printed ObjectDB, resource and dummy-shader leaks at commit 1601b4b, and the
  GPU runs' `ParticlesShaderGLES3` warning comes from the weather particles.
  Native desktop export icons were not tested.

## Audit fixes

- The menu music loop check now waits on the real clock. Its game-time timer ran
  out after 57 ms of real time once the larger menu painting slowed the first
  frames, so the test failed every run before the music looped.
- Enter selects the plot at the centre of the view and Shift+Enter adds it, so
  plots can be farmed without a mouse.
- A storm's first lightning now waits until the 4-second wet-ground blend ends;
  a strike at 3–4 seconds used to stop the ground short of fully wet.
- Removed the orphan `_stats.gd.uid` and shared the HUD serif font from
  `time_hud.gd`.

## Crops, puddles, ledger tabs and agriculture debug follow-up

- Plowed land changing look after rain was the old rule that let grass back
  onto unsown plowed land: patches appeared 5–40 days after plowing, often
  around rainy spells, and the plot became grass after 35–90 days. Plowed land
  now stays plowed; stubble and dead crops still go wild. Rain leaves
  sky-tinted puddles in furrow hollows that dry with the weather.
- Five crops replace generic grain, each with sowing months, base and best
  temperature, rain preference, frost limit, winter need, seed, yield, soil
  sensitivity and wear (`Farm.CROPS`). Tuned with 50 weather seeds per sowing
  month: every crop ripens when sown mid-window except wheat, which hard winters
  kill in 11 of 50 seeds at -8°C (none at -9°C, so -8 was kept for risk).
  Raised soil wear after a nine-year check showed spring crops barely wore the
  soil once they spent less time in the ground.
- The Sow button names its crop; C or ▸ cycles crops sowable this month.
  Ledger tabs: Fields, Years, Crops. F4 opens the agriculture debug window in
  debug builds. Ripe colour and height live in `Farm.CROPS` and reach the crop
  shader as uniform arrays, so the ledger swatches and stalks share one source.
- Both headless tests pass. Inspected GPU captures of all five crops ripe and
  growing, worn and fertile plowed soil, a rainy close-up of puddles, and the
  ledger tabs beside the debug window. Fixed from captures: dark smudges instead
  of water in puddles, and Crops-tab columns pushed out of line by long text.

Not checked: snow on growing winter crops, play across several real-time
years, and whether these crops and numbers suit historical Moldavia.

## Crop context menu follow-up

- One styled crop menu replaces cycling with C: right-click a plot (a click,
  not a camera-rotating drag of 6 pixels or more), the Crop ▾ button, or C, which
  leaves it keyboard-navigable. Items say what they would sow now, or show the
  sowing months of crops out of season (disabled); the current crop is checked.
- `test_crops.gd` opens it with C, chooses Oats with Enter, opens it by
  right-click and checks a right-drag does not. A typed-variable warning (treated
  as an error) first stopped `game.gd` loading and the test then hung waiting on
  the missing scene; both tests pass after the fix.
- GPU captures at 1280×800 showed the first right-click menu offset up-left:
  popup positions are viewport coordinates, which the code had scaled a second
  time. After the fix it opens at the clicked plot, and the button/C menu opens
  just above Crop ▾.

## Inventory and wiki follow-up

- Each crop now has its own store (`Farm.stock`): sowing uses that crop's grain
  as seed and its harvest returns to it. With 10 barley and 2 seed a plot, a
  six-plot selection sows five and the panel says "Seed for 5 of 6".
- Inventory window (I or button), ledger and wiki share `hud_window.gd` (frame,
  title, close button, striped rows, bars); the ledger moved onto it unchanged.
- `wiki/wiki.html` is a standalone page (checked in the browser pane). The F1
  window converts its subset of tags to BBCode. Tests cover the converter
  (lists, tables, bold, escaped brackets, dropped head), that each crop's wiki
  row matches `Farm.CROPS`, and that the shown text has no leftover tags.
- Both tests pass. GPU captures of the inventory beside the ledger and the wiki
  at its top and crop table looked right; "−0 sown +0 harvested" was replaced
  by a dash.

Not checked: an exported build (the HTML needs an export filter), and wiki
text beyond the crop table drifting from the rules.

## Weather soundscape and controls — 24 October 2026

- Added five continuously offset ambience layers: long wind, filtered winter wind,
  and three loopable rain textures, plus lightning-triggered delayed thunder.
  Repeated days keep playback running; leaving a storm cancels pending thunder.
- Shared wind strength/direction drives crop sway and precipitation. Calendar
  pause and acceleration do not change audio speed. No crop rules or saves changed.
- Sound button/F10 in menu and field opens mute and master/weather/music sliders.
  Escape closes it; settings persist in sound.cfg independently of gameplay.
  Runtime wind attribution includes source/license links and modification notice
  in the credits tooltip; full provenance is in assets/audio/weather/SOURCE.md.
- Asset import and test_audio.gd, test_menu.gd and test_crops.gd pass on Godot
  4.7.2 / Apple M4. Audio tests check settings validation/round-trip, zero volume,
  mute preserving levels, running layers, thunder delay/cancellation, repeated
  weather, transitions, menu music bus, both controls, F10/Escape, camera isolation
  and panel geometry at 1000×700. Tests restore preferences after slider changes.
- GPU captures of rain, storm, snow and the panel at 1000×700 were inspected.
  Fixed initially off-screen anchors and made the Sound button opaque for contrast.
- Godot reports particle shader RID cleanup warnings at shutdown. An unchanged
  HEAD copy reproduced the same shader warnings. Waiting for the audio server
  after freeing test scenes eliminates the additional audio shutdown warnings.

Not checked: subjective headphone/speaker balance, assistive-technology behavior,
long-session listening fatigue, or an exported build.

## Contextual action wheel — 2026-10-24

- Replaced the crop popup with the selected segmented wheel design. Right-click,
  C and Actions show eligible Plow, individual Sow crops, and Harvest segments
  with distinct illustrated SVG icons, plot counts and grain changes. Status-only land
  explains its limits in the hub; long mixed reasons have a full-text tooltip.
- `tests/test_wheel.gd` passes: grass/stubble/withered, plowed, growing, ripe,
  mixed, spring/autumn/winter, exhausted seed, activation-time revalidation,
  live refresh, keyboard activation/Escape, outside dismissal, first-opening
  layout, long reasons, and viewport-edge/hint fit.
- `tests/test_crops.gd` and `tests/test_menu.gd` pass. Crop integration now uses
  routed input and checks both keyboard sowing and mouse plowing, preserving
  right-drag rotation and mixed selection, blocking outside drag selection and
  underlying inventory-button clicks while the wheel is open.
- GPU captures from `tests/capture_wheel.gd` checked on Apple M4/OpenGL:
  grass, plowed, growing, ripe, mixed, autumn wheat/rye, millet, winter status,
  and bottom-right placement at the 1000×700 minimum window. The checks caught
  and corrected first-opening label expansion and an overlapping edge hint.
- A separate code review caught GUI sibling input ordering; the wheel now sits
  after every HUD window and the inventory regression passes.
- Headless runs report a macOS system-CA lookup diagnostic and renderer shader
  allocations at exit; rendered captures also report particle shader cleanup
  diagnostics at shutdown. No script errors or failed assertions remain.
- Physical VoiceOver, other GPUs/platforms and long play sessions are unverified.
- Icon refinement: seven original 64×64 SVG assets replace procedural line
  symbols. Wheel and crop tests pass, including texture import/dimension checks;
  rendered mixed, autumn, millet and minimum-window icons were visually checked.
- Rebased onto the merged weather-audio update on main; wheel, crop, menu and
  audio tests all pass. The sandbox blocks default sound-preference writes;
  the audio suite's explicit temporary-file round-trip passes.

## Harvest kilograms and bag inventory follow-up

- Grain is counted in kg. A plot is 0.1 ha; seed and full harvest per plot use
  medieval rates. Barley, oats and rye keep their previous seed-to-harvest
  ratios; millet and wheat changed after the realism check below. Starting
  stock still seeds five plots of each crop and six of millet.
- Harvests vary with the season: each growing day adds the crop's watering
  relative to a cloudy day, and the average deviation is scaled by 5 because 60+
  days of spells average out (unscaled, 50 seeds gave only ±5%). Mid-window
  sowing over 50 weather seeds then gives barley 67–116% of full, oats 45–114%,
  millet 83–105%, wheat 73–131%, rye 80–134%, averaging 87–95%. Capped at 150%
  for an all-rain season, which real weather never reaches.
- Realism check against sources: medieval manors sowed wheat at 2–2.5 bushels
  an acre and oats, barley and drage at 3–4 (Postles, Oxoniensia 1979), i.e.
  130–215 kg/ha at 60/48/32 lb bushels; game seed is 150–200 kg/ha. Medieval
  wheat returned 2–7 times its seed and documents average about 2.7–3.9; 18th-
  century Russian black-earth provinces averaged rye and oats sam-5 to 7, wheat
  about 2–5, millet 4–40 with best years sam-40 to 50, swinging year to year
  from 1.5 to 7 for rye (Milov). Romanian traditional cereals gave 800–1400
  kg/ha, 540 in a bad year (Jarman, quoted in arXiv:1505.05121). Before: millet
  sown at 50 kg/ha for sixfold, wheat elevenfold over two, and ±15% weather.
  Now millet is 30 kg/ha sown for about thirteenfold, wheat 15 → 75, and the
  swing above; averages come to 3.0–4.6-fold (490–690 kg/ha) for the four big
  cereals. A bag of about 70 litres is two US bushels: 54 kg of wheat, 51 of
  rye, 44 of barley, 29–35 of oats (32–38 lb bushels); proso tests about 52
  lb/bu. No Moldavian 15th-century yield figures were found.
- The resting-rotation check compares the mean of the later sown years with
  the first cycle (within 20%), since weather now moves each year's harvest by
  up to a third; resting still holds about 90% where yearly cropping falls to a
  third.
- Inventory (I) is an RPG-style grid of bag slots. A bag holds about 70 litres,
  so 55 kg of wheat, 50 of rye and millet, 45 of barley, 32 of oats
  (`Farm.CROPS[crop].bag`). `bag_icons.gd` builds each bag as a 3D scene in
  its own SubViewport, renders it once at 128 px with 4× MSAA, copies it into a
  mipmapped texture and frees the viewport; looks are cached per crop, eighth of
  a bag and one of three variants. The sack is a lathed superellipse settling
  wider at the bottom, with lumps, pleats and a wavy, rolled rim; `sack.gdshader`
  gives it burlap (threads over and under, holes, fibres, wear, a fuzzy
  outline). The heap is several hundred instanced kernels, shaped per crop,
  over a dark dome; the initial is a shaded Label3D stamp. A sun with shadows,
  a cool fill light and a blob floor shadow light it. A part-filled bag sits
  lower and wider with gold kg. The per-crop table hides behind a Stats toggle;
  the total stays.
- Both headless tests pass. GPU captures at 1280×800, judged against a
  user-supplied photo of medieval sacks for style: the first flat-polygon bags
  had unreadable kg labels over them (moved to a strip below); a flat 2D shader
  pass was replaced by the 3D renders, whose first version looked like orange
  wicker pots (finer, duller, flatter weave; rounder, lumpier body; wavy mouth;
  stamp moved up to the belly and thickened; framing tightened). The Stats test
  needed a frame's wait: a window's header lays out the frame after it is shown.
  One GPU capture run reported a resource still in use at exit, likely a bag
  render still waiting for its frame when the script quit; a repeat was clean.

- Merged after the action wheel landed on main: its segment labels, hub text
  and test now use kg (seed and harvest from `Farm.CROPS`), and the crop test
  keeps the wheel's click-through check, pressing the inventory's close button
  by its text now that Stats sits before it.

Not checked: tooltips and hover highlight on screen (hover was only sent in the
capture), very large stores (the grid scrolls past about six rows), slower GPUs
(each new bag look renders a 3D scene of about 15,000 triangles once), and
storage limits: bags are a display, so the store holds any amount.
