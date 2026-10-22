# Răzeș: scene-first strategy interface and construction

## Intent and authority

The user finds the native port too similar to a website and wants the graphics larger, a strategy-game interface, construction, more visual effects and new buildings. They approved the recommended first scope: keep the four-season story, make the homestead the main screen, and add two buildings. This is a macOS-only iteration of `native/macos/`; the browser game remains unchanged.

Success means playing through the world feels primary: see the household, select a person or place, issue a command, see its forecast, then watch the consequence. Construction must change both the homestead and a meaningful seasonal decision. It must not require a new engine, a real-time simulation or a general building editor.

This design supersedes the native port's page layout and prohibition on new gameplay. Other requirements remain: macOS 14 minimum, offline operation, no third-party Swift dependencies, native accessible controls, revision-checked actions, validated atomic saves and local development packaging.

## Scene-first layout

Use a fixed game viewport rather than a scrolling page. At the default 1280 by 850 window, the SpriteKit canvas fills the content area behind the interface; compact HUD elements leave at least 80% unobscured when no contextual panel or conversation is open. Remove the large page heading, resource cards, footer, permanent right sidebar and household section below the scene.

- A roughly 48-point top strip shows season, phase, food, money, shelter and free workers. Resource icons retain text labels and accessible values. Journal, help, sound, motion and restart live in a compact secondary menu. Save warnings remain visible and actionable rather than hidden in that menu.
- A roughly 96-point bottom command area shows Ion, Ana and Petru as portrait controls with their current tasks, plus Build and the current phase's primary action. It floats over a subdued dark/opaque backing for contrast. Hover/focus states must be distinct; nothing essential depends on hover.
- Selecting a worker opens a compact task inspector; selecting the cottage, field, stores, visitor or a building plot highlights that location and opens its relevant inspector. A single inspector occupies the lower-right area, at most 300 points wide at the default window. It can scroll internally. Native controls provide keyboard equivalents for every scene command.
- Conversations appear in a temporary lower overlay with the speaker portrait, readable text and explicit choices/costs. Hide the task inspector while a mandatory conversation is active. Summary and ending use dismissible review overlays, retaining a clear Continue/Restart path. Never shrink text to keep the scene visible; long text scrolls inside its panel.
- Escape dismisses optional inspectors and Build mode, not the mandatory conversation. Preserve Command-J for the journal. End Season first opens the forecast and a deliberate confirmation; resolving work still leads to the evening event, never skips it.

Support the existing 1000 by 700 minimum window. At that size, preserve a large visible portion of the homestead and fit resource/worker controls without horizontal scrolling. The scene camera may reframe the existing composition to use the available area, but essential buildings and selection targets must remain reachable. A wider camera/world map and free camera navigation are outside this pass.

Use the existing painted palette, restrained timber/parchment/iron accents and readable native text. Avoid card grids, website navigation and decorative HUD framing that competes with the scene.

## Construction rules

There are two fixed, authored plots in unused ground. Each plot has one building type; no free placement, rotation, demolition or upgrade tree. Existing barn and well remain part of the homestead rather than being relabelled as newly constructed buildings.

| Building    | Cost    | Labour                          | Benefit                                                                                                                                             |
| ----------- | ------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Woodshed    | 3 money | One adult's seasonal assignment | In winter after completion, reduce base consumption from 9 to 6 and weathering from 14 to 6. Cold shelter still adds the existing 3-food surcharge. |
| Root cellar | 4 money | One adult's seasonal assignment | In seasons after completion, each Buy provisions assignment gains 10 food instead of 7, for the existing 4-money purchase price.                    |

These are initial testable balance values, not a claim of equal strategic value or validated enjoyment. A woodshed competes with summer tending/repairs and a cellar competes with early wages and planting. Keep existing task, crop, event and ending values unchanged otherwise.

Construction is available during the work phase in spring, summer and autumn. Winter construction is disabled with an explanation: benefits begin next season, and this story ends after winter. Only one worker may build a particular building; different workers may build the two buildings in the same season if the household can afford both. Reserved Petru cannot be reassigned. Completed buildings cannot be rebuilt.

Assigning construction is an editable draft: it reserves that adult's assignment but spends nothing yet. The preview includes all construction costs together with other work costs, checking affordability against current stocks before wages/harvest. Changing or cancelling a draft restores the plot and recalculates the forecast. Resolving work deducts cost once, records the building's completion season and completes construction before the evening conversation. Benefits begin the following season, including when construction and a provisions purchase occur in the same season. A repeated/stale resolve cannot charge or complete anything twice.

Keep the regular seasonal rhythm. No real-time timers, material inventories, additional workers or multi-year continuation. The construction controls display cost, worker commitment, completion timing and benefit before assignment. Completed-building inspectors show which benefits are active and when they start. Include construction in the seasonal report; preserve the existing journal's promises and decision history.

## Visual changes and effects

Deliver painted woodshed and cellar art matching the current elevated view, scale, lighting and palette. Each needs a construction treatment, completed treatment and snow-covered winter treatment. Reuse current land, cottage, crop, people and props. Add each asset as a separately named bundled resource with documented provenance; do not modify the original atlases to manufacture misleading new buildings.

