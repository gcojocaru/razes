import { describe, it, expect } from 'vitest';
import { newGame } from '../src/game/rules';
import { presentation } from '../src/scene/presentation';
import type { GameState } from '../src/game/types';

describe('painterly state projection', () => {
  it('shows each crop stage and always covers winter fields in snow', () => {
    const s = newGame();
    expect(presentation(s).field).toBe('bare');
    expect(presentation({ ...s, planted: true }).field).toBe('sown');
    expect(presentation({ ...s, season: 1, planted: true }).field).toBe(
      'growing',
    );
    expect(presentation({ ...s, season: 2, planted: true }).field).toBe('ripe');
    expect(
      presentation({ ...s, season: 2, planted: true, harvested: true }).field,
    ).toBe('harvested');
    expect(
      presentation({ ...s, season: 3, planted: true, harvested: true }).field,
    ).toBe('snow');
  });
  it('keeps roof condition and stored food visibly distinct', () => {
    expect(presentation({ ...newGame(), house: 64, food: 8 })).toMatchObject({
      house: 'damaged',
      stores: 0,
    });
    expect(presentation({ ...newGame(), house: 65, food: 9 })).toMatchObject({
      house: 'intact',
      stores: 1,
    });
    expect(presentation({ ...newGame(), food: 25 }).stores).toBe(2);
  });
  it('shows Dumitru during the inheritance encounter instead of Vasile', () => {
    const s: GameState = {
      ...newGame(),
      season: 2,
      phase: 'consequence',
      ox: 'paid',
    };
    expect(presentation(s).visitor).toBe('dumitru');
    expect(presentation(newGame()).visitor).toBe('vasile');
    expect(presentation({ ...newGame(), season: 1 }).visitor).toBeNull();
  });
  it('does not mutate game state when choosing visuals', () => {
    const s = newGame(),
      before = JSON.stringify(s);
    presentation(s);
    expect(JSON.stringify(s)).toBe(before);
  });
  it('has seasonal weather and a short spring shower after work', () => {
    expect(presentation(newGame()).weather).toBe('blossom');
    expect(presentation({ ...newGame(), phase: 'consequence' }).weather).toBe(
      'rain',
    );
    expect(presentation({ ...newGame(), season: 1 }).weather).toBe('motes');
    expect(presentation({ ...newGame(), season: 2 }).weather).toBe('leaves');
    expect(presentation({ ...newGame(), season: 3 }).weather).toBe('snow');
  });
});
