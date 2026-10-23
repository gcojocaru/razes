# Răzeș for macOS

Native SwiftUI + SpriteKit settlement game with Ion as the only worker and repeating seasons. Requires macOS 14 or later and a Swift 6 toolchain (Xcode 16 or later). No backend, web server, accounts, or third-party Swift packages.

Open `Package.swift` in Xcode and run `RazesMac`, or from the repository root:

```sh
swift test --package-path native/macos
native/macos/Scripts/package_app.sh
open native/macos/build/Razes.app
```

The packaging script builds for the current Mac's architecture, copies the resource bundles, signs for local development, and checks the bundle and signature. The generated app lives in `build/Razes.app`. It is not notarized or signed for public distribution. Intel Macs and macOS 14 have not been tested on hardware.

In a restricted workspace, use writable caches and disable SwiftPM sandboxing:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/razes-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/razes-swift-cache \
swift test --package-path native/macos --disable-sandbox --scratch-path /tmp/razes-swift-build
```

## Playing and saves

Select Ion or a place to assign one job for the season. Review the forecast, confirm work, read the seasonal report, and continue. Winter returns to spring and resets the crop. Ion can sow in spring, tend in summer and harvest alone in autumn, or use his assignment for wages, provisions, repairs or gathering. Food use is 3 per season, reduced to 2 in winter with an active woodshed; cold winter shelter adds 1. Shortages are reported and the settlement continues. These are initial tuning values.

There are no authored conversations, other characters, promises, journal or ending in the Mac game. The browser version retains its independent story. The Places menu provides keyboard alternatives to scene targets. Escape closes optional commands. Sound starts off. Reduce motion freezes optional animation; the system accessibility setting takes priority.

New settlements start with the house and Ion. Build offers eleven types on the 16×16 isometric map, each with levels 1–5:

| Building    | Build price | Level 1 production per season |
| ----------- | ----------: | ----------------------------- |
| Woodshed    |     3 coins | 1 coin                        |
| Root cellar |     4 coins | 2 food                        |
| Barn        |     5 coins | 1 food + 1 coin               |
| Well        |     3 coins | 1 food                        |
| Granary     |     6 coins | 2 food + 1 coin               |
| Workshop    |     5 coins | 2 coins                       |
| Bakery      |     7 coins | 3 food + 1 coin               |
| Smithy      |     8 coins | 3 coins                       |
| Stable      |     9 coins | 1 food + 2 coins              |
| Apiary      |     4 coins | 2 food + 1 coin               |
| Storehouse  |     4 coins | +40 shared material storage   |

Choose a type and click free ground. Green footprints fit; red footprints are occupied, outside the map or protected house/farm space. Coins and material costs are shown before placement and paid immediately, preserving supplies and coins reserved for seasonal assignments. Foundations complete at the end of the season, after work and upkeep. Workers retain their jobs. There is one structure of each type per household.

Select a building to inspect condition, rotate or move it, upgrade or repair. Upgrades cost the base price times the target level and apply immediately; production multiplies by level. Repairs cost half the base price rounded up and restore condition immediately. Existing completed buildings produce the catalog yield once per season, included in the forecast. They then lose 20 condition after seasonal consumption. At zero, a structure above level 1 loses a level and returns to 60 condition; level 1 stays inactive until repaired. New construction first produces the following season. Resources cap at 100000. The starter house retains its original shelter rules; its separate storage upgrades do not repair shelter. Woodshed winter protection and improved cellar provisions require positive condition and begin the season after completion.

There are no construction, upgrade, repair, production or decay clocks, including while the app is closed. Every season uses the same planning, resolution and report loop; building production and wear apply exactly once per turn. New foundations first produce in the following season, including across winter into spring.

Drag the map, right/middle-drag, or scroll to pan. Pinch or Option-scroll to zoom. The Pan menu, zoom buttons and Home reset provide explicit camera controls. Rotate map left/right cycles four views while the HUD stays upright. Each placed building/scenery has its own facing. A building inspector can rotate it; R or Rotate placement changes facing before placement. Rotation updates projected ground, depth, people, tools, smoke, selection and inverse map picking together. Painted front/rear facades and mirrors provide four directional views, with shared seasonal crops and snow on roofs, ledges and bases in every view. The rear artwork preserves building materials and features; foundations retain construction artwork when rotated. This is 2D artwork, not a continuous 3D orbit.

Build offers Farmland, Stone pavement, Dirt path, Rail fence, Wattle fence and Erase. Farmland costs one coin per tile and uses the same drag painting as pavement, allowing any shape or size. Both path surfaces cost one coin per tile; both fence styles cost one per cell edge. Click or drag to paint connected runs; the tool stays active. R or Rotate fence edge selects the north/east/south/west edge, including when the map owns keyboard focus. The painted preview matches the chosen fence style and edge in all four map views. Path surfaces cannot overlap each other; a path and a fence can coexist. A shared edge cannot be charged twice, even using a different fence style from the opposite side. Erase removes path surfaces, farmland and bordering fences with no refund. Buildings cannot cover infrastructure or farmland. House ground stays protected. Farmland cannot be changed while crops are growing or farming work is assigned; cancel the assignment or harvest first. Winter fallow land can be edited. Sowing requires at least one farmland tile. Existing seed costs, seasonal jobs and harvest yields are unchanged by area. Escape cancels a tool or closes optional commands.

The Debug workshop places buildings instantly, finishes foundations, edits levels/condition and grants resources. Season preview changes painted ground, seasonal art and weather without changing resources, simulation season or assignments. Actual season restores the real view. Legacy barn/well/stores/fence debug scenery is retained. Debug edits save with the household.

Commands save atomically to `~/Library/Application Support/Razes/settlement-v8.json`. Schema 8 stores Ion-only assignments, painted farmland and a repeating season/year counter. Saves without farmland data retain the original nine field tiles; explicitly empty farmland stays empty. This is a fresh development reset: earlier `household-v1.json` saves remain untouched and are not migrated. Unreadable data blocks gameplay until retry or explicit fresh start; restart preserves a recovery copy. Browser saves remain separate.

## Materials, crafting and shared storage

Select the **house** to see food, coins, wood, stone, planks, material storage usage and reserved stocks. **Buy supplies** opens the purchasing panel; **Materials** in the resource strip opens the same panel. Food provisions remain a seasonal job for Ion (4 coins for 7 food, or 10 with an active cellar). New settlements receive 6 wood and 4 stone in 20 shared slots. Wood, stone and planks each occupy one slot; food and coins remain separate. House storage levels 1–5 add 10 slots per upgrade. Upgrading is immediate, costs 4 × target level coins plus 2 wood, 2 stone and 1 plank, and does not change shelter condition.

During work planning, assign Ion to **Gather timber** (up to 6 wood) or **Gather stone** (up to 4 stone). Gathering replaces his other seasonal job. The forecast shows the haul that fits in free storage. Materials arrive when work resolves and cannot fund construction in the current draft. Gathering remains available every year.

Buy any material immediately without a worker: wood/stone cost 1 coin per unit, planks cost 3. Crafting immediately converts 2 free wood into 1 plank, with no worker or timer. Quantity applies to buy, craft and discard actions. Purchases must fit and preserve reserved coins; crafting checks room after consuming ingredients and preserves reserved supplies. Explicit discard buttons free unwanted supplies without a refund.

Construction and upgrades also need materials; the build palette and inspectors show quantities. Woodshed, cellar, barn and well use raw wood/stone; other buildings introduce planks. Upgrade material costs scale with target level. Repairs use 1 wood (wooden structures) or 1 stone (cellar, well, bakery, smithy), in addition to their existing coin cost. Roads and fences retain their existing coin prices.

A storehouse costs 4 coins, 6 wood, 2 stone and 2 planks, fitting in starter storage. It completes at season end and adds 40 slots per completed level. It reuses the granary artwork. Wear does not destroy inventory: a downgrade may leave supplies over capacity, blocking incoming materials until space is freed. A level-1 storehouse retains its storage even at zero condition.

Prices, yields and capacity are initial tuning values, not playtested balance. No selling, resource depletion, recipe tree or automatic material production is included.

## Native validation

`RazesCore` owns native settlement definitions, rules, presentation and save validation. `RazesMac` owns the session, views, audio and scene. Native gameplay no longer imports browser story data or reference years; the obsolete native parity exporter and fixtures have been removed. Browser rules and tests remain independent.

Run `swift test --package-path native/macos` for the seasonal loop, solo harvest, multi-year save round-trips, forecast consistency, construction/materials, scene, controls and recovery checks. Run `native/macos/Scripts/package_app.sh` to build and verify the local app bundle.

The SpriteKit scene composes persistent backdrop, terrain, world, weather, smoke, selection and feedback nodes. A shared 2:1 projection places the household; world sprites, tools and hit targets use ground depth. Selection and assignments preserve these containers. The ground uses 1,024 reusable diamond tiles with cached grass, earth and snow textures. Paths, the field soil and construction patches are composed per tile, rather than baked into one ground picture. Seasonal materials and completed building textures swap in place. Eleven building types reuse the original artwork and painted front/rear atlases; level storage layers, wear marks, condition bars and construction progress compose independently. Construction dust, tools, completion flashes and resource feedback respect reduced motion; loading does not replay completion effects. SwiftUI draws the HUD separately. This is a painted 2D scene with validated grid placement and a bounded camera.

Artwork is reused from `public/art/`; see the root README and `docs/art/2026-10-21-painterly-pass.md` for provenance; the new ground and construction assets are documented in `docs/art/2026-10-22-native-construction.md` and `docs/art/2026-10-23-settlement-buildings.md` and `docs/art/2026-10-23-directional-buildings.md`. Bundled DM Sans and Cormorant Garamond font licenses are in `Sources/RazesMac/Resources/Fonts/`.

This first port does not implement mobile/Windows, custom Metal rendering, browser-save migration, pathfinding, cloud saves or store distribution. See the [native validation report](VALIDATION.md) for checks actually performed.
