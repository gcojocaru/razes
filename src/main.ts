import '@fontsource/dm-sans/400.css';
import '@fontsource/dm-sans/500.css';
import '@fontsource/dm-sans/600.css';
import '@fontsource/cormorant-garamond/500.css';
import '@fontsource/cormorant-garamond/600.css';
import './styles.css';
import { newGame, dispatch } from './game/rules';
import { loadGame, saveGame } from './game/save';
import { SEASONS, type Action, type TaskId, type WorkerId } from './game/types';
import {
  shell,
  header,
  heading,
  resources,
  sceneOverlay,
  commitment,
  household,
  panel,
  journalPreview,
  modalContent,
  escape,
  type UIState,
} from './ui/render';
import { icon } from './ui/icons';
import { Ambience } from './ui/audio';
import { mountScene, type Hotspot } from './scene/Homestead';

const el = (id: string) => document.getElementById(id)!;
let storage: Storage;
try {
  storage = window.localStorage;
} catch {
  storage = {
    getItem() {
      throw Error('unavailable');
    },
    setItem() {
      throw Error('unavailable');
    },
  } as unknown as Storage;
}
const loaded = loadGame(storage);
let state = loaded.state ?? newGame();
const media = window.matchMedia('(prefers-reduced-motion: reduce)');
const ui: UIState = {
  modal: null,
  task: null,
  muted: true,
  reducedMotion: media.matches,
  error: null,
  storageWarning: loaded.error,
  invalidSave: !!loaded.error && !loaded.error.includes('storage'),
};
const audio = new Ambience();
let lastFocus: string | null = null;
el('app').innerHTML = shell();
const scene = mountScene(el('scene'), (spot) => handleHotspot(spot));
function draw(focusPanel = false) {
  const active = document.activeElement as HTMLElement | null;
  const oldId = active?.id;
  const activeAction = active?.dataset.action;
  el('topbar').innerHTML = header(ui, SEASONS[state.season]).replace(
    'Saved on this device',
    ui.storageWarning
      ? 'Saving unavailable'
      : loaded.state || state.revision > 0
        ? 'Saved on this device'
        : 'A new household',
  );
  el('season-heading').innerHTML = heading(state);
  el('resources').innerHTML = resources(state);
  el('scene-overlay').innerHTML = sceneOverlay(state);
  el('commitment').innerHTML = commitment(state);
  el('household').innerHTML = household(state);
  el('panel').innerHTML = panel(state);
  el('journal-preview').innerHTML = journalPreview(state);
  el('messages').innerHTML = [
    ui.storageWarning
      ? `<div class="banner" role="alert">${icon('warning')}<span>${escape(ui.storageWarning)}</span>${ui.invalidSave ? '<button class="button secondary" data-action="new">Start a fresh household</button>' : ''}</div>`
      : '',
    ui.error
      ? `<div class="banner" role="alert">${icon('warning')}<span>${escape(ui.error)}</span></div>`
      : '',
  ].join('');
  document.body.dataset.season = String(state.season);
  document.body.classList.toggle('reduced-motion', ui.reducedMotion);
  scene.update(state, ui.reducedMotion);
  if (ui.invalidSave) {
    el('panel')
      .querySelectorAll('button')
      .forEach((b) => (b.disabled = true));
  }
  renderModal();
  if (!ui.modal) {
    if (focusPanel) el('panel-title')?.focus({ preventScroll: true });
    else if (oldId && document.getElementById(oldId))
      el(oldId).focus({ preventScroll: true });
    else if (activeAction)
      document
        .querySelector<HTMLElement>(`[data-action="${activeAction}"]`)
        ?.focus({ preventScroll: true });
  }
}
function renderModal() {
  const root = el('modal-root');
  if (!ui.modal) {
    root.innerHTML = '';
    return;
  }
  root.innerHTML = modalContent(state, ui);
  const dialog = root.querySelector('dialog')!;
  dialog.showModal();
  dialog.addEventListener('cancel', (e) => {
    e.preventDefault();
    closeModal();
  });
  dialog.addEventListener('click', (e) => {
    if (e.target === dialog) {
      const r = dialog.getBoundingClientRect();
      if (
        e.clientX < r.left ||
        e.clientX > r.right ||
        e.clientY < r.top ||
        e.clientY > r.bottom
      )
        closeModal();
    }
  });
}
function openModal(kind: UIState['modal']) {
  const active = document.activeElement as HTMLElement;
  lastFocus = active?.id
    ? `#${active.id}`
    : active?.dataset.action
      ? `[data-action="${active.dataset.action}"]`
      : null;
  ui.modal = kind;
  renderModal();
}
function closeModal() {
  ui.modal = null;
  renderModal();
  if (lastFocus)
    document
      .querySelector<HTMLElement>(lastFocus)
      ?.focus({ preventScroll: true });
}
function commit(action: Action) {
  try {
    const previousPhase = state.phase;
    state = dispatch(state, action);
    ui.error = null;
    ui.storageWarning = saveGame(storage, state)
      ? null
      : 'Browser storage is unavailable. Your current run continues, but changes will not survive a reload.';
    ui.modal = null;
    audio.cue();
    draw(state.phase !== previousPhase);
    el('announcer').textContent =
      action.type === 'assign'
        ? 'Work assignment updated.'
        : state.phase === 'work'
          ? 'Choice recorded. Assign work to your household.'
          : state.phase === 'consequence'
            ? 'Work completed. An evening conversation awaits.'
            : state.phase === 'summary'
              ? 'The season is complete. Review the household’s stores.'
              : 'Your household has moved forward.';
  } catch (e) {
    ui.error =
      e instanceof Error ? e.message : 'That action could not be completed.';
    draw();
  }
}
function handleHotspot(spot: Hotspot) {
  if (ui.invalidSave) return;
  if (spot === 'visitor') {
    el('panel-title').focus({ preventScroll: true });
    el('panel').scrollIntoView({
      behavior: ui.reducedMotion ? 'instant' : 'smooth',
      block: 'nearest',
    });
    return;
  }
  if (state.phase !== 'work') {
    el('panel-title').focus({ preventScroll: true });
    el('announcer').textContent =
      'Finish the current conversation before assigning work.';
    return;
  }
  ui.task =
    spot === 'field'
      ? state.season === 0
        ? 'plant'
        : state.season === 1
          ? 'tend'
          : state.season === 2
            ? 'harvest'
            : null
      : spot === 'house'
        ? 'repair'
        : 'supplies';
  if (ui.task) {
    // The field remains a useful information hotspot when there is no crop to tend.
    if (spot === 'field' && state.season > 0 && !state.planted) {
      ui.error =
        'The field was not planted in spring. Choose another household task.';
      draw();
      return;
    }
    openModal('task');
  }
}
document.addEventListener('click', (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>(
    'button[data-action]',
  );
  if (!b || b.disabled) return;
  const a = b.dataset.action,
    revision = Number(b.dataset.revision);
  if (a === 'choose')
    commit({
      type: 'choose',
      event: b.dataset.event,
      choice: b.dataset.choice,
      revision,
    });
  else if (a === 'assign')
    commit({
      type: 'assign',
      worker: b.dataset.worker as WorkerId,
      task: b.dataset.task as TaskId,
      revision,
    });
  else if (a === 'continue' || a === 'resolve') commit({ type: a, revision });
  else if (a === 'journal' || a === 'help' || a === 'restart') openModal(a);
  else if (a === 'review') openModal('review');
  else if (a === 'task') {
    ui.task = b.dataset.task as TaskId;
    openModal('task');
  } else if (a === 'close') closeModal();
  else if (a === 'field' || a === 'house') handleHotspot(a);
  else if (a === 'homestead') {
    el('main-content').scrollIntoView({
      behavior: ui.reducedMotion ? 'instant' : 'smooth',
    });
    el('panel-title').focus({ preventScroll: true });
  } else if (a === 'mute') {
    ui.muted = !ui.muted;
    void audio.setEnabled(!ui.muted);
    draw();
  } else if (a === 'motion') {
    ui.reducedMotion = !ui.reducedMotion;
    draw();
  } else if (a === 'new') {
    state = newGame();
    ui.invalidSave = false;
    ui.modal = null;
    ui.error = null;
    ui.storageWarning = saveGame(storage, state)
      ? null
      : 'Browser storage is unavailable. This run cannot be saved.';
    draw(true);
  }
});
document.addEventListener('change', (e) => {
  const select = e.target as HTMLSelectElement;
  if (select.matches('select[data-worker]'))
    commit({
      type: 'assign',
      worker: select.dataset.worker as WorkerId,
      task: select.value as TaskId,
      revision: Number(select.dataset.revision),
    });
});
media.addEventListener('change', (e) => {
  ui.reducedMotion = e.matches;
  draw();
});
document.addEventListener('visibilitychange', () => {
  void audio.setEnabled(!ui.muted && !document.hidden);
});
draw();
