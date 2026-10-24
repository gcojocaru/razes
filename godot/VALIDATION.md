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
