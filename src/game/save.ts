import { EVENTS } from './content';
import { TASKS, BALANCE as B } from './balance';
import { WORKERS, type GameState } from './types';
export const SAVE_KEY = 'razes.household.v1';
type ReadStorage = Pick<Storage, 'getItem'>;
type WriteStorage = Pick<Storage, 'setItem'>;
const record = (v: unknown): v is Record<string, unknown> =>
  v !== null && typeof v === 'object' && !Array.isArray(v);
const integer = (v: unknown, min = 0, max = 100000) =>
  Number.isInteger(v) && Number(v) >= min && Number(v) <= max;
const text = (v: unknown) => typeof v === 'string' && v.length <= 2000;
function ensure(value: unknown): asserts value {
  if (!value)
    throw new Error(
      'This save is invalid or incomplete. You can start a fresh household.',
    );
}
export function encodeSave(s: GameState): string {
  return JSON.stringify(s);
}
export function decodeSave(raw: string): GameState {
  let s: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(raw);
    ensure(record(parsed));
    s = parsed;
  } catch {
    throw new Error(
      'This save could not be read. You can start a fresh household.',
    );
  }
  if (s.version !== 1)
    throw new Error(
      'This save belongs to an unsupported version. You can start a fresh household.',
    );
  ensure(
    integer(s.revision) &&
      integer(s.season, 0, 3) &&
      integer(s.food) &&
      integer(s.money) &&
      integer(s.house, 0, 100) &&
      integer(s.trust, -5, 5),
  );
  ensure(
    ['opening', 'work', 'consequence', 'summary', 'ending'].includes(
      String(s.phase),
    ),
  );
  ensure(
    ['none', 'borrowed', 'paid', 'declined', 'honoured', 'broken'].includes(
      String(s.ox),
    ),
  );
  for (const key of ['planted', 'tended', 'harvested', 'fairShare'])
    ensure(typeof s[key] === 'boolean');
  ensure(s.cropBonus === 0 || s.cropBonus === B.oxBonus);
  ensure(record(s.assignments) && Object.keys(s.assignments).length === 3);
  const assignments = s.assignments as Record<string, unknown>;
  for (const w of WORKERS)
    ensure(
      typeof assignments[w] === 'string' &&
        Object.hasOwn(TASKS, assignments[w] as string),
    );
  ensure(
    s.reservedWorker === null ||
      (s.reservedWorker === 'petru' &&
        s.season === 2 &&
        s.ox === 'honoured' &&
        assignments.petru === 'help'),
  );
  ensure(!s.tended || s.planted);
  ensure(!s.harvested || (s.planted && Number(s.season) >= 2));
  ensure(!(s.season === 0 && s.tended));
  ensure(s.planted || s.cropBonus === 0);
  ensure(s.phase !== 'ending' || s.season === 3);
  ensure(s.ox !== 'none' || (s.season === 0 && s.phase === 'opening'));
  ensure(Array.isArray(s.history) && s.history.length <= 8);
  const seen = new Set<string>();
  for (const h of s.history) {
    ensure(
      record(h) &&
        text(h.event) &&
        text(h.choice) &&
        text(h.title) &&
        text(h.detail) &&
        integer(h.season, 0, 3),
    );
    const event = EVENTS[String(h.event)];
    ensure(
      event &&
        event.choices.some((c) => c.id === h.choice) &&
        !seen.has(String(h.event)),
    );
    seen.add(String(h.event));
  }
  const expected =
    Number(s.season) * 2 +
    (s.phase === 'opening'
      ? 0
      : s.phase === 'work' || s.phase === 'consequence'
        ? 1
        : 2);
  ensure(s.history.length === expected);
  ensure(Array.isArray(s.memories) && s.memories.length <= 12);
  for (const m of s.memories)
    ensure(
      record(m) &&
        text(m.id) &&
        text(m.title) &&
        text(m.detail) &&
        integer(m.season, 0, 3) &&
        ['good', 'bad', 'neutral'].includes(String(m.tone)),
    );
  ensure(Array.isArray(s.hardship) && s.hardship.length <= 8);
  for (const h of s.hardship)
    ensure(
      record(h) &&
        integer(h.season, 0, 3) &&
        ['food', 'shelter'].includes(String(h.kind)) &&
        integer(h.amount, 1),
    );
  if (['consequence', 'summary', 'ending'].includes(String(s.phase))) {
    ensure(record(s.report));
    for (const key of [
      'foodBefore',
      'foodAfter',
      'moneyBefore',
      'moneyAfter',
      'houseBefore',
      'houseAfter',
      'consumption',
      'wear',
      'deficit',
    ])
      ensure(integer(s.report[key]));
    ensure(
      Array.isArray(s.report.tasks) &&
        s.report.tasks.length === 3 &&
        s.report.tasks.every(text),
    );
  } else ensure(s.report === null);
  const state = s as unknown as GameState;
  validateProgress(state);
  return state;
}
export function loadGame(storage: ReadStorage): {
  state: GameState | null;
  error: string | null;
} {
  let raw: string | null;
  try {
    raw = storage.getItem(SAVE_KEY);
  } catch {
    return {
      state: null,
      error:
        'Browser storage is unavailable. You can play, but this run cannot be saved.',
    };
  }
  if (raw === null) return { state: null, error: null };
  try {
    return { state: decodeSave(raw), error: null };
  } catch (e) {
    return {
      state: null,
      error: e instanceof Error ? e.message : 'This save could not be read.',
    };
  }
}
export function saveGame(storage: WriteStorage, state: GameState): boolean {
  try {
    storage.setItem(SAVE_KEY, encodeSave(state));
    return true;
  } catch {
    return false;
  }
}

