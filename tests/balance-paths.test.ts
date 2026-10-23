import { describe, expect, it } from 'vitest';
import { currentEvent, dispatch, ending, newGame } from '../src/game/rules';
import { decodeSave, encodeSave } from '../src/game/save';
import {
  WORKERS,
  type Action,
  type GameState,
  type TaskId,
} from '../src/game/types';

type Path = 'honour' | 'break' | 'pay' | 'decline';
const act = (s: GameState, a: Omit<Action, 'revision'>) =>
  dispatch(s, { ...a, revision: s.revision });
const choose = (s: GameState, choice: string) =>
  act(s, { type: 'choose', event: currentEvent(s).id, choice });
function matchedYear(
  path: Path,
  gift: boolean,
  share: boolean,
  settle: boolean,
) {
  let s = newGame();
  for (let season = 0; season < 4; season++) {
    s = choose(
      s,
      season === 0
        ? path === 'honour' || path === 'break'
          ? 'borrow'
          : path
        : season === 1
          ? share
            ? 'share'
            : 'listen'
          : season === 2
            ? path === 'honour' || path === 'break'
              ? path
              : 'prepare'
            : path === 'break'
              ? 'endure'
              : 'ask',
    );
    const tasks: TaskId[][] = [
      ['plant', 'repair', 'paid'],
      ['tend', 'paid', 'supplies'],
      ['harvest', 'harvest', 'paid'],
      ['repair', 'paid', 'paid'],
    ];
    for (const [i, worker] of WORKERS.entries())
      if (worker !== s.reservedWorker)
        s = act(s, { type: 'assign', worker, task: tasks[season][i] });
    s = act(s, { type: 'resolve' });
    s = choose(
      s,
      season === 0
        ? gift
          ? 'share'
          : 'keep'
        : season === 1
          ? 'accept'
          : season === 2
            ? settle
              ? 'settle'
              : 'keep'
            : 'together',
    );
    s = act(s, { type: 'continue' });
    s = decodeSave(encodeSave(s));
  }
  return s;
}

describe('ox agreement trade-offs across eight matched narrative profiles', () => {
  for (const gift of [false, true])
    for (const share of [false, true])
      for (const settle of [false, true]) {
        it(`paying preserves a little more cash than honouring, in exchange for less food (grain=${gift}, share=${share}, settlement=${settle})`, () => {
          const paths = Object.fromEntries(
            (['honour', 'break', 'pay', 'decline'] as const).map((path) => [
              path,
              matchedYear(path, gift, share, settle),
            ]),
          ) as Record<Path, GameState>;
          for (const s of Object.values(paths)) {
            expect(ending(s).category).toBe('secure');
            expect(s.hardship).toEqual([]);
            expect(s.history).toHaveLength(8);
          }
          // Reverting hire to one whole wage removes the paid route's cash advantage.
          expect(paths.pay.money).toBeGreaterThan(paths.honour.money);
          expect(paths.pay.food).toBeLessThan(paths.honour.food);
          expect(paths.pay.money).toBeLessThan(paths.decline.money);
          expect(paths.pay.food).toBeGreaterThan(paths.decline.food);
          expect(paths.break.money).toBeGreaterThan(paths.honour.money);
          expect(paths.break.food).toBeLessThan(paths.honour.food);
          expect(
            paths.break.history.some((h) => h.event === 'winter-isolation'),
          ).toBe(true);
        });
      }
  it('resumes a previously paid six-money hire without charging or refunding it', () => {
    const paid = choose(newGame(), 'pay');
    const oldSnapshot = encodeSave({ ...paid, money: 6 });
    const resumed = decodeSave(oldSnapshot);
    const assigned = act(resumed, {
      type: 'assign',
      worker: 'ion',
      task: 'plant',
    });
    expect(assigned.money).toBe(6);
    expect(
      assigned.history.filter((h) => h.event === 'spring-ox'),
    ).toHaveLength(1);
  });
});
