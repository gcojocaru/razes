import { expect, it } from 'vitest';
import {
  newGame,
  dispatch,
  currentEvent,
  choiceProblem,
  taskOptions,
  assignmentProblem,
  preview,
} from '../src/game/rules';
import { decodeSave, encodeSave } from '../src/game/save';
import { WORKERS, type GameState, type Action } from '../src/game/types';

it('400 varied affordable household strategies finish, resume and preserve resource invariants', () => {
  const events = new Set<string>(),
    tasks = new Set<string>();
  let seed = 421;
  const pick = <T>(values: T[]): T => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return values[seed % values.length];
  };
  for (let run = 0; run < 400; run++) {
    let s = newGame();
    const act = (a: Omit<Action, 'revision'>) => {
      s = dispatch(s, { ...a, revision: s.revision });
      expect(s.food).toBeGreaterThanOrEqual(0);
      expect(s.money).toBeGreaterThanOrEqual(0);
      expect(s.house).toBeGreaterThanOrEqual(0);
      expect(s.house).toBeLessThanOrEqual(100);
      const resumed = decodeSave(encodeSave(s));
      expect(resumed).toEqual(s);
      s = resumed;
    };
    for (let season = 0; season < 4; season++) {
      const opening = currentEvent(s);
      events.add(opening.id);
      const choice = pick(opening.choices.filter((c) => !choiceProblem(s, c)));
      act({ type: 'choose', event: opening.id, choice: choice.id });
      for (const w of WORKERS) {
        if (s.reservedWorker === w) continue;
        const task = pick(
          taskOptions(s).filter((t) => !assignmentProblem(s, w, t.id)),
        );
        tasks.add(task.id);
        act({ type: 'assign', worker: w, task: task.id });
      }
      if (preview(s).errors.length) {
        for (const w of WORKERS)
          if (s.assignments[w] === 'harvest')
            act({ type: 'assign', worker: w, task: 'rest' });
      }
      expect(preview(s).errors).toEqual([]);
      act({ type: 'resolve' });
      const evening = currentEvent(s);
      events.add(evening.id);
      const response = pick(
        evening.choices.filter((c) => !choiceProblem(s, c)),
      );
      act({ type: 'choose', event: evening.id, choice: response.id });
      act({ type: 'continue' });
    }
    expect(s.phase).toBe('ending');
    expect(s.history).toHaveLength(8);
  }
  expect(events.size).toBe(12);
  expect(tasks.size).toBe(8);
});
