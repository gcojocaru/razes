import { BALANCE as B, TASKS, PEOPLE } from './balance';
import { eventFor } from './content';
import {
  WORKERS,
  SEASONS,
  type Action,
  type Choice,
  type Ending,
  type GameState,
  type Projection,
  type Season,
  type Task,
} from './types';

export const currentEvent = eventFor;
export const emptyAssignments = () =>
  ({ ion: 'rest', ana: 'rest', petru: 'rest' }) as const;
export function newGame(): GameState {
  return {
    version: 1,
    revision: 0,
    season: 0,
    phase: 'opening',
    ...B.initial,
    assignments: emptyAssignments(),
    reservedWorker: null,
    planted: false,
    tended: false,
    harvested: false,
    cropBonus: 0,
    ox: 'none',
    trust: 0,
    fairShare: false,
    memories: [],
    history: [],
    hardship: [],
    report: null,
  };
}
export function taskOptions(s: GameState): Task[] {
  const seasonal: Task[] = [];
  if (s.season === 0 && !s.planted) seasonal.push(TASKS.plant);
  if (s.season === 1 && s.planted && !s.tended) seasonal.push(TASKS.tend);
  if (s.season === 2 && s.planted && !s.harvested)
    seasonal.push({
      ...TASKS.harvest,
      foodGain: B.harvest + s.cropBonus + (s.tended ? B.tendedBonus : 0),
    });
  return [
    ...seasonal,
    TASKS.repair,
    TASKS.paid,
    TASKS.help,
    TASKS.supplies,
    TASKS.rest,
  ];
}
export function choiceProblem(s: GameState, c: Choice): string | null {
  if (s.money + (c.effect.money ?? 0) < 0)
    return `Needs ${-(c.effect.money ?? 0)} money; you have ${s.money}.`;
  if (s.food + (c.effect.food ?? 0) < 0)
    return `Needs ${-(c.effect.food ?? 0)} food; you have ${s.food}.`;
  return null;
}
export function preview(s: GameState): Projection {
  const p: Projection = {
    foodCost: 0,
    moneyCost: 0,
    foodGain: 0,
    moneyGain: 0,
    houseGain: 0,
    consumption: B.consumption,
    wear: B.wear[s.season],
    foodAfter: 0,
    moneyAfter: 0,
    houseAfter: 0,
    errors: [],
    warnings: [],
  };
  const assigned = Object.values(s.assignments);
  for (const id of assigned) {
    const task = TASKS[id];
    if (!task) {
      p.errors.push('Unknown work assignment.');
      continue;
    }
    p.foodCost += task.foodCost;
    p.moneyCost += task.moneyCost;
    p.foodGain += task.foodGain;
    p.moneyGain += task.moneyGain;
    p.houseGain += task.houseGain;
  }
  if (s.season === 2 && s.fairShare) p.foodGain += B.fairShareFood;
  const harvesters = assigned.filter((t) => t === 'harvest').length;
  if (harvesters === 1)
    p.errors.push(
      'Harvest needs two adults. Assign one more, or choose different work.',
    );
  if (harvesters > 2)
    p.errors.push(
      'Harvest needs only two adults. Give the third adult different work.',
    );
  if (harvesters === 2)
    p.foodGain += B.harvest + s.cropBonus + (s.tended ? B.tendedBonus : 0);
  if (p.moneyCost > s.money)
    p.errors.push(
      `Work costs ${p.moneyCost} money; only ${s.money} is available now.`,
    );
  if (p.foodCost > s.food)
    p.errors.push(
      `Planting needs ${p.foodCost} food for seed; only ${s.food} is available.`,
    );
  const repaired = Math.min(100, s.house + p.houseGain);
  if (s.season === 3 && repaired < B.coldThreshold) p.consumption += B.coldFood;
  p.foodAfter = s.food - p.foodCost + p.foodGain - p.consumption;
  p.moneyAfter = s.money - p.moneyCost + p.moneyGain;
  p.houseAfter = Math.max(0, repaired - p.wear);
  if (p.foodAfter < 0)
    p.warnings.push(
      `Expected food shortfall: ${-p.foodAfter}. This will be recorded as hardship unless the evening event provides relief.`,
    );
  else if (p.foodAfter < B.seed)
    p.warnings.push(
      `Only ${p.foodAfter} food after consumption. Next spring needs ${B.seed} for seed.`,
    );
  if (p.houseAfter < B.coldThreshold)
    p.warnings.push(
      'The house will be vulnerable. Cold winter shelter needs extra food.',
    );
  if (s.season === 0 && !assigned.includes('plant'))
    p.warnings.push('Without planting now, there will be no autumn harvest.');
  if (s.season === 2 && s.planted && harvesters === 0)
    p.warnings.push('The unharvested crop will be lost when winter comes.');
  return p;
}
export function assignmentProblem(
  s: GameState,
  worker: string,
  task: string,
): string | null {
  if (s.phase !== 'work')
    return 'Choose the seasonal event before assigning work.';
  if (!WORKERS.includes(worker as (typeof WORKERS)[number]))
    return 'Unknown household member.';
  if (s.reservedWorker === worker)
    return 'This adult is reserved for your promise to Vasile.';
  if (!taskOptions(s).some((t) => t.id === task))
    return 'That task is unavailable this season.';
  const assignments = { ...s.assignments, [worker]: task };
  for (const exclusive of ['plant', 'tend'])
    if (Object.values(assignments).filter((t) => t === exclusive).length > 1)
      return 'Only one adult is needed for that task.';
  const p = preview({ ...s, assignments });
  return p.errors.find((e) => !e.startsWith('Harvest needs two')) ?? null;
}
export function dispatch(state: GameState, action: Action): GameState {
  if (action.revision !== state.revision)
    throw new Error(
      'This choice has already changed. Please use the current controls.',
    );
  if (state.phase === 'ending')
    throw new Error(
      'This year is complete. Begin a new household to play again.',
    );
  const s = structuredClone(state);
  switch (action.type) {
    case 'choose': {
      const event = currentEvent(s);
      if (
        action.event !== event.id ||
        s.history.some((h) => h.event === event.id)
      )
        throw new Error('This event is no longer available.');
      const choice = event.choices.find((c) => c.id === action.choice);
      if (!choice) throw new Error('That choice is not available.');
      const problem = choiceProblem(s, choice);
      if (problem) throw new Error(problem);
      const e = choice.effect;
      s.food += e.food ?? 0;
      s.money += e.money ?? 0;
      s.house = Math.max(0, Math.min(100, s.house + (e.house ?? 0)));
      s.trust = Math.max(-5, Math.min(5, s.trust + (e.trust ?? 0)));
      if (e.ox) s.ox = e.ox;
      if (e.fairShare !== undefined) s.fairShare = e.fairShare;
      if (e.reserve) {
        s.reservedWorker = 'petru';
        s.assignments.petru = 'help';
      }
      if (choice.memory)
        s.memories.push({
          id: `${event.id}:${choice.id}`,
          season: s.season,
          ...choice.memory,
        });
      s.history.push({
        event: event.id,
        choice: choice.id,
        title: choice.label,
        detail: choice.memory?.detail ?? choice.detail,
        season: s.season,
      });
      if (s.phase === 'opening') s.phase = 'work';
      else {
        const consumption =
          B.consumption +
          (s.season === 3 && s.house < B.coldThreshold ? B.coldFood : 0);
        const deficit = Math.max(0, consumption - s.food);
        s.food = Math.max(0, s.food - consumption);
        s.house = Math.max(0, s.house - B.wear[s.season]);
        if (deficit)
          s.hardship.push({ season: s.season, kind: 'food', amount: deficit });
        if (s.house < B.survivalHouse)
          s.hardship.push({
            season: s.season,
            kind: 'shelter',
            amount: B.survivalHouse - s.house,
          });
        if (s.report)
          Object.assign(s.report, {
            foodAfter: s.food,
            moneyAfter: s.money,
            houseAfter: s.house,
            consumption,
            deficit,
          });
        s.phase = 'summary';
      }
      break;
    }
    case 'assign': {
      const problem = assignmentProblem(
        s,
        action.worker ?? '',
        action.task ?? '',
      );
      if (problem) throw new Error(problem);
      s.assignments[action.worker!] = action.task!;
      break;
    }
    case 'resolve': {
      if (s.phase !== 'work')
        throw new Error('Work has already been resolved.');
      const p = preview(s);
      if (p.errors.length) throw new Error(p.errors[0]);
      s.report = {
        foodBefore: s.food,
        foodAfter: 0,
        moneyBefore: s.money,
        moneyAfter: 0,
        houseBefore: s.house,
        houseAfter: 0,
        consumption: p.consumption,
        wear: p.wear,
        deficit: 0,
        tasks: WORKERS.map(
          (w) => `${PEOPLE[w].name}: ${TASKS[s.assignments[w]].name}`,
        ),
      };
      s.food = s.food - p.foodCost + p.foodGain;
      s.money = s.money - p.moneyCost + p.moneyGain;
      s.house = Math.min(100, s.house + p.houseGain);
      const tasks = Object.values(s.assignments);
      if (tasks.includes('plant')) {
        s.planted = true;
        s.cropBonus = s.ox === 'borrowed' || s.ox === 'paid' ? B.oxBonus : 0;
      }
      if (tasks.includes('tend')) s.tended = true;
      if (tasks.includes('harvest')) s.harvested = true;
      if (tasks.includes('help')) {
        s.trust = Math.min(5, s.trust + 1);
        s.memories.push({
          id: `help-${s.season}`,
          season: s.season,
          title: 'A hand across the fence',
          detail: s.reservedWorker
            ? 'Petru spent his assignment fulfilling the autumn promise. Vasile shared a meal in thanks.'
            : 'Your household made time for Vasile’s work. A shared meal and a warmer friendship came home with you.',
          tone: 'good',
        });
      }
      s.phase = 'consequence';
      break;
    }
    case 'continue': {
      if (s.phase !== 'summary')
        throw new Error('Finish this season before continuing.');
      if (s.season === 3) s.phase = 'ending';
      else {
        s.season = (s.season + 1) as Season;
        s.phase = 'opening';
        s.assignments = emptyAssignments();
        s.reservedWorker = null;
        s.report = null;
      }
      break;
    }
    default:
      throw new Error('Unknown action.');
  }
  s.revision++;
  return s;
}
export function ending(s: GameState): Ending {
  const crisis =
    s.house < B.survivalHouse || s.hardship.some((h) => h.kind === 'food');
  const secure =
    !crisis &&
    s.hardship.length === 0 &&
    s.food >= B.seed &&
    s.house >= B.coldThreshold;
  const category = crisis ? 'crisis' : secure ? 'secure' : 'cost';
  const decisions = [
    s.history.find((h) => h.event === 'autumn-promise') ??
      s.history.find((h) => h.event === 'spring-ox'),
    s.history.find((h) => h.event === 'summer-brother'),
    s.history.find((h) => h.event === 'autumn-dispute'),
  ].filter((h): h is NonNullable<typeof h> => !!h);
  return {
    category,
    title: crisis
      ? 'A home in need of help'
      : secure
        ? 'A home worth keeping'
        : 'Through the winter, together',
    text: crisis
      ? 'You reached the end of the year, but hunger or unsafe shelter has left the household needing outside support. The story is not a failure of care. It is a measure of what three people could carry.'
      : secure
        ? 'There is grain for the next sowing, a roof against the rain, and room to think beyond tomorrow. The year asked much of you. You have given this home another spring.'
        : 'You have made it through, though the year has left its mark. Before the next sowing, seed or shelter will need attention. What you have kept together is worth the work ahead.',
    decisions,
  };
}
export function seasonSubtitle(s: GameState): string {
  return [
    'The earth wakes. So does possibility.',
    'Long days. More work than hands.',
    'What we planted. What we promised.',
    'A little warmth against the world.',
  ][s.season];
}
export function fieldLabel(s: GameState): string {
  if (s.season === 3) return 'Resting beneath the snow';
  if (s.harvested) return 'Harvest safely gathered';
  if (s.planted)
    return s.season === 0
      ? 'Sown for the seasons ahead'
      : s.season === 1
        ? 'Growing through the summer'
        : 'Ready for two pairs of hands';
  return 'Waiting to be sown';
}
export { SEASONS };
