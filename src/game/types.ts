export const SEASONS = ['Spring', 'Summer', 'Autumn', 'Winter'] as const;
export type Season = 0 | 1 | 2 | 3;
export type Phase = 'opening' | 'work' | 'consequence' | 'summary' | 'ending';
export const WORKERS = ['ion', 'ana', 'petru'] as const;
export type WorkerId = (typeof WORKERS)[number];
export type PersonId = WorkerId | 'vasile' | 'dumitru';
export type TaskId =
  | 'rest'
  | 'plant'
  | 'tend'
  | 'harvest'
  | 'paid'
  | 'repair'
  | 'help'
  | 'supplies';
export type Ox =
  'none' | 'borrowed' | 'paid' | 'declined' | 'honoured' | 'broken';
export type Tone = 'good' | 'neutral' | 'bad';
export interface Memory {
  id: string;
  title: string;
  detail: string;
  season: Season;
  tone: Tone;
}
export interface HistoryEntry {
  event: string;
  choice: string;
  title: string;
  detail: string;
  season: Season;
}
export interface Hardship {
  season: Season;
  kind: 'food' | 'shelter';
  amount: number;
}
export interface SeasonReport {
  foodBefore: number;
  foodAfter: number;
  moneyBefore: number;
  moneyAfter: number;
  houseBefore: number;
  houseAfter: number;
  consumption: number;
  wear: number;
  tasks: string[];
  deficit: number;
}
export interface GameState {
  version: 1;
  revision: number;
  season: Season;
  phase: Phase;
  food: number;
  money: number;
  house: number;
  assignments: Record<WorkerId, TaskId>;
  reservedWorker: WorkerId | null;
  planted: boolean;
  tended: boolean;
  harvested: boolean;
  cropBonus: number;
  ox: Ox;
  trust: number;
  fairShare: boolean;
  memories: Memory[];
  history: HistoryEntry[];
  hardship: Hardship[];
  report: SeasonReport | null;
}
export interface Action {
  type: 'choose' | 'assign' | 'resolve' | 'continue';
  revision: number;
  event?: string;
  choice?: string;
  worker?: WorkerId;
  task?: TaskId;
}
export interface Effect {
  food?: number;
  money?: number;
  house?: number;
  trust?: number;
  ox?: Ox;
  fairShare?: boolean;
  reserve?: boolean;
}
export interface Choice {
  id: string;
  label: string;
  detail: string;
  effect: Effect;
  memory?: { title: string; detail: string; tone: Tone };
}
export interface GameEvent {
  id: string;
  eyebrow: string;
  title: string;
  person: PersonId;
  text: string;
  choices: Choice[];
}
export interface Task {
  id: TaskId;
  name: string;
  description: string;
  icon: string;
  workers: number;
  moneyCost: number;
  foodCost: number;
  foodGain: number;
  moneyGain: number;
  houseGain: number;
}
export interface Projection {
  foodCost: number;
  moneyCost: number;
  foodGain: number;
  moneyGain: number;
  houseGain: number;
  consumption: number;
  wear: number;
  foodAfter: number;
  moneyAfter: number;
  houseAfter: number;
  errors: string[];
  warnings: string[];
}
export interface Ending {
  category: 'secure' | 'cost' | 'crisis';
  title: string;
  text: string;
  decisions: HistoryEntry[];
}
