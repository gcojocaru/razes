import Phaser from 'phaser';
import { presentation } from './presentation';
import { type GameState, WORKERS } from '../game/types';
export type Hotspot = 'field' | 'house' | 'visitor' | 'stores';
export interface SceneController {
  update(state: GameState, reducedMotion: boolean): void;
  destroy(): void;
}
export function mountScene(
  element: HTMLElement,
  onHotspot: (spot: Hotspot) => void,
): SceneController {
  let state: GameState | null = null,
    reduced = false;
  class Homestead extends Phaser.Scene {
    private loaded = false;
    private signature = '';
    private land!: Phaser.GameObjects.Image;
    private crop!: Phaser.GameObjects.Image;
    private house!: Phaser.GameObjects.Image;
    private props: Phaser.GameObjects.Image[] = [];
    private stores: Phaser.GameObjects.Image[] = [];
    private people: Phaser.GameObjects.Image[] = [];
    private tools: Phaser.GameObjects.Graphics[] = [];
    private particles: Phaser.GameObjects.Ellipse[] = [];
    private smoke: Phaser.GameObjects.Ellipse[] = [];
    constructor() {
      super('homestead');
    }
    preload() {
      [
        'spring',
        'summer',
        'autumn',
        'winter',
        'props',
        'props-winter',
        'people',
        'fields',
      ].forEach((key) => this.load.image(key, `/art/${key}.png`));
      this.load.on('loaderror', () => {
        element.dataset.error =
          'Artwork could not load. Reload to retry; the task buttons remain available.';
      });
    }
    create() {
      for (const key of ['props', 'props-winter']) {
        const texture = this.textures.get(key);
        [
          ['intact', 0, 0, 557, 503],
          ['damaged', 557, 0, 550, 503],
          ['barn', 1107, 0, 429, 503],
          ['well', 0, 503, 426, 521],
          ['supplies', 426, 503, 634, 521],
          ['fence', 1066, 503, 470, 521],
        ].forEach(([name, x, y, w, h]) =>
          texture.add(
            name as string,
            0,
            x as number,
            y as number,
            w as number,
            h as number,
          ),
        );
      }
      ['bare', 'sown', 'growing', 'ripe', 'harvested', 'snow'].forEach(
        (name, i) =>
          this.textures
            .get('fields')
            .add(name, 0, (i % 3) * 525, Math.floor(i / 3) * 499, 525, 499),
      );
      [...WORKERS, 'vasile', 'dumitru'].forEach((name, i) =>
        this.textures.get('people').add(name, 0, i * 307, 0, 307, 590),
      );
      const prop = (
        x: number,
        y: number,
        frame: string,
        w: number,
        h: number,
      ) =>
        this.add
          .image(x, y, 'props', frame)
          .setDisplaySize(w, h)
          .setOrigin(0.5, 1);
      this.land = this.add
        .image(0, 0, 'spring')
        .setOrigin(0)
        .setDisplaySize(1200, 760);
      this.crop = this.add
        .image(285, 640, 'fields', 'bare')
        .setDisplaySize(390, 295)
        .setOrigin(0.5, 1);
      this.props.push(prop(370, 452, 'barn', 215, 235));
      this.house = prop(700, 493, 'damaged', 355, 320);
      this.props.push(prop(956, 552, 'well', 125, 153));
      this.stores.push(
        prop(408, 524, 'supplies', 116, 96),
        prop(482, 545, 'supplies', 107, 88),
      );
      [...WORKERS, 'vasile'].forEach((p) =>
        this.people.push(
          this.add
            .image(600, 540, 'people', p)
            .setDisplaySize(48, 92)
            .setOrigin(0.5, 1),
        ),
      );
      this.props.push(prop(1040, 712, 'fence', 275, 235));
      for (let i = 0; i < 3; i++) this.tools.push(this.add.graphics());
      for (let i = 0; i < 48; i++)
        this.particles.push(this.add.ellipse(0, 0, 4, 3, 0xffffff, 0.5));
      for (let i = 0; i < 5; i++)
        this.smoke.push(
          this.add.ellipse(0, 0, 15 + i * 6, 9 + i * 4, 0xf0ede2, 0.25),
        );
      const zones: [number, number, number, number, Hotspot][] = [
        [285, 545, 350, 180, 'field'],
        [700, 365, 330, 250, 'house'],
        [827, 554, 80, 100, 'visitor'],
        [435, 498, 140, 100, 'stores'],
      ];
      zones.forEach(([x, y, w, h, spot]) =>
        this.add
          .zone(x, y, w, h)
          .setInteractive({ useHandCursor: true })
          .on('pointerdown', () => onHotspot(spot)),
      );
      this.loaded = true;
      this.paint();
      element.dataset.ready = 'true';
      this.game.canvas.setAttribute('aria-hidden', 'true');
    }
    paint() {
      if (!this.loaded || !state) return;
      const s = state,
        p = presentation(s),
        signature = JSON.stringify([
          s.season,
          s.phase,
          s.assignments,
          p,
          reduced,
        ]);
      if (signature === this.signature) return;
      this.signature = signature;
      this.land.setTexture(['spring', 'summer', 'autumn', 'winter'][s.season]);
      this.crop.setTexture('fields', p.field);
      const texture = s.season === 3 ? 'props-winter' : 'props';
      this.house.setTexture(texture, p.house);
      this.props.forEach((prop) => prop.setTexture(texture, prop.frame.name));
      this.stores.forEach((store, i) =>
        store.setTexture(texture, 'supplies').setVisible(i < p.stores),
      );
      const positions: Record<string, [number, number]> = {
        plant: [245, 569],
        tend: [245, 569],
        harvest: [245, 569],
        repair: [720, 510],
        paid: [903, 643],
        help: [824, 582],
        supplies: [430, 547],
        rest: [645, 552],
      };
      this.people.forEach((person, i) => {
        const task = i < 3 ? s.assignments[WORKERS[i]] : 'rest',
          pos = i < 3 ? positions[task] : [827, 554];
        person
          .setTexture('people', i < 3 ? WORKERS[i] : (p.visitor ?? 'vasile'))
          .setPosition(
            pos[0] + (i === 1 ? 35 : i === 2 ? -29 : 0),
            pos[1] + (i < 3 ? i * 8 : 0),
          )
          .setAngle(0)
          .setDisplaySize(48, 92)
          .setVisible(i < 3 || p.visitor !== null);
      });
      this.tools.forEach((tool, i) => {
        const task = s.assignments[WORKERS[i]],
          person = this.people[i];
        tool
          .clear()
          .setPosition(person.x + 15, person.y - 28)
          .setAngle(0);
        tool.setVisible(['plant', 'tend', 'harvest', 'repair'].includes(task));
        tool.lineStyle(3, 0x6d4b2b).lineBetween(0, 0, 2, -27);
        tool.lineStyle(4, 0x8e9893);
        if (task === 'harvest')
          tool.beginPath().arc(2, -27, 11, -Math.PI, 0).strokePath();
        else tool.lineBetween(task === 'repair' ? -5 : -9, -27, 9, -27);
      });
      element.dataset.motion = reduced ? 'reduced' : 'active';
      element.dataset.weather = p.weather;
      element.dataset.visitor = p.visitor ?? 'none';
      element.dataset.field = p.field;
      this.particles.forEach((particle, i) => {
        const rain = p.weather === 'rain',
          snow = p.weather === 'snow',
          leaf = p.weather === 'leaves';
        particle
          .setPosition((i * 137) % 1200, (i * 83) % 760)
          .setSize(rain ? 1 : leaf ? 7 : 4, rain ? 17 : leaf ? 3 : 4)
          .setFillStyle(
            snow ? 0xffffff : rain ? 0xb6c9cb : leaf ? 0xc88b35 : 0xf8e8bd,
            rain ? 0.4 : 0.65,
          )
          .setAngle(rain ? -15 : 0)
          .setVisible(!reduced && i < (snow || rain ? 48 : 20));
      });
      this.smoke.forEach((particle, i) =>
        particle
          .setPosition(733 + i * 4, 236 - i * 11)
          .setAlpha(0.25 - i * 0.035)
          .setVisible(!reduced),
      );
    }
    update(time: number, delta: number) {
      if (!this.loaded || !state || reduced) return;
      const p = presentation(state),
        dt = Math.min(delta, 80) / 1000;
      this.people.forEach((person, i) => {
        const working =
          i < 3 &&
          state!.phase === 'consequence' &&
          state!.assignments[WORKERS[i]] !== 'rest';
        person
          .setAngle(working ? Math.sin(time / 260 + i) * 5 : 0)
          .setScale(
            48 / 307,
            (92 / 590) * (1 + Math.sin(time / 1400 + i) * 0.012),
          );
      });
      this.tools.forEach((tool, i) =>
        tool.setAngle(
          state!.phase === 'consequence' ? Math.sin(time / 260 + i) * 22 : 0,
        ),
      );
      this.particles.forEach((particle, i) => {
        particle.x +=
          (p.weather === 'rain' ? 28 : 10 + Math.sin(time / 1200 + i) * 8) * dt;
        particle.y +=
          (p.weather === 'rain'
            ? 290
            : p.weather === 'snow'
              ? 30
              : p.weather === 'motes'
                ? -7
                : 18) * dt;
        if (particle.y > 775) particle.y = -20;
        if (particle.y < -25) particle.y = 770;
        if (particle.x > 1210) particle.x = -10;
        if (p.weather === 'leaves') particle.rotation += dt * 0.5;
      });
      this.smoke.forEach((particle, i) => {
        const progress = (time / 5500 + i / 5) % 1;
        particle
          .setPosition(733 + progress * 30, 236 - progress * 65)
          .setScale(0.7 + progress)
          .setAlpha((1 - progress) * 0.23);
      });
    }
  }
  const scene = new Homestead();
  const game = new Phaser.Game({
    type: Phaser.CANVAS,
    parent: element,
    width: 1200,
    height: 760,
    backgroundColor: '#dce6d4',
    scene: [scene],
    banner: false,
    audio: { noAudio: true },
    fps: { target: 30 },
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    render: { antialias: true, roundPixels: false },
  });
  return {
    update(s, m) {
      state = s;
      reduced = m;
      scene.paint();
    },
    destroy() {
      game.destroy(true);
    },
  };
}
