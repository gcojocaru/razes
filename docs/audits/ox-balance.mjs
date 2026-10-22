import { createServer } from 'vite';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
const root = fileURLToPath(new URL('../../', import.meta.url));
const server = await createServer({
  root,
  configFile: false,
  cacheDir: '/tmp/razes-audit-vite-cache',
  optimizeDeps: { noDiscovery: true, include: [] },
  plugins: [
    {
      name: 'audit-only-price',
      enforce: 'pre',
      transform(code, id) {
        if (id.endsWith('/src/game/balance.ts') && process.env.AUDIT_OX_PRICE)
          return code.replace(
            /oxPrice: \d+,/,
            `oxPrice: ${Number(process.env.AUDIT_OX_PRICE)},`,
          );
      },
    },
  ],
  server: { middlewareMode: true, hmr: false },
  appType: 'custom',
});
const profile = process.env.AUDIT_PROFILE ?? 'gift-listen-defer';
if (!/^(gift|independent)-(listen|share)-(defer|settle)$/.test(profile))
  throw new Error('Invalid AUDIT_PROFILE');
if (process.env.AUDIT_OX_PRICE && !/^[456]$/.test(process.env.AUDIT_OX_PRICE))
  throw new Error('AUDIT_OX_PRICE must be 4, 5, or 6');
const [gift, brother, dispute] = profile.split('-');
const R = await server.ssrLoadModule('/src/game/rules.ts');
const { BALANCE: B } = await server.ssrLoadModule('/src/game/balance.ts');
const act = (s, a) => R.dispatch(s, { ...a, revision: s.revision });
function choose(s, id) {
  const e = R.currentEvent(s);
  const choice = e.choices.find((c) => c.id === id);
  if (!choice) throw new Error(`Audit choice ${id} missing from ${e.id}`);
  if (R.choiceProblem(s, choice)) return null;
  return act(s, { type: 'choose', event: e.id, choice: id });
}
function opening(s, path) {
  return choose(
    s,
    s.season === 0
      ? path === 'honour' || path === 'break'
        ? 'borrow'
        : path
      : s.season === 1
        ? brother === 'share'
          ? 'share'
          : 'listen'
        : s.season === 2
          ? path === 'honour' || path === 'break'
            ? path
            : 'prepare'
          : path === 'break'
            ? 'endure'
            : 'ask',
  );
}
function close(s) {
  s = act(s, { type: 'resolve' });
  s = choose(
    s,
    s.season === 0
      ? gift === 'gift'
        ? 'share'
        : 'keep'
      : s.season === 1
        ? 'accept'
        : s.season === 2
          ? dispute === 'settle'
            ? 'settle'
            : 'keep'
          : 'together',
  );
  return s ? act(s, { type: 'continue' }) : null;
}
function assignments(s) {
  const ids = R.taskOptions(s)
      .map((t) => t.id)
      .sort(),
    result = [];
  const n = s.reservedWorker ? 2 : 3;
  function visit(a, start) {
    if (a.length === n) {
      let trial = s;
      for (let i = 0; i < a.length; i++) {
        const worker = ['ion', 'ana', 'petru'][i];
        if (R.assignmentProblem(trial, worker, a[i])) return;
        trial = act(trial, { type: 'assign', worker, task: a[i] });
      }
      if (!R.preview(trial).errors.length) result.push(trial);
      return;
    }
    for (let i = start; i < ids.length; i++) visit([...a, ids[i]], i);
  }
  visit([], 0);
  return result;
}
function category(s) {
  return R.ending(s).category;
}
function key(s) {
  return [
    s.planted,
    s.tended,
    s.harvested,
    s.cropBonus,
    s.hardship.some((h) => h.kind === 'food'),
    s.hardship.some((h) => h.kind === 'shelter'),
  ].join('/');
}
const dominates = (a, b) =>
  a.food >= b.food && a.money >= b.money && a.house >= b.house;
