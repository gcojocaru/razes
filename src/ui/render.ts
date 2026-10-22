import { PEOPLE, BALANCE as B, TASKS } from '../game/balance';
import {
  currentEvent,
  choiceProblem,
  taskOptions,
  preview,
  ending,
  fieldLabel,
  seasonSubtitle,
  assignmentProblem,
} from '../game/rules';
import { SEASONS, WORKERS, type GameState, type TaskId } from '../game/types';
import { portrait } from '../scene/art';
import { icon } from './icons';
export const escape = (s: string) =>
  s.replace(
    /[&<>"']/g,
    (c) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        c
      ]!,
  );
export interface UIState {
  modal: 'journal' | 'help' | 'review' | 'restart' | 'task' | null;
  task: TaskId | null;
  muted: boolean;
  reducedMotion: boolean;
  error: string | null;
  storageWarning: string | null;
  invalidSave: boolean;
}
const seasonalIcons = ['leaf', 'sun', 'wheat', 'snow'];
const phaseLabels = {
  opening: 'A conversation',
  work: 'Plan your work',
  consequence: 'As evening falls',
  summary: 'Season remembered',
  ending: 'Your first year',
};
const button = (label: string, action: string, cls = 'button', extra = '') =>
  `<button class="${cls}" data-action="${action}" ${extra}>${label}</button>`;
