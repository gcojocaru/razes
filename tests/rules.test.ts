import { describe, expect, it } from 'vitest';
import { BALANCE } from '../src/game/balance';
import {
  newGame,
  dispatch,
  currentEvent,
  preview,
  ending,
  taskOptions,
} from '../src/game/rules';
import type { GameState, Action, TaskId, WorkerId } from '../src/game/types';

const act = (s: GameState, action: Omit<Action, 'revision'>) =>
  dispatch(s, { ...action, revision: s.revision } as Action);
const choose = (s: GameState, choice: string) =>
  act(s, { type: 'choose', event: currentEvent(s).id, choice });
function assign(s: GameState, worker: WorkerId, task: TaskId) {
  return act(s, { type: 'assign', worker, task });
}
function resolve(s: GameState, choice?: string) {
  s = act(s, { type: 'resolve' });
  s = choose(
    s,
    choice ??
      currentEvent(s).choices.find(
        (c) => c.id === 'accept' || c.id === 'keep' || c.id === 'together',
      )!.id,
  );
  return act(s, { type: 'continue' });
}
function year(ox: 'borrow' | 'pay' | 'decline', honour = true) {
  let s = choose(newGame(), ox);
  s = assign(s, 'ion', 'plant');
  s = assign(s, 'ana', 'repair');
  s = assign(s, 'petru', 'paid');
  s = resolve(s, 'keep');
  s = choose(s, 'share');
  s = assign(s, 'ion', 'tend');
  s = assign(s, 'ana', 'paid');
  s = assign(s, 'petru', 'repair');
  s = resolve(s, 'accept');
  s = choose(s, ox === 'borrow' ? (honour ? 'honour' : 'break') : 'prepare');
  s = assign(s, 'ion', 'harvest');
  s = assign(s, 'ana', 'harvest');
  if (!s.reservedWorker) s = assign(s, 'petru', 'paid');
  s = resolve(s, 'settle');
  s = choose(s, ox === 'borrow' && !honour ? 'endure' : 'ask');
  s = assign(s, 'ion', 'repair');
  s = assign(s, 'ana', 'supplies');
  s = assign(s, 'petru', 'paid');
  return resolve(s, 'together');
}

describe('complete deterministic year', () => {
  it.each([
    ['borrow', true],
    ['borrow', false],
    ['pay', true],
    ['decline', true],
  ] as const)(
    '%s / honour %s reaches an ending with eight encounters',
    (ox, honour) => {
      const s = year(ox, honour);
      expect(s.phase).toBe('ending');
      expect(s.history).toHaveLength(8);
      expect(s.food).toBeGreaterThanOrEqual(0);
      expect(s.money).toBeGreaterThanOrEqual(0);
      expect(s.house).toBeGreaterThanOrEqual(0);
      expect(s.house).toBeLessThanOrEqual(100);
      expect(ending(s).decisions).toHaveLength(3);
    },
  );
  it('honouring leads to winter help and breaking removes it', () => {
    const honoured = year('borrow'),
      broken = year('borrow', false);
    expect(honoured.ox).toBe('honoured');
    expect(broken.ox).toBe('broken');
    expect(
      honoured.history.some(
        (h) => h.event === 'winter-friend' && h.choice === 'ask',
      ),
    ).toBe(true);
    expect(broken.history.some((h) => h.event === 'winter-isolation')).toBe(
      true,
    );
  });
  it('borrowing and paying give the same crop bonus, declining gives less', () => {
    const planted = (choice: string) => {
      let s = choose(newGame(), choice);
      s = assign(s, 'ion', 'plant');
      return act(s, { type: 'resolve' });
    };
    expect(planted('borrow').cropBonus).toBe(planted('pay').cropBonus);
    expect(planted('borrow').cropBonus).toBeGreaterThan(
      planted('decline').cropBonus,
    );
  });
});

