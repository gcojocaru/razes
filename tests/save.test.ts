import { expect, it } from 'vitest';
import { newGame, dispatch, currentEvent } from '../src/game/rules';
import {
  encodeSave,
  decodeSave,
  loadGame,
  saveGame,
  SAVE_KEY,
} from '../src/game/save';

it('round trips every phase without applying any effects', () => {
  let s = newGame();
  for (let season = 0; season < 4; season++) {
    expect(decodeSave(encodeSave(s))).toEqual(s);
    const e = currentEvent(s);
    const c =
      e.choices.find((c) => !(c.effect.money || c.effect.food)) ??
      e.choices.at(-1)!;
    s = dispatch(s, {
      type: 'choose',
      event: e.id,
      choice: c.id,
      revision: s.revision,
    });
    expect(decodeSave(encodeSave(s))).toEqual(s);
    s = dispatch(s, { type: 'resolve', revision: s.revision });
    expect(decodeSave(encodeSave(s))).toEqual(s);
    const evening = currentEvent(s);
    const free =
      evening.choices.find((c) => !c.effect.money && !c.effect.food) ??
      evening.choices[0];
    s = dispatch(s, {
      type: 'choose',
      event: evening.id,
      choice: free.id,
      revision: s.revision,
    });
    expect(decodeSave(encodeSave(s))).toEqual(s);
    s = dispatch(s, { type: 'continue', revision: s.revision });
  }
  expect(decodeSave(encodeSave(s))).toEqual(s);
  expect(s.phase).toBe('ending');
});
it.each(['{', 'null', '[]', '{"version":0}', '{"version":99}'])(
  'rejects malformed or unsupported save %s',
  (raw) => expect(() => decodeSave(raw)).toThrow(),
);
it.each([
  { food: -1 },
  { money: Infinity },
  { house: 101 },
  { season: 4 },
  { phase: 'secret' },
  { revision: -1 },
  { planted: 'yes' },
  { ox: 'bogus' },
  { assignments: { ion: 'plant' } },
  { memories: [{}] },
  { history: [{}] },
  { hardship: [{}] },
  { report: {} },
])('rejects invalid field %j', (change) =>
  expect(() =>
    decodeSave(JSON.stringify({ ...newGame(), ...change })),
  ).toThrow(),
);
it('rejects inconsistent reserved workers and impossible crop flags', () => {
  expect(() =>
    decodeSave(JSON.stringify({ ...newGame(), reservedWorker: 'petru' })),
  ).toThrow();
  expect(() =>
    decodeSave(JSON.stringify({ ...newGame(), tended: true })),
  ).toThrow();
});
it('returns recoverable storage failure and does not throw on writes', () => {
  const storage = {
    getItem() {
      throw Error('blocked');
    },
    setItem() {
      throw Error('blocked');
    },
  };
  expect(loadGame(storage).error).toMatch(/storage/i);
  expect(saveGame(storage, newGame())).toBe(false);
});
it('distinguishes absent save from invalid save', () => {
  expect(loadGame({ getItem: () => null }).state).toBeNull();
  expect(loadGame({ getItem: () => '{' }).error).toMatch(/save/i);
});
it('stores the versioned snapshot under the app key', () => {
  const values = new Map<string, string>();
  const storage = {
    setItem(k: string, v: string) {
      values.set(k, v);
    },
  };
  expect(saveGame(storage, newGame())).toBe(true);
  expect(decodeSave(values.get(SAVE_KEY)!)).toEqual(newGame());
});

function workSave() {
  const s = newGame();
  return dispatch(s, {
    type: 'choose',
    event: 'spring-ox',
    choice: 'borrow',
    revision: s.revision,
  });
}
it('rejects a valid but out-of-order event that would dead-end the next conversation', () => {
  const s = workSave();
  s.history[0] = {
    event: 'spring-table',
    choice: 'keep',
    season: 0,
    title: 'Keep our own table',
    detail: 'A quiet beginning',
  };
  expect(() => decodeSave(JSON.stringify(s))).toThrow();
});
it('rejects wrong-season and duplicate crop assignments', () => {
  const s = workSave();
  s.assignments = { ion: 'harvest', ana: 'harvest', petru: 'rest' };
  expect(() => decodeSave(JSON.stringify(s))).toThrow();
  s.assignments = { ion: 'plant', ana: 'plant', petru: 'rest' };
  expect(() => decodeSave(JSON.stringify(s))).toThrow();
});
it('rejects current work that spends more than available stocks', () => {
  const s = workSave();
  s.money = 0;
  s.assignments.ion = 'repair';
  expect(() => decodeSave(JSON.stringify(s))).toThrow();
});
it('rejects an honoured autumn promise with its reservation removed', () => {
  let s = workSave();
  for (let season = 0; season < 2; season++) {
    s = dispatch(s, { type: 'resolve', revision: s.revision });
    const e = currentEvent(s);
    s = dispatch(s, {
      type: 'choose',
      event: e.id,
      choice: season === 0 ? 'keep' : 'accept',
      revision: s.revision,
    });
    s = dispatch(s, { type: 'continue', revision: s.revision });
    s = dispatch(s, {
      type: 'choose',
      event: currentEvent(s).id,
      choice: season === 0 ? 'listen' : 'honour',
      revision: s.revision,
    });
  }
  expect(decodeSave(JSON.stringify(s))).toEqual(s);
  s.reservedWorker = null;
  expect(() => decodeSave(JSON.stringify(s))).toThrow();
});
