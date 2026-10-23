import { writeFileSync } from 'node:fs';
import { BALANCE, TASKS, PEOPLE } from '../src/game/balance';
import { EVENTS } from '../src/game/content';
import {
  newGame,
  dispatch,
  currentEvent,
  choiceProblem,
  taskOptions,
  assignmentProblem,
  preview,
  ending,
} from '../src/game/rules';
import { presentation } from '../src/scene/presentation';
import { WORKERS, type Action } from '../src/game/types';
const root = 'native/macos/';
writeFileSync(
  root + 'Sources/RazesCore/Resources/content.json',
  JSON.stringify(
    { balance: BALANCE, tasks: TASKS, people: PEOPLE, events: EVENTS },
    null,
    2,
  ) + '\n',
);
let seed = 421;
const pick = <T>(values: T[]) => {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return values[seed % values.length];
};
const runs = [];
const categories = new Set<string>(),
  ox = new Set<string>(),
  fields = new Set<string>();
for (let run = 0; run < 40; run++) {
  let s = newGame();
  const steps: unknown[] = [];
  const act = (a: Omit<Action, 'revision'>) => {
    const action = { ...a, revision: s.revision };
    s = dispatch(s, action);
    const p = presentation(s);
    fields.add(p.field);
    steps.push({ action, state: s, projection: preview(s), presentation: p });
  };
  for (let season = 0; season < 4; season++) {
    const event = currentEvent(s),
      c = pick(event.choices.filter((c) => !choiceProblem(s, c)));
    act({ type: 'choose', event: event.id, choice: c.id });
    for (const worker of WORKERS) {
      if (s.reservedWorker === worker) continue;
      const task = pick(
        taskOptions(s).filter((t) => !assignmentProblem(s, worker, t.id)),
      );
      act({ type: 'assign', worker, task: task.id });
    }
    if (preview(s).errors.length)
      for (const worker of WORKERS)
        if (s.assignments[worker] === 'harvest')
          act({ type: 'assign', worker, task: 'rest' });
    act({ type: 'resolve' });
    const evening = currentEvent(s),
      response = pick(evening.choices.filter((c) => !choiceProblem(s, c)));
    act({ type: 'choose', event: evening.id, choice: response.id });
    act({ type: 'continue' });
  }
  const end = ending(s);
  categories.add(end.category);
  ox.add(s.ox);
  runs.push({ steps, ending: end });
}
if (
  categories.size !== 3 ||
  !['honoured', 'broken', 'paid', 'declined'].every((x) => ox.has(x)) ||
  fields.size !== 6
)
  throw Error('Incomplete fixture coverage');
writeFileSync(
  root + 'Tests/RazesCoreTests/Fixtures/parity.json',
  JSON.stringify({ initial: newGame(), runs }) + '\n',
);
console.log(
  `Exported ${runs.length} years, ${categories.size} endings, ${fields.size} field states`,
);