describe('validating actions and ordering', () => {
  it('rejects stale repeated event choices without charging twice', () => {
    const start = newGame();
    const action = {
      type: 'choose',
      event: currentEvent(start).id,
      choice: 'pay',
      revision: 0,
    } as const;
    const paid = dispatch(start, action);
    expect(paid.money).toBe(start.money - BALANCE.oxPrice);
    expect(() => dispatch(paid, action)).toThrow();
    expect(start.money).toBe(12);
  });
  it('rejects wrong events and unknown choices', () => {
    expect(() =>
      act(newGame(), { type: 'choose', event: 'winter-friend', choice: 'ask' }),
    ).toThrow();
    expect(() => choose(newGame(), 'imaginary')).toThrow();
  });
  it('rejects unaffordable choices and assignments', () => {
    const s = { ...newGame(), money: 0 };
    expect(() => choose(s, 'pay')).toThrow();
    const work = choose(s, 'decline');
    expect(() => assign(work, 'ion', 'repair')).toThrow();
  });
  it('validates combined assignment spending and supports revising', () => {
    let s = choose({ ...newGame(), money: 5 }, 'decline');
    s = assign(s, 'ion', 'repair');
    expect(() => assign(s, 'ana', 'repair')).toThrow();
    s = assign(s, 'ion', 'rest');
    expect(assign(s, 'ana', 'supplies').assignments.ana).toBe('supplies');
  });
  it('does not spend future paid-work income before it exists', () => {
    let s = choose({ ...newGame(), money: 0 }, 'decline');
    s = assign(s, 'ion', 'paid');
    expect(() => assign(s, 'ana', 'supplies')).toThrow();
  });
  it('requires two harvesters and never awards harvest twice', () => {
    let s: GameState = {
      ...choose(newGame(), 'decline'),
      season: 2 as const,
      planted: true,
      tended: true,
    };
    s = assign(s, 'ion', 'harvest');
    expect(preview(s).errors.length).toBeGreaterThan(0);
    expect(() => act(s, { type: 'resolve' })).toThrow();
    s = assign(s, 'ana', 'harvest');
    expect(preview(s).foodGain).toBe(28);
    const resolved = act(s, { type: 'resolve' });
    expect(resolved.harvested).toBe(true);
    expect(() => act(resolved, { type: 'resolve' })).toThrow();
  });
  it('reserves exactly one worker for an honoured obligation', () => {
    let s: GameState = {
      ...newGame(),
      season: 2 as const,
      ox: 'borrowed' as const,
      planted: true,
    };
    s = choose(s, 'honour');
    expect(s.reservedWorker).toBe('petru');
    expect(s.assignments.petru).toBe('help');
    expect(() => assign(s, 'petru', 'paid')).toThrow();
    s = assign(s, 'ion', 'harvest');
    s = assign(s, 'ana', 'harvest');
    expect(preview(s).errors).toHaveLength(0);
    expect(act(s, { type: 'resolve' }).phase).toBe('consequence');
  });
  it('rejects duplicate planting and wrong-season work', () => {
    let s = choose(newGame(), 'decline');
    s = assign(s, 'ion', 'plant');
    expect(() => assign(s, 'ana', 'plant')).toThrow();
    expect(() => assign(s, 'ana', 'harvest')).toThrow();
  });
  it('keeps seed and projected consumption visible without mutating state', () => {
    const s = assign(choose(newGame(), 'borrow'), 'ion', 'plant');
    const snapshot = JSON.stringify(s);
    const p = preview(s);
    expect(p.foodCost).toBe(4);
    expect(p.consumption).toBe(9);
    expect(JSON.stringify(s)).toBe(snapshot);
    expect(p.foodAfter).toBe(5);
  });
  it('applies consequence relief before seasonal consumption', () => {
    let s = choose({ ...newGame(), food: 6 }, 'decline');
    s = act(s, { type: 'resolve' });
    expect(s.food).toBe(6);
    s = choose(s, 'share');
    expect(s.food).toBe(0);
    expect(s.hardship).toHaveLength(0);
  });
  it('records shortages without ending the year early and clamps stocks', () => {
    let s = choose({ ...newGame(), food: 0 }, 'decline');
    s = act(s, { type: 'resolve' });
    s = choose(s, 'keep');
    expect(s.food).toBe(0);
    expect(s.hardship.length).toBeGreaterThan(0);
    expect(s.phase).toBe('summary');
    expect(act(s, { type: 'continue' }).season).toBe(1);
  });
  it('uses winter shelter to determine additional food consumption', () => {
    const s = {
      ...choose(newGame(), 'decline'),
      season: 3 as const,
      house: 25,
    };
    expect(preview(s).consumption).toBe(12);
    expect(taskOptions(s).some((t) => t.id === 'plant')).toBe(false);
  });
  it('caps repairs at 100 condition', () => {
    let s = choose({ ...newGame(), house: 95 }, 'decline');
    s = assign(s, 'ana', 'repair');
    expect(act(s, { type: 'resolve' }).house).toBe(100);
  });
});

describe('endings', () => {
  const s = { ...newGame(), phase: 'ending' as const, season: 3 as const };
  it('requires seed and shelter for security', () =>
    expect(ending({ ...s, food: 4, house: 40 }).category).toBe('secure'));
  it('distinguishes survival without seed', () =>
    expect(ending({ ...s, food: 3, house: 40 }).category).toBe('cost'));
  it('calls unsafe shelter a crisis', () =>
    expect(ending({ ...s, food: 12, house: 19 }).category).toBe('crisis'));
});

it('includes Petru’s promised provisions in the autumn projection', () => {
  const s: GameState = {
    ...newGame(),
    season: 2,
    phase: 'work',
    ox: 'declined',
    fairShare: true,
  };
  const p = preview(s);
  const next = act(s, { type: 'resolve' });
  expect(p.foodGain).toBe(2);
  expect(next.food - s.food).toBe(p.foodGain - p.foodCost);
});
it('helping the neighbour creates a named memory', () => {
  let s = choose(newGame(), 'decline');
  s = assign(s, 'ion', 'help');
  s = act(s, { type: 'resolve' });
  expect(s.memories.some((m) => m.title === 'A hand across the fence')).toBe(
    true,
  );
});