/** Check relationships, not only field shapes: damaged saves must not resume into a dead end. */
function validateProgress(s: GameState): void {
  const opening = s.history.find((h) => h.event === 'spring-ox');
  const autumn = s.history.find((h) => h.event === 'autumn-promise');
  const expectedOx = !opening
    ? 'none'
    : opening.choice === 'pay'
      ? 'paid'
      : opening.choice === 'decline'
        ? 'declined'
        : !autumn
          ? 'borrowed'
          : autumn.choice === 'honour'
            ? 'honoured'
            : 'broken';
  ensure(s.ox === expectedOx);
  const expectedEvents = [
    'spring-ox',
    'spring-table',
    'summer-brother',
    s.tended ? 'summer-tended' : 'summer-dry',
    opening?.choice === 'borrow' ? 'autumn-promise' : 'autumn-free',
    'autumn-dispute',
    expectedOx === 'broken' ? 'winter-isolation' : 'winter-friend',
    s.house + B.wear[3] < B.coldThreshold ? 'winter-cold' : 'winter-hearth',
  ];
  s.history.forEach((h, i) =>
    ensure(h.event === expectedEvents[i] && h.season === Math.floor(i / 2)),
  );
  ensure(
    s.fairShare ===
      s.history.some(
        (h) => h.event === 'summer-brother' && h.choice === 'share',
      ),
  );
  const reserved = s.season === 2 && s.ox === 'honoured';
  ensure(s.reservedWorker === (reserved ? 'petru' : null));
  if (reserved) ensure(s.assignments.petru === 'help');
  const assigned = Object.values(s.assignments);
  const count = (task: string) => assigned.filter((t) => t === task).length;
  ensure(count('plant') <= 1 && count('tend') <= 1 && count('harvest') <= 2);
  if (s.phase === 'opening') ensure(assigned.every((t) => t === 'rest'));
  for (const task of assigned) {
    if (task === 'plant') ensure(s.season === 0);
    if (task === 'tend') ensure(s.season === 1 && s.planted);
    if (task === 'harvest') ensure(s.season === 2 && s.planted);
  }
  const resolved = ['consequence', 'summary', 'ending'].includes(s.phase);
  if (resolved) ensure(count('harvest') !== 1);
  if (s.season === 0) ensure(s.planted === (resolved && count('plant') === 1));
  if (s.season <= 1)
    ensure(s.tended === (s.season === 1 && resolved && count('tend') === 1));
  if (s.season <= 2)
    ensure(
      s.harvested === (s.season === 2 && resolved && count('harvest') === 2),
    );
  ensure(
    s.cropBonus ===
      (s.planted && opening?.choice !== 'decline' ? B.oxBonus : 0),
  );
  if (s.phase === 'work') {
    ensure(
      assigned.reduce((cost, t) => cost + TASKS[t].moneyCost, 0) <= s.money,
    );
    ensure(assigned.reduce((cost, t) => cost + TASKS[t].foodCost, 0) <= s.food);
  }
}