function frontier(states) {
  const groups = new Map();
  for (const entry of states) {
    const s = entry.state,
      k = key(s),
      list = groups.get(k) ?? [];
    if (list.some((e) => dominates(e.state, s))) continue;
    groups.set(k, list.filter((e) => !dominates(s, e.state)).concat(entry));
  }
  return [...groups.values()].flat();
}
function record(e) {
  return {
    food: e.state.food,
    money: e.state.money,
    house: e.state.house,
    category: category(e.state),
    hardship: e.state.hardship,
    planted: e.state.planted,
    tended: e.state.tended,
    harvested: e.state.harvested,
    plan: e.plan,
  };
}
const results = {
  profile,
  balance: B,
  sourceHashes: Object.fromEntries(
    ['balance', 'content', 'rules'].map((name) => [
      name,
      createHash('sha256')
        .update(readFileSync(`${root}/src/game/${name}.ts`))
        .digest('hex'),
    ]),
  ),
  assumptions:
    'All canonical work multisets; narrative choices fixed by profile. Winter aid taken if available, no feast. Pareto prune food/money/house within crop and hardship-class flags after each season. Trust has no effect in current rules.',
  paths: {},
};
for (const path of ['honour', 'break', 'pay', 'decline']) {
  let entries = [{ state: R.newGame(), plan: [] }],
    counts = [];
  for (let season = 0; season < 4; season++) {
    const next = [];
    let branches = 0;
    for (const entry of entries) {
      const start = opening(entry.state, path);
      if (!start) continue;
      for (const worked of assignments(start)) {
        branches++;
        const end = close(worked);
        if (!end) continue;
        next.push({
          state: end,
          plan: [
            ...entry.plan,
            {
              season,
              assignments: worked.assignments,
              after: { food: end.food, money: end.money, house: end.house },
              hardship: end.hardship,
            },
          ],
        });
      }
    }
    entries = frontier(next);
    counts.push({ season, branches, retained: entries.length });
    console.error(path, season, branches, entries.length);
  }
  const secure = entries.filter((e) => category(e.state) === 'secure');
  const best = (es, metric) =>
    es.length
      ? record(es.reduce((a, b) => (metric(a.state) > metric(b.state) ? a : b)))
      : null;
  results.paths[path] = {
    counts,
    secureFrontierCount: secure.length,
    maxMoneySecure: best(secure, (s) => s.money),
    maxFoodSecure: best(secure, (s) => s.food),
    maxMoneySecureNoFarm: best(
      secure.filter((e) => !e.state.planted),
      (s) => s.money,
    ),
    maxMoneySecureFarm: best(
      secure.filter((e) => e.state.harvested),
      (s) => s.money,
    ),
    frontier: entries.map(record),
  };
}
const secureStates = Object.entries(results.paths).flatMap(([path, v]) =>
  v.frontier
    .filter((e) => e.category === 'secure')
    .map((e) => ({ path, ...e })),
);
for (const [path, v] of Object.entries(results.paths)) {
  const candidates = secureStates.filter(
    (e) =>
      e.path === path &&
      !secureStates.some(
        (other) =>
          dominates(other, e) &&
          (other.food > e.food ||
            other.money > e.money ||
            other.house > e.house),
      ),
  );
  v.globalFrontierCount = new Set(
    candidates.map((e) => [e.food, e.money, e.house].join('/')),
  ).size;
}
writeFileSync(
  process.env.AUDIT_OUTPUT ??
    `/tmp/razes-balance-audit-${B.oxPrice}-${profile}.json`,
  JSON.stringify(results, null, 2),
);
console.log(
  JSON.stringify(
    Object.fromEntries(
      Object.entries(results.paths).map(([p, v]) => [
        p,
        {
          counts: v.counts,
          globalFrontierCount: v.globalFrontierCount,
          maxMoneySecure: v.maxMoneySecure?.money,
          maxMoneySecureNoFarm: v.maxMoneySecureNoFarm?.money,
          maxFoodSecure: v.maxFoodSecure?.food,
        },
      ]),
    ),
  ),
);
await server.close();
