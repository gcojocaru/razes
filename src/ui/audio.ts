/** Quiet wind and a soft cue, synthesized locally after a user gesture. */
export class Ambience {
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private started = false;
  async setEnabled(enabled: boolean) {
    if (!enabled) {
      if (this.master && this.context)
        this.master.gain.setTargetAtTime(0, this.context.currentTime, 0.15);
      return;
    }
    try {
      this.context ??= new AudioContext();
      await this.context.resume();
      if (!this.started) {
        const c = this.context;
        this.master = c.createGain();
        this.master.gain.value = 0;
        this.master.connect(c.destination);
        const buffer = c.createBuffer(1, c.sampleRate * 4, c.sampleRate),
          samples = buffer.getChannelData(0);
        let previous = 0;
        for (let i = 0; i < samples.length; i++) {
          previous = (previous + Math.random() * 0.04 - 0.02) / 1.02;
          samples[i] = previous;
        }
        const wind = c.createBufferSource();
        wind.buffer = buffer;
        wind.loop = true;
        const filter = c.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.value = 650;
        wind.connect(filter);
        filter.connect(this.master);
        wind.start();
        this.started = true;
      }
      this.master!.gain.setTargetAtTime(0.15, this.context.currentTime, 0.4);
    } catch {
      /* Sound is optional; browser audio support never blocks play. */
    }
  }
  cue() {
    if (!this.context || !this.master || this.master.gain.value < 0.01) return;
    const c = this.context,
      o = c.createOscillator(),
      g = c.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(440, c.currentTime);
    o.frequency.exponentialRampToValueAtTime(330, c.currentTime + 0.15);
    g.gain.setValueAtTime(0.09, c.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, c.currentTime + 0.3);
    o.connect(g);
    g.connect(this.master);
    o.start();
    o.stop(c.currentTime + 0.3);
  }
}
