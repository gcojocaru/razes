import { currentEvent } from '../game/rules';
import type { GameState } from '../game/types';
export function presentation(s: GameState) {
  const person =
    s.phase === 'opening' || s.phase === 'consequence'
      ? currentEvent(s).person
      : null;
  return {
    field:
      s.season === 3
        ? 'snow'
        : s.harvested
          ? 'harvested'
          : !s.planted
            ? 'bare'
            : s.season === 0
              ? 'sown'
              : s.season === 1
                ? 'growing'
                : 'ripe',
    house: s.house >= 65 ? 'intact' : 'damaged',
    stores: s.food < 9 ? 0 : s.food < 25 ? 1 : 2,
    visitor: person === 'vasile' || person === 'dumitru' ? person : null,
    weather:
      s.season === 3
        ? 'snow'
        : s.season === 2
          ? 'leaves'
          : s.season === 1
            ? 'motes'
            : s.phase === 'consequence'
              ? 'rain'
              : 'blossom',
  } as const;
}
