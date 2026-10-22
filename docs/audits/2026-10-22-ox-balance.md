# Ox agreement balance audit

22 October 2026. Applied change: **ox hire costs 5 money instead of 6**. All other numerical tuning, event effects, task rules and ending thresholds are unchanged.

## Finding and correction

At a six-money hire price, paying for the ox produced no globally nondominated secure resource outcome in any of the eight narrative profiles examined. For every secure paid-route outcome retained by the search, some other route could finish with at least as much food, money and shelter, and strictly more of at least one. This compares terminal resources, not emotional value or every intermediate position.

The simple reason appears in matched farm plans: paying six upfront and using the free autumn worker for six-money wages cancels out. Honouring instead gets two food from the reserved helping assignment; both routes still receive six food of winter aid. Paying therefore ended with equal money and two less food in that comparison.

A price of **five** restores a modest cash advantage for paying, at the cost of some food and spring liquidity. It adds a distinct resource outcome without increasing crop yield, making friendship mandatory, or inventing another penalty for breaking a promise. Each of the four routes now has at least one nondominated secure resource outcome in all eight examined profiles.

## Matched work plan

This comparison accepts the spring grain, leaves Petru’s separate purse undecided, defers the boundary settlement, asks for winter aid when offered, and skips the feast. Assign:

| Season | Ion     | Ana       | Petru                                  |
| ------ | ------- | --------- | -------------------------------------- |
| Spring | Plant   | Repair    | Paid work                              |
| Summer | Tend    | Paid work | Buy supplies                           |
| Autumn | Harvest | Harvest   | Help if honouring; paid work otherwise |
| Winter | Repair  | Paid work | Paid work                              |

All routes finish secure, without hardship, at **62 shelter**. Ending stocks:

| Agreement         | Food | Money before adjustment | Money after adjustment | Specific trade-off                                                               |
| ----------------- | ---: | ----------------------: | ---------------------: | -------------------------------------------------------------------------------- |
| Borrow and honour |   34 |                      26 |                     26 | Most food in this plan; autumn worker is committed.                              |
| Pay               |   32 |                      26 |                     27 | Pay now; retain autumn flexibility and a little more final cash than honouring.  |
| Decline           |   22 |                      32 |                     32 | Keep spring cash and all workers; smaller harvest.                               |
| Borrow and break  |   26 |                      32 |                     32 | Keep the crop benefit and worker; lose winter aid and record the broken promise. |

The broken route has more food than declining in this particular farming plan, but a worse relationship memory. That is an intentional temptation, not something to erase with a punitive hidden rule. Declining also has a separate cash-oriented strategy below.

## Search method and limits

The reproducible analyzer uses the actual `dispatch`, `taskOptions`, `assignmentProblem`, `preview`, `currentEvent` and `ending` functions. It does not maintain a second resource simulator.

- Compare all four routes under eight fixed narrative profiles: accept/decline spring grain × agree/defer Petru’s purse × settle/defer the boundary.
- Take winter aid whenever it is available and choose the ordinary winter meal. Refusing free winter aid or paying for a celebration is not included in the resource optimization; those remain expressive choices.
- Enumerate legal task **multisets** for each season. Workers have equal capacity; permutations do not change resources. Honouring fixes Petru to help and enumerates only the other two assignments.
- Reject unaffordable choices/assignments through the production validators. Unexpected errors propagate rather than being swallowed.
- After each season, prune states that have no more food, money or shelter than another state with the same crop flags and presence/absence of food and shelter hardship. At least one witness work plan is retained. For this model and these fixed event policies, those flags cover later resource-relevant branches; trust has no mechanical effect on winter aid.
- Compare secure endings across all four routes using food, money and shelter. Memories, player preferences, timing of cash and cognitive difficulty are not assigned a score.
- A count below is a count of **unique resource triples**, not a number of all possible runs, a probability, or a player success rate. The search is exhaustive within the stated policies and symmetry/pruning assumptions, not across all narrative choices or every possible player objective.

The analyzer loads a temporary Vite transform to compare a different hire price. It never edits product files. The JSON records source-file hashes and the applied price separately: hashes identify the source on disk, while the price may be overridden in memory. Trust or rule changes require reviewing the pruning assumptions before reusing the result.

