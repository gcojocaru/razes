import type { PersonId } from '../game/types';
/** Portrait windows share the same painted character sheet as the scene figures. */
export function portrait(person: PersonId) {
  const column = ['ion', 'ana', 'petru', 'vasile', 'dumitru'].indexOf(person);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${column * 307 + 25} 595 270 340" preserveAspectRatio="xMidYMid slice" style="overflow:hidden" aria-hidden="true"><image href="/art/people.png" width="1536" height="1024" /></svg>`;
}
