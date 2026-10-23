# Weekly calendar and grain harvest

The user approved weekly work, separate seeds, visible crop growth and tending, harvest rewards, and the full calendar. Based on main commit `85b740a` (house supplies and paintable farmland). This extends the native Mac settlement; the browser story remains independent. SwiftUI, SpriteKit and RazesCore remain the implementation, with no new dependencies.

## Approach

Use the existing planning → resolution → report loop once per week. Cosmetic weeks inside a seasonal turn would not provide weekly farming decisions; separate real-time timers would conflict with the turn-based game. Each season has three numbered months of four weeks, twelve weeks per season and 48 per repeating year. Keep `turn` as the season ordinal for existing building records and add `week` (0–11) plus derived month/week labels.

All painted farmland shares one grain crop cycle and consumes 4 separate seeds when sowing in spring. New settlements have 8 seeds; seeds cost 1 coin each, are bought immediately, and occupy separate storage like food. Grain ages on resolved growing weeks, including sowing, and ripens after 24 weeks. Stages are sown (weeks 1–2), sprouting (3–4), growing (5–23), ripe (24), and harvested. Tend once while growing after sprouting for +8 food and +2 seeds. Harvest once when ripe before winter for 20 food and 4 seeds, or 28 food and 6 seeds when tended. Unharvested crops are lost in winter; spring resets the field. Show growth, weeks remaining, seed cost and projected rewards in the field inspector and forecast. Reuse main’s painted farmland rendering; add a shorter stalk stage for sprouting. No fixed field sprite remains. Seed costs and yields do not scale with painted area.

Food consumption is monthly: 3 at weeks 4, 8 and 12 (winter woodshed/cold modifiers apply). Shelter weathering, completed-building production/wear and foundation completion remain seasonal at week 12. Wages become 1 coin per week; gathering becomes up to 2 wood or 1 stone per week. Existing provision and repair prices/yields remain. These are initial balance values, not playtested tuning.

## Scope and constraints

Update core state, rules, validation, presentation, forecasts, native controls/help, seed purchases, save filename, tests and documentation. Preserve stale-action protection, atomic edits, storage and money reservations, accessibility and reduced-motion behavior. No crop catalog, multiple fields, offline timers or new assets/dependencies.

Per the user's project rule, the app is unreleased and progress may reset: use schema 9 and `settlement-v9.json`, with no migration or compatibility layer.