export function shell() {
  return `<a href="#main-content" class="skip-link">Skip to household</a><header id="topbar"></header><main id="main-content"><section id="season-heading" class="season-heading"></section><section id="resources" class="resources" aria-label="Household resources"></section><div id="messages" aria-live="polite"></div><div class="homestead-layout"><div class="homestead-column"><section class="scene-frame" aria-label="Your homestead"><div id="scene" role="img" aria-label="An illustrated seasonal homestead, with a house, field, storehouse and household members."></div><div id="scene-overlay"></div></section><div id="commitment"></div><section id="household" class="household" aria-labelledby="household-title"></section></div><aside id="panel" class="side-panel" aria-label="Seasonal decisions"></aside></div><section id="journal-preview" class="journal-preview"></section><footer><span>${icon('leaf')} A small life. A lasting story.</span><span>Northern Moldavia · 1495 <span class="dot">·</span> A fictional household</span></footer></main><div id="modal-root"></div><div class="sr-only" id="announcer" aria-live="polite" aria-atomic="true"></div>`;
}
export function header(ui: UIState, season: string) {
  return `<div class="brand"><span class="brand-mark">${icon('wheat')}</span><div><span class="wordmark">Răzeș</span><span class="brand-subtitle">A HOME WORTH KEEPING</span></div></div><nav aria-label="Main navigation"><button class="nav-link active" data-action="homestead">${icon('house')}<span>Homestead</span></button><button class="nav-link" data-action="journal" aria-label="Open promise journal">${icon('book')}<span>Journal</span></button><button class="nav-link" data-action="help"><span>How to play</span></button></nav><div class="header-controls"><span class="header-season">${season} · Year one</span><span class="local-save">${icon('check')} Saved on this device</span><button class="icon-button" data-action="mute" aria-label="${ui.muted ? 'Enable sound' : 'Mute sound'}" title="${ui.muted ? 'Enable ambient sound' : 'Mute sound'}">${icon(ui.muted ? 'mute' : 'sound')}</button><button class="icon-button" data-action="motion" aria-label="Reduce motion" aria-pressed="${ui.reducedMotion}" title="Reduce motion">${icon('motion')}</button></div>`;
}
export function heading(s: GameState) {
  const titles = [
    'A new beginning.',
    'Under the summer sun.',
    'The season of keeping.',
    'A light in the window.',
  ];
  return `<div><div class="eyebrow">${icon(seasonalIcons[s.season])} ${SEASONS[s.season]} <span class="small-dot">·</span> YEAR ONE</div><h1>${s.phase === 'ending' ? 'What a year can hold.' : titles[s.season]}</h1><p>${seasonSubtitle(s)}</p></div><ol class="season-track" aria-label="Year progress">${SEASONS.map((season, i) => `<li class="${i === s.season ? 'current' : i < s.season ? 'past' : ''}" ${i === s.season ? 'aria-current="step"' : ''}><span class="season-symbol">${icon(i < s.season ? 'check' : seasonalIcons[i])}</span><span>${season}</span></li>`).join('')}</ol>`;
}
export function resources(s: GameState) {
  const hands = Object.values(s.assignments).filter((t) => t === 'rest').length;
  return [
    [
      'wheat',
      'Food',
      String(s.food),
      'in the storehouse',
      `${B.seed} needed for spring seed`,
      s.food < 9 ? 'warning' : '',
    ],
    [
      'coin',
      'Money',
      String(s.money),
      'coins to your name',
      'A little room to choose',
      '',
    ],
    [
      'house',
      'Shelter',
      `${s.house}<small>/100</small>`,
      s.house >= 65
        ? 'Sound & cared for'
        : s.house >= 40
          ? 'Weathered, but holding'
          : 'In need of repair',
      s.house >= 40 ? 'A roof over your heads' : 'Cold shelter uses extra food',
      s.house < 40 ? 'warning' : '',
    ],
    [
      'people',
      'Hands',
      `${hands}<small>/3</small>`,
      'adults available',
      s.reservedWorker
        ? 'One hand keeps a promise'
        : 'Every pair of hands matters',
      '',
    ],
  ]
    .map(
      ([ico, label, value, sub, caption, cls]) =>
        `<div class="resource ${cls}"><span class="resource-icon">${icon(ico)}</span><div class="resource-main"><span class="resource-label">${label}</span><div class="resource-value">${value}<span>${sub}</span></div><span class="resource-caption">${caption}</span></div></div>`,
    )
    .join('');
}
export function sceneOverlay(s: GameState) {
  return `<div class="scene-heading"><span class="scene-location">${icon('house')} Your family’s homestead</span><span class="scene-year">YOUR FIRST YEAR</span></div><button class="map-label field-label" data-action="field">${icon('wheat')}<span>The field<small>${fieldLabel(s)}</small></span>${icon('chevron')}</button><button class="map-label house-label" data-action="house">${icon('house')}<span>Home<small>${s.house >= 65 ? 'A well-kept roof' : 'A little care goes a long way'}</small></span></button><span class="scene-hint">${icon('sun')} ${s.season === 3 ? 'Quiet beneath the snow' : 'There is life in the little things'}</span><button class="scene-help" data-action="help" aria-label="Scene interaction help">?</button>`;
}
export function commitment(s: GameState) {
  if (s.ox === 'borrowed')
    return `<div class="commitment promise"><span>${icon('flag')}</span><div><strong>A promise to keep</strong><p>One adult owed to the neighbour in autumn.</p></div>${button('View journal ' + icon('arrow'), 'journal', 'text-button')}</div>`;
  if (s.ox === 'honoured')
    return `<div class="commitment kept"><span>${icon('heart')}</span><div><strong>A word kept, a friendship warmed</strong><p>Petru helped Vasile. Your neighbour will remember.</p></div>${button('View journal ' + icon('arrow'), 'journal', 'text-button')}</div>`;
  if (s.ox === 'broken')
    return `<div class="commitment broken"><span>${icon('flag')}</span><div><strong>A promise left behind</strong><p>Vasile will remember the hand that never came.</p></div>${button('View journal ' + icon('arrow'), 'journal', 'text-button')}</div>`;
  return `<div class="commitment"><span>${icon('leaf')}</span><div><strong>These are the days that make a home.</strong><p>${s.ox === 'paid' ? 'The ox is paid for. Your autumn labour is your own.' : s.ox === 'declined' ? 'Your own hands will work the earth.' : 'Three people, a patch of earth, and a year ahead.'}</p></div></div>`;
}
export function household(s: GameState) {
  return `<div class="section-heading"><div><span class="eyebrow">BETTER TOGETHER</span><h2 id="household-title">Your household</h2></div><span class="section-note">One task per adult, each season</span></div><div class="worker-grid">${WORKERS.map(
    (w) => {
      const person = PEOPLE[w],
        reserved = s.reservedWorker === w,
        active = s.phase === 'work' && !reserved;
      const options = taskOptions(s);
      if (!options.some((t) => t.id === s.assignments[w]))
        options.push(TASKS[s.assignments[w]]);
      return `<article class="worker-card ${reserved ? 'reserved' : ''}"><div class="worker-identity"><div class="portrait small">${portrait(w)}</div><div><h3>${person.name}</h3><p>${person.role}</p></div>${reserved ? icon('lock', 'reserved-icon') : ''}</div><p class="worker-quote">${person.line}</p><label class="sr-only" for="task-${w}">${person.name}'s task</label><select id="task-${w}" aria-label="${person.name}'s task" data-worker="${w}" data-revision="${s.revision}" ${active ? '' : 'disabled'}>${options.map((t) => `<option value="${t.id}" ${s.assignments[w] === t.id ? 'selected' : ''} ${active && assignmentProblem(s, w, t.id) ? 'disabled' : ''}>${t.name}${t.moneyCost ? ` · ${t.moneyCost} coins` : t.foodCost ? ` · ${t.foodCost} seed` : ''}</option>`).join('')}</select><span class="worker-status">${reserved ? 'Keeping the autumn promise' : s.phase === 'opening' ? 'Hear the conversation first' : s.phase === 'work' ? (s.assignments[w] === 'rest' ? 'Ready for your decision' : 'Assignment can still be changed') : s.assignments[w] === 'rest' ? 'A quiet season at home' : 'This season’s work is done'}</span></article>`;
    },
  ).join('')}</div>`;
}
function eventPanel(s: GameState) {
  const e = currentEvent(s),
    p = PEOPLE[e.person];
  return `<div class="panel-top"><span>${icon(s.phase === 'opening' ? 'leaf' : 'sun')} ${phaseLabels[s.phase]}</span><span>0${s.season + 1} / 04</span></div><div class="event-content"><div class="speaker"><div class="portrait">${portrait(e.person)}</div><div><strong>${p.name}</strong><span>${p.role}</span></div><span class="event-ornament">❧</span></div><div class="eyebrow">${e.eyebrow}</div><h2 tabindex="-1" id="panel-title">${e.title}</h2><p class="event-story">${e.text}</p><div class="choices">${e.choices
    .map((c, i) => {
      const problem = choiceProblem(s, c);
      return `<button class="choice ${i === 0 ? 'recommended' : ''}" data-action="choose" data-event="${e.id}" data-choice="${c.id}" data-revision="${s.revision}" ${problem ? 'disabled' : ''}><span class="choice-number">${String(i + 1).padStart(2, '0')}</span><span><strong>${c.label}</strong><small>${c.detail}</small>${problem ? `<small class="unaffordable">${problem}</small>` : ''}</span>${icon('arrow')}</button>`;
    })
    .join(
      '',
    )}</div><p class="decision-note">${icon('book')} A choice becomes part of your story.</p></div>`;
}
const costs = (t: ReturnType<typeof taskOptions>[number]) =>
  [
    t.foodCost ? `−${t.foodCost} seed` : '',
    t.moneyCost ? `−${t.moneyCost} money` : '',
    t.foodGain ? `+${t.foodGain} food` : '',
    t.moneyGain ? `+${t.moneyGain} money` : '',
    t.houseGain ? `+${t.houseGain} shelter` : '',
    t.id === 'tend' ? `+${B.tendedBonus} autumn food` : '',
  ]
    .filter(Boolean)
    .join(' · ');
function workPanel(s: GameState) {
  const p = preview(s);
  return `<div class="panel-top"><span>${icon('people')} Plan your work</span><span>0${s.season + 1} / 04</span></div><div class="work-content"><div class="eyebrow">THREE HANDS, MANY POSSIBILITIES</div><h2 tabindex="-1" id="panel-title">The work of ${SEASONS[s.season].toLowerCase()}</h2><p class="panel-intro">Choose a task below, or assign work beside each household member.</p><div class="task-list">${taskOptions(
    s,
  )
    .filter((t) => t.id !== 'rest')
    .map(
      (t) =>
        `<button class="task-option" data-action="task" data-task="${t.id}"><span class="task-icon">${icon(t.icon)}</span><span><strong>${t.name}</strong><small>${costs(t)}${t.workers === 2 ? ' · 2 adults' : ''}</small></span>${icon('chevron')}</button>`,
    )
    .join(
      '',
    )}</div><div class="forecast-mini"><span>After work & consumption<small>Before the evening conversation</small></span><strong class="${p.foodAfter < 0 ? 'danger' : ''}">${icon('wheat')} ${Math.max(0, p.foodAfter)} <small>food</small></strong></div>${p.errors.map((e) => `<p class="inline-warning">${icon('warning')}${e}</p>`).join('')}${button('Review the season ' + icon('arrow'), 'review', 'button primary wide', p.errors.length ? 'disabled' : '')}<p class="decision-note">Assignments stay flexible until you confirm.</p></div>`;
}
function reportPanel(s: GameState) {
  const r = s.report!;
  return `<div class="panel-top"><span>${icon('check')} Season complete</span><span>0${s.season + 1} / 04</span></div><div class="event-content"><div class="summary-emblem">${icon(seasonalIcons[s.season])}</div><div class="eyebrow">THE WORK, AND WHAT REMAINS</div><h2 tabindex="-1" id="panel-title">${SEASONS[s.season]}, remembered.</h2><p class="panel-intro">The days have done their work. Here is what your household carries forward.</p><div class="report-stats">${[
    ['wheat', 'Food', r.foodBefore, r.foodAfter],
    ['coin', 'Money', r.moneyBefore, r.moneyAfter],
    ['house', 'Shelter', r.houseBefore, r.houseAfter],
  ]
    .map(
      ([i, label, before, after]) =>
        `<div>${icon(String(i))}<span>${label}</span><span>${before} ${icon('arrow')} <strong>${after}</strong></span></div>`,
    )
    .join(
      '',
    )}</div><p class="report-note">The household consumed ${r.consumption} food. Seasonal wear took ${r.wear} shelter.</p>${r.deficit ? `<p class="inline-warning">${icon('warning')}A shortfall of ${r.deficit} food is remembered as hardship. The year continues.</p>` : ''}<div class="journal-excerpt">${icon('book')}<p>${escape(s.memories.at(-1)?.detail ?? 'Another season has become part of your story.')}</p></div>${button(`Continue to ${s.season === 3 ? 'your ending' : SEASONS[s.season + 1].toLowerCase()} ${icon('arrow')}`, 'continue', 'button primary wide', `data-revision="${s.revision}"`)}</div>`;
}
function endingPanel(s: GameState) {
  const e = ending(s);
  return `<div class="panel-top"><span>${icon('leaf')} The year you made</span><span>YEAR ONE</span></div><div class="event-content"><div class="summary-emblem">${icon(e.category === 'secure' ? 'house' : e.category === 'cost' ? 'heart' : 'leaf')}</div><div class="eyebrow">${e.category === 'secure' ? 'SECURE FOR SPRING' : e.category === 'cost' ? 'SURVIVED AT A COST' : 'HOUSEHOLD IN CRISIS'}</div><h2 tabindex="-1" id="panel-title">${e.title}</h2><p class="event-story">${e.text}</p><h3 class="ending-subtitle">Three choices that stayed</h3><div class="ending-decisions">${e.decisions.map((d) => `<div><span>${SEASONS[d.season]}</span><strong>${escape(d.title)}</strong><p>${escape(d.detail)}</p></div>`).join('')}</div>${button('Begin another year ' + icon('arrow'), 'restart', 'button primary wide')}<p class="decision-note">A fresh household. Perhaps a different story.</p></div>`;
}
export function panel(s: GameState) {
  return s.phase === 'opening' || s.phase === 'consequence'
    ? eventPanel(s)
    : s.phase === 'work'
      ? workPanel(s)
      : s.phase === 'summary'
        ? reportPanel(s)
        : endingPanel(s);
}
export function journalPreview(s: GameState) {
  return `<span class="journal-mark">${icon('book')}</span><div><span class="eyebrow">THE PROMISE JOURNAL</span><p>${s.memories.length ? escape(s.memories.at(-1)!.title) : 'Some things are worth remembering.'}<span>${s.memories.length ? `${s.memories.length} memories of your first year` : 'Your choices and commitments will find a home here.'}</span></p></div>${button('Read your story ' + icon('arrow'), 'journal', 'text-button')}`;
}
export function modalContent(s: GameState, ui: UIState) {
  if (!ui.modal) return '';
  let body = '',
    title = '',
    eyebrow = '';
  if (ui.modal === 'journal') {
    title = 'The things we remember.';
    eyebrow = 'YOUR PROMISE JOURNAL';
    body = `<p class="modal-intro">A home is made of more than what is in its stores.</p>${s.memories.length ? `<ol class="memory-list">${s.memories.map((m) => `<li class="${m.tone}"><span class="memory-symbol">${icon(m.tone === 'bad' ? 'flag' : m.tone === 'good' ? 'heart' : 'leaf')}</span><div><span class="eyebrow">${SEASONS[m.season]} · YEAR ONE</span><h3>${escape(m.title)}</h3><p>${escape(m.detail)}</p></div></li>`).join('')}</ol>` : '<div class="empty-journal">' + icon('book') + '<p>The page is still open. Your first choice will leave a mark.</p></div>'}${s.hardship.length ? `<h3>Hard days, remembered</h3><ul>${s.hardship.map((h) => `<li>${SEASONS[h.season]}: ${h.kind === 'food' ? `${h.amount} food shortfall` : 'shelter fell below the safe threshold'}.</li>`).join('')}</ul>` : ''}`;
  }
  if (ui.modal === 'help') {
    title = 'Make a home of the year.';
    eyebrow = 'A LITTLE GUIDANCE';
    body = `<p class="modal-intro">You are looking after Ion, Ana, and Petru in a fictional village in northern Moldavia, in 1495. The household works inherited family land and must decide how to keep a home together. Their work is equal. Their hopes are their own.</p><ol class="help-steps"><li><strong>Listen, then choose.</strong> Each season begins with a conversation. Costs and promises are shown before you commit.</li><li><strong>Give each adult one task.</strong> Sow in spring, tend in summer, harvest with two adults in autumn. Repairs, wages, provisions, and neighbourly help compete for those same hands.</li><li><strong>Review what the season will leave.</strong> Food pays for spring seed and seasonal meals. Work costs must be affordable from the stocks you have now; wages arrive when the work is done.</li><li><strong>Let the season unfold.</strong> Work happens first, then an evening conversation, then consumption and wear. Shortages become hardship; everyone reaches the winter ending.</li><li><strong>Remember your word.</strong> Borrowing Vasile’s ox promises one adult in autumn. Honour it to keep his winter assistance. Pay or decline to keep your labour free.</li></ol><div class="help-note"><strong>For a secure spring</strong><p>Finish without hardship, with at least ${B.seed} food for seed and ${B.coldThreshold} shelter. Any food shortfall or final shelter below ${B.survivalHouse} means the household needs outside support.</p></div><div class="help-note"><strong>A household in its time</strong><p>Răzeș is a historical term for a free landholding peasant in Moldavia, often sharing inherited land with kin. Here, the ox promise is a personal bargain with a neighbour. Money, food, and one task per adult are game abstractions; they do not reproduce historical prices or a farming calendar. The story and painted homestead are interpretations, not a reconstruction of a documented family.</p></div><p class="small-copy">The game saves on this device after each choice and assignment. You can pause at any time. Use Tab and Enter, or the labelled task selectors, for every essential action. Sound and movement controls are in the header.</p>`;
  }
  if (ui.modal === 'review') {
    const p = preview(s);
    title = 'Before the season turns.';
    eyebrow = 'TAKE A MOMENT';
    body = `<p class="modal-intro">These are the hands you have chosen to put to work. Once confirmed, the work becomes part of the year.</p><div class="review-workers">${WORKERS.map((w) => `<div>${portrait(w)}<span><strong>${PEOPLE[w].name}</strong><small>${TASKS[s.assignments[w]].name}</small></span>${s.reservedWorker === w ? icon('lock') : icon('check')}</div>`).join('')}</div><dl class="review-math"><div><dt>Seed reserved for sowing</dt><dd>−${p.foodCost} food</dd></div><div><dt>Work and supplies</dt><dd>−${p.moneyCost} money</dd></div><div><dt>Work brings home</dt><dd>+${p.foodGain} food · +${p.moneyGain} money</dd></div><div><dt>Repairs</dt><dd>+${Math.min(p.houseGain, 100 - s.house)} shelter</dd></div><div><dt>Seasonal consumption</dt><dd>−${p.consumption} food</dd></div><div><dt>Seasonal wear</dt><dd>−${p.wear} shelter</dd></div></dl><div class="review-totals"><span>${icon('wheat')}<strong>${Math.max(0, p.foodAfter)}</strong> food</span><span>${icon('coin')}<strong>${p.moneyAfter}</strong> money</span><span>${icon('house')}<strong>${p.houseAfter}</strong> shelter</span></div><p class="small-copy">Projection before the evening conversation. Its choices may change the final stores.</p>${p.warnings.map((w) => `<p class="inline-warning">${icon('warning')}${w}</p>`).join('')}<div class="modal-actions">${button('Keep planning', 'close', 'button secondary')}${button('Confirm and resolve ' + icon('arrow'), 'resolve', 'button primary', `data-revision="${s.revision}"`)}</div>`;
  }
  if (ui.modal === 'restart') {
    title = 'Begin a different story?';
    eyebrow = 'A FRESH SPRING';
    body = `<p class="modal-intro">This will replace the year saved on this device. The same three people and the same small homestead await your next choices.</p><div class="modal-actions">${button('Keep this household', 'close', 'button secondary')}${button('Start a fresh household', 'new', 'button primary')}</div>`;
  }
  if (ui.modal === 'task' && ui.task) {
    const t = taskOptions(s).find((t) => t.id === ui.task)!;
    title = t.name;
    eyebrow = 'WHO WILL LEND A HAND?';
    body = `<p class="modal-intro">${t.description}</p><p class="task-detail-cost">${costs(t)}${t.workers === 2 ? ' · two adults required' : ''}</p><div class="task-workers">${WORKERS.map(
      (w) => {
        const problem = assignmentProblem(s, w, t.id);
        return `<button class="task-worker" data-action="assign" data-worker="${w}" data-task="${t.id}" data-revision="${s.revision}" ${problem ? 'disabled' : ''}><span class="portrait small">${portrait(w)}</span><span><strong>${PEOPLE[w].name}</strong><small>${problem ?? `Currently: ${TASKS[s.assignments[w]].name}`}</small></span>${icon('arrow')}</button>`;
      },
    ).join(
      '',
    )}</div>${t.workers === 2 ? '<p class="small-copy">Choose this task again for a second adult before resolving the season.</p>' : ''}`;
  }
  return `<dialog aria-labelledby="modal-title"><div class="modal-inner">${button(icon('close'), 'close', 'icon-button modal-close', 'aria-label="Close dialog"')}<div class="eyebrow">${eyebrow}</div><h2 id="modal-title">${title}</h2>${body}</div></dialog>`;
}