## Comparison across narrative profiles

Each cell lists nondominated secure outcomes in this order: **honour / break / pay / decline**.

| Spring grain · Petru · boundary | Six-money hire  | Five-money hire  |
| ------------------------------- | --------------- | ---------------- |
| Accept · defer · defer          | 31 / 16 / 0 / 4 | 31 / 16 / 22 / 4 |
| Accept · agree · defer          | 28 / 16 / 0 / 4 | 28 / 16 / 22 / 4 |
| Accept · defer · settle         | 28 / 16 / 0 / 4 | 28 / 16 / 22 / 4 |
| Accept · agree · settle         | 26 / 16 / 0 / 4 | 26 / 16 / 21 / 4 |
| Decline · defer · defer         | 27 / 8 / 0 / 4  | 27 / 8 / 14 / 4  |
| Decline · agree · defer         | 24 / 8 / 0 / 8  | 24 / 8 / 14 / 8  |
| Decline · defer · settle        | 24 / 8 / 0 / 4  | 24 / 8 / 14 / 4  |
| Decline · agree · settle        | 22 / 8 / 0 / 8  | 22 / 8 / 13 / 8  |

A four-money candidate was also explored in the initial accept/defer/defer profile. It reduced the honour/break frontier counts from 31/16 to 27/8 while paying retained 23. Five is the smaller intervention that met the acceptance condition across all eight profiles; a larger discount is not supported by a need shown here.

## Other findings retained for playtesting

**Wages are a viable alternative to farming.** In the accept/defer/defer profile, declining, never planting, taking wage work and purchasing supplies can finish secure with 55 money, 5 food and 42 shelter. The witness plan is in the results JSON. This maximizes cash, not food or every objective. Farming still supports substantially larger food reserves. We did not force planting or nerf wages simply to make one intended strategy compulsory. Ask testers whether skipping the field makes the household feel less interesting.

**The early food bridge matters.** Starting food 18 minus seed 4, two seasons of meals 18, plus the spring gift 3 leaves a one-food shortfall before the harvest unless some work brings in food. Plant/repair/wages followed by tend/wages/repair is therefore hungry even after accepting the gift. The matched plan above buys supplies in summer. The forecast already warns about shortages. Watch whether testers understand this, rather than silently increasing initial food and removing the trade-off.

**Trust is currently descriptive state.** Winter aid checks `ox === 'broken'`, not the trust meter. Accepting a gift or helping does not buy forgiveness for a broken harvest promise. The UI should not imply a hidden numerical friendship threshold. A broader relationship simulation is outside this change.

**A single food hardship causes the crisis category**, even if stocks recover later. That is the current explicit rule and is explained in How to play. This audit does not revise it; player reactions should inform any future classification change.

## Verification and reproduction

The regression test in `tests/balance-paths.test.ts` plays the matched plan through all four routes and eight narrative profiles, round-tripping saves after each season. It verifies secure endings, distinct trade-offs and winter refusal after breaking. It also verifies that an existing six-money paid snapshot retains its recorded money; it is neither charged again nor refunded after this tuning change.

The new trade-off assertions failed against the old price in all eight profiles, then passed with five. An existing stale-click test had its fixed old-price expectation updated to the centralized balance value. Final checks: 66 unit tests, 11 browser tests, production build. Human playtesting has not occurred.

From the repository root:

```sh
node docs/audits/ox-balance.mjs
AUDIT_OX_PRICE=6 node docs/audits/ox-balance.mjs
AUDIT_OX_PRICE=5 AUDIT_PROFILE=independent-share-settle node docs/audits/ox-balance.mjs
```

`AUDIT_PROFILE` accepts `gift|independent`, `listen|share`, `defer|settle`, separated by hyphens. `AUDIT_OX_PRICE` accepts 4, 5 or 6; omission uses the actual current tuning. JSON with complete frontier witnesses is written to `/tmp/razes-balance-audit-<price>-<profile>.json`; set `AUDIT_OUTPUT` to choose another destination. The saved summary is [2026-10-22-ox-balance-results.json](2026-10-22-ox-balance-results.json); the generator is [ox-balance.mjs](ox-balance.mjs).