Build mode reveals the two plot outlines with a translucent building preview. Selected plots show a perimeter/selection marker; unaffordable or unavailable actions explain why in the inspector. Assigned construction appears as a footprint/scaffolding with the assigned worker beside it. Completed structures replace their construction treatment on successful work resolution.

Use short, purposeful feedback: hammer/tool motion and small dust bursts at construction, a brief completion reveal, resource-change indicators near the relevant resource, a subtle selected-object outline, and seasonal weather/light changes. Do not simulate walking using the static character atlas. Optional effects must not obscure choices or make game state depend on animation completion.

Display a completion effect only when a building changes from draft/unbuilt to completed in the live session. Loading a completed save displays the completed building directly, without replaying construction or resource rewards. Keep stable SpriteKit nodes for unchanged elements so opening an inspector, selecting a worker or toggling sound does not restart weather or construction effects.

With system or app reduced motion enabled, show static footprints/completed buildings, selection outlines and textual state changes; omit drifting particles, tool oscillation and animated completion. Keep optional audio quiet, enabled by the existing sound control and suspended while inactive. No direct Metal renderer.

## Model and ownership

Extend `RazesCore` with typed building identifiers, immutable building definitions and completion-season records. Two construction task identifiers use the existing assignment/resolve flow. Centralize task lookup so rules, forecasts, save validation, reports and UI all recognize native construction tasks. Do not scatter lookups into the browser-exported task dictionary, which has no construction entries.

The native definitions layer augments the existing exported content without editing generated JSON or teaching the browser about construction. Maintain baseline parity: runs with no construction keep the same numeric outcomes, event selection and endings as the checked-in TypeScript reference. Adapt fixture comparisons explicitly for the native save version and empty construction records; never regenerate old expected outcomes from the new Swift rules.

Use shared pure helpers for effective seasonal consumption, weathering and task gains. Forecasts, actual evening settlement, reports and validation must agree. Winter event validation currently infers pre-weathering shelter using the original wear constant; update that relationship to use the applicable wear for the saved household.

`GameSession` remains authoritative for mutations, persistence and accepted-action feedback. UI selection and Build mode are transient presentation state; they do not alter the household until an existing revision-checked assignment is accepted. The SpriteKit scene receives state and selection, reports hit targets and renders effects. It never spends resources or completes buildings.

## Saves and recovery

Introduce native save schema version 2 with a required collection of completed building identifiers and their completion seasons. New households start with none. Keep the existing Application Support save location so an upgrade discovers the user's current household.

Version 1 snapshots first pass all existing validation unchanged, then upgrade in memory with an empty construction collection. Do not treat malformed v1 data as a new household. Before the first write that replaces a v1 snapshot, preserve its bytes under a unique migration backup name. A failed backup blocks replacement and produces the existing saving warning while retaining the live run. Version 2 snapshots require explicit valid construction fields; missing or malformed fields must not be repaired with defaults.

Reject unknown/duplicate buildings, invalid completion seasons, construction in winter, multiple workers on one building, and impossible relationships between assignments, completion records and phase. In opening/work phases, completed buildings must come from earlier seasons. In resolved phases, a construction assignment must have the matching current-season completion record; do not accept a completion record for a current-season building with no matching assignment. Legacy saves have no construction assignments. Preserve existing bounds, history, crops, obligations and affordability validation.

Atomic saves, damaged-save recovery and confirmed restart remain in force. Preserve both migrated and current building state across quit/relaunch. Do not erase or rewrite the live household merely to demonstrate the new features.

## Validation and acceptance

1. Replay existing reference years without construction, comparing every numeric outcome, projection and ending after explicit schema normalization. Browser unit tests/build remain green.
2. Add rules tests for draft/cancel, affordability before future income, duplicate builders, reserved workers, completion exactly once, winter rejection and completion timing. Check two buildings in one turn, root-cellar purchases in completion versus following seasons, and woodshed winter consumption with shelter on either side of the cold threshold. Forecast/report/final-state numbers must match.
3. Test valid v1 migration at every fixture phase, v2 round trips at draft and completed states, unknown future versions, malformed construction records, winter event relationships under reduced weathering, failed migration backup and unchanged original bytes on failure.
4. Verify the native app at default and minimum window sizes: world dominates, no outer scrolling page, selection and keyboard equivalents work, costs remain readable, conversations and phase changes do not trap outgoing views, and forecasts/confirmation remain reachable. Check missing art preserves usable controls and a visible warning.
5. Play a complete native year with each building at least once across representative runs, verify visible stages and completion, quit/relaunch during a construction draft and after completion, and verify completed effects/rewards do not replay. Check system/app reduced motion and inactivity/audio behavior. Capture screenshots of the HUD, inspector, active plot, completed buildings and winter scene.
6. Build/package the `.app`, verify resources and development signature, and document actual test/runtime results and any unavailable checks. No distribution, notarization, historical-art certification or player-enjoyment claim.

## Scope boundaries and risks

This pass does not add the workshop, a multi-year economy, free placement, a world map, villagers walking, multiplayer, mobile/Windows or a new engine. The primary risk is losing the quiet household identity under unnecessary strategy-game UI; the scene, three people and their promises must remain legible. The other material risks are art mismatch, unbalanced building payoffs and save migration errors. Dedicated asset inspection, rules tests and preservation of old save bytes address those risks; player testing is still required for enjoyment and balance confidence.
