import { DURATION, PANEL_PARTS, TILE_START, TILE_STEP } from './timeline';

type Hit = (when: number) => void;
interface ScoreEvent {
  t: number;
  fn: Hit;
}
interface Bus {
  dry: GainNode;
  wet: GainNode;
}

const BEAT = 0.5;
const LOOKAHEAD = 0.2;
const CHORDS = [
  [57, 60, 64],
  [53, 57, 60],
  [48, 52, 55],
  [55, 59, 62],
];
const ROOTS = [33, 29, 36, 31];
const note = (midi: number) => 440 * Math.pow(2, (midi - 69) / 12);

export interface ReelAudio {
  start: (t: number) => void;
  stop: () => void;
  pump: () => void;
  time: () => number | null;
  resume: () => Promise<void>;
  suspend: () => void;
  close: () => void;
  state: () => AudioContextState;
}

export function createReelAudio(): ReelAudio {
  const Ctor: typeof AudioContext =
    window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  const ac = new Ctor();
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -14;
  comp.ratio.value = 4;
  const out = ac.createGain();
  out.gain.value = 0.8;
  out.connect(comp);
  comp.connect(ac.destination);

  const noiseBuffer = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate);
  const noiseData = noiseBuffer.getChannelData(0);
  for (let i = 0; i < noiseData.length; i += 1) noiseData[i] = Math.random() * 2 - 1;

  const impulse = ac.createBuffer(2, Math.floor(ac.sampleRate * 2.4), ac.sampleRate);
  for (let channel = 0; channel < 2; channel += 1) {
    const data = impulse.getChannelData(channel);
    for (let i = 0; i < data.length; i += 1) {
      data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / data.length, 3.2);
    }
  }
  const convolver = ac.createConvolver();
  convolver.buffer = impulse;
  const reverb = ac.createGain();
  reverb.gain.value = 0.3;
  reverb.connect(convolver);
  convolver.connect(comp);

  let bus: Bus | null = null;
  const timers = new Set<ReturnType<typeof setTimeout>>();

  const newBus = () => {
    if (bus) {
      const old = bus;
      old.dry.gain.setTargetAtTime(0, ac.currentTime, 0.02);
      old.wet.gain.setTargetAtTime(0, ac.currentTime, 0.02);
      const timer = setTimeout(() => {
        timers.delete(timer);
        old.dry.disconnect();
        old.wet.disconnect();
      }, 300);
      timers.add(timer);
    }
    const dry = ac.createGain();
    const wet = ac.createGain();
    dry.connect(out);
    wet.connect(reverb);
    bus = { dry, wet };
    return bus;
  };

  const live = () => bus ?? newBus();

  const env = (gain: GainNode, when: number, peak: number, attack: number, decay: number) => {
    gain.gain.setValueAtTime(0.0001, when);
    gain.gain.exponentialRampToValueAtTime(peak, when + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + attack + decay);
  };

  const osc = (
    type: OscillatorType,
    frequency: number,
    when: number,
    duration: number,
    peak: number,
    attack: number,
    decay: number,
    wet = 0,
    glideTo?: number,
  ) => {
    const target = live();
    const source = ac.createOscillator();
    const gain = ac.createGain();
    source.type = type;
    source.frequency.setValueAtTime(frequency, when);
    if (glideTo) source.frequency.exponentialRampToValueAtTime(glideTo, when + duration);
    env(gain, when, peak, attack, decay);
    source.connect(gain);
    gain.connect(target.dry);
    if (wet) {
      const send = ac.createGain();
      send.gain.value = wet;
      gain.connect(send);
      send.connect(target.wet);
    }
    source.start(when);
    source.stop(when + attack + decay + 0.05);
  };

  const noise = (
    when: number,
    duration: number,
    peak: number,
    type: BiquadFilterType,
    frequency: number,
    q = 1,
    sweepTo?: number,
    wet = 0,
  ) => {
    const target = live();
    const source = ac.createBufferSource();
    source.buffer = noiseBuffer;
    const filter = ac.createBiquadFilter();
    filter.type = type;
    filter.frequency.setValueAtTime(frequency, when);
    filter.Q.value = q;
    if (sweepTo) filter.frequency.exponentialRampToValueAtTime(sweepTo, when + duration);
    const gain = ac.createGain();
    env(gain, when, peak, Math.min(0.01, duration / 3), duration);
    source.connect(filter);
    filter.connect(gain);
    gain.connect(target.dry);
    if (wet) {
      const send = ac.createGain();
      send.gain.value = wet;
      gain.connect(send);
      send.connect(target.wet);
    }
    source.start(when);
    source.stop(when + duration + 0.05);
  };

  const I = {
    kick: (w: number) => osc('sine', 150, w, 0.12, 0.85, 0.003, 0.38, 0, 42),
    clap: (w: number) => {
      noise(w, 0.14, 0.3, 'bandpass', 1600, 1.2);
      noise(w + 0.012, 0.16, 0.2, 'bandpass', 1400, 1.2, undefined, 0.3);
    },
    hat: (w: number, open = false) => noise(w, open ? 0.18 : 0.045, open ? 0.08 : 0.06, 'highpass', 8000),
    bass: (w: number, midi: number) => {
      const target = live();
      const source = ac.createOscillator();
      const filter = ac.createBiquadFilter();
      const gain = ac.createGain();
      source.type = 'sawtooth';
      source.frequency.value = note(midi);
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(900, w);
      filter.frequency.exponentialRampToValueAtTime(180, w + 0.2);
      env(gain, w, 0.2, 0.005, 0.22);
      source.connect(filter);
      filter.connect(gain);
      gain.connect(target.dry);
      source.start(w);
      source.stop(w + 0.3);
    },
    pad: (w: number, notes: number[], duration: number, level = 0.045) => {
      const target = live();
      for (const midi of notes) {
        for (const detune of [-6, 6]) {
          const source = ac.createOscillator();
          const filter = ac.createBiquadFilter();
          const gain = ac.createGain();
          source.type = 'sawtooth';
          source.frequency.value = note(midi);
          source.detune.value = detune;
          filter.type = 'lowpass';
          filter.frequency.value = 1400;
          gain.gain.setValueAtTime(0.0001, w);
          gain.gain.linearRampToValueAtTime(level, w + 0.35);
          gain.gain.setValueAtTime(level, w + duration - 0.4);
          gain.gain.linearRampToValueAtTime(0.0001, w + duration);
          source.connect(filter);
          filter.connect(gain);
          gain.connect(target.dry);
          const send = ac.createGain();
          send.gain.value = 0.6;
          gain.connect(send);
          send.connect(target.wet);
          source.start(w);
          source.stop(w + duration + 0.05);
        }
      }
    },
    bell: (w: number, midi: number, level = 0.16, decay = 0.9) => {
      osc('sine', note(midi), w, decay, level, 0.004, decay, 0.7);
      osc('sine', note(midi) * 2.01, w, decay, level * 0.35, 0.004, decay * 0.5, 0.7);
    },
    pluck: (w: number, midi: number, level = 0.14) => osc('triangle', note(midi), w, 0.3, level, 0.003, 0.28, 0.35),
    pop: (w: number, midi: number, level = 0.2) =>
      osc('sine', note(midi) * 1.9, w, 0.07, level, 0.002, 0.12, 0.25, note(midi)),
    click: (w: number) => noise(w, 0.02, 0.05, 'highpass', 3500),
    tick: (w: number) => noise(w, 0.015, 0.035, 'bandpass', 2400, 6),
    whoosh: (w: number, duration: number, up = true) =>
      noise(w, duration, 0.2, 'bandpass', up ? 300 : 4000, 1.4, up ? 4500 : 250, 0.25),
    riser: (w: number, duration: number) => {
      noise(w, duration, 0.14, 'bandpass', 400, 2, 7000, 0.3);
      osc('sawtooth', 110, w, duration, 0.03, duration * 0.9, 0.08, 0.2, 440);
    },
    crash: (w: number) => noise(w, 1.6, 0.18, 'highpass', 5000, 0.7, undefined, 0.5),
    thud: (w: number) => osc('sine', 110, w, 0.15, 0.45, 0.003, 0.25, 0, 50),
    chime: (w: number, low = false) => {
      const base = low ? 81 : 86;
      I.bell(w, base, 0.2, 1.1);
      I.bell(w + 0.11, base + 5, 0.16, 1.2);
    },
  };

  const score: ScoreEvent[] = [];
  const at = (t: number, fn: Hit) => score.push({ t, fn });

  for (let bar = 0; bar < 14; bar += 1) {
    const t0 = bar * 2;
    const chord = CHORDS[bar % 4];
    at(t0, (w) => I.pad(w, chord, 2.05, t0 >= 12 && t0 < 14 ? 0.06 : 0.04));
  }
  at(28, (w) => I.pad(w, [48, 55, 60, 64, 67, 74], 2, 0.06));

  const groove = (from: number, to: number, full: boolean) => {
    for (let t = from; t < to - 0.001; t += BEAT) {
      const beat = Math.round(t / BEAT);
      at(t, I.kick);
      if (full && beat % 2 === 1) at(t, I.clap);
      at(t + 0.25, (w) => I.hat(w, beat % 4 === 3));
      const root = ROOTS[Math.floor(t / 2) % 4];
      at(t, (w) => I.bass(w, root + 12));
      at(t + 0.25, (w) => I.bass(w, root + (beat % 2 ? 24 : 12)));
    }
  };
  groove(4, 12, true);
  groove(14, 19.5, true);
  groove(19.5, 22.5, false);
  groove(22.5, 27.5, true);

  for (let t = 0; t < 4; t += 0.5) at(t, (w) => I.hat(w));
  for (let t = 12; t < 14; t += 0.25) {
    const chord = CHORDS[Math.floor(t / 2) % 4];
    at(t, (w) => I.bell(w, chord[Math.round(t * 4) % 3] + 24, 0.05, 0.5));
  }

  at(0.08, (w) => I.pop(w, 69, 0.2));
  at(0.3, (w) => I.whoosh(w, 0.5));
  at(0.85, (w) => {
    I.bell(w, 81, 0.2, 1.4);
    I.bell(w, 88, 0.12, 1.2);
    I.thud(w);
  });
  for (let i = 0; i < 6; i += 1) at(0.95 + i * 0.05, (w) => I.pop(w, [69, 72, 76, 79, 81, 84][i], 0.1));
  at(1.4, (w) => I.whoosh(w, 0.45));
  for (let i = 0; i < 6; i += 1) at(1.6 + i * 0.05, (w) => I.pluck(w, [57, 60, 64, 67, 69, 72][i], 0.18));
  for (let t = 1.9; t < 2.5; t += 0.05) at(t, I.click);
  at(2.5, (w) => I.riser(w, 1.5));
  at(4, (w) => {
    I.crash(w);
    I.thud(w);
    I.whoosh(w, 0.5, false);
  });
  for (let i = 0; i < 9; i += 1) at(4.05 + i * 0.06, (w) => I.pop(w, [57, 60, 64, 67, 69, 72, 76, 79, 81][i], 0.09));

  at(8, (w) => I.whoosh(w, 0.45));
  at(8.1, (w) => I.whoosh(w, 0.45, false));
  at(9, (w) => {
    I.click(w);
    I.thud(w);
  });
  at(10, (w) => {
    I.click(w);
    I.bell(w, 76, 0.16, 0.7);
    I.bell(w + 0.12, 83, 0.14, 0.9);
  });
  at(11.5, (w) => I.whoosh(w, 0.45, false));
  at(11.7, (w) => I.whoosh(w, 0.4));
  at(12.3, (w) => {
    I.click(w);
    I.pop(w, 64, 0.22);
  });
  PANEL_PARTS.forEach((part, index) => {
    at(part, (w) => I.pop(w, [67, 69, 72, 74, 76, 79, 81, 84][index % 8], 0.12));
  });
  at(13, (w) => I.riser(w, 1));
  at(14, (w) => I.crash(w));

  at(14.5, (w) => {
    I.click(w);
    I.pop(w, 72, 0.2);
  });
  at(15.5, (w) => {
    I.click(w);
    I.pluck(w, 76, 0.2);
    I.pluck(w + 0.1, 81, 0.16);
  });
  at(17, (w) => {
    I.click(w);
    I.whoosh(w, 0.35);
    [72, 76, 79, 84].forEach((midi) => I.bell(w, midi, 0.12, 1.2));
  });
  at(17.32, (w) => I.pop(w, 67, 0.16));
  at(18.5, (w) => {
    I.click(w);
    I.pop(w, 79, 0.18);
    I.pop(w + 0.08, 72, 0.16);
  });
  at(19.1, (w) => I.whoosh(w, 0.4));

  for (let t = 19.625; t < 22.2; t += 0.125) at(t, I.tick);
  at(20.5, (w) => I.pluck(w, 69, 0.24));
  at(21.6, (w) => {
    I.thud(w);
    I.bell(w, 57, 0.2, 1);
  });

  at(22.5, (w) => {
    I.whoosh(w, 0.35);
    I.chime(w);
  });
  [22.85, 23.02, 23.17, 23.3].forEach((t, index) => at(t, (w) => I.bell(w, 93 - index, 0.05, 0.25)));
  at(23.5, (w) => {
    I.whoosh(w, 0.35);
    I.chime(w, true);
  });
  [23.85, 24.02, 24.17, 24.3].forEach((t, index) => at(t, (w) => I.bell(w, 88 - index, 0.05, 0.25)));
  at(24.7, (w) => I.whoosh(w, 0.4, false));

  for (let i = 0; i < 6; i += 1) {
    at(TILE_START + i * TILE_STEP, (w) => I.pop(w, [69, 72, 74, 76, 79, 81][i], 0.16));
  }
  at(27.2, (w) => I.whoosh(w, 0.4, false));
  at(27.5, (w) => I.riser(w, 0.5));
  at(28, (w) => {
    I.crash(w);
    I.thud(w);
    I.kick(w);
    [48, 60, 64, 67, 74].forEach((midi) => I.bell(w, midi + 12, 0.12, 2));
  });
  for (let i = 0; i < 6; i += 1) at(28.4 + i * 0.125, (w) => I.bell(w, [84, 86, 88, 91, 93, 96][i], 0.07, 0.7));

  score.sort((a, b) => a.t - b.t);

  let clock: { t0: number; c0: number } | null = null;
  let cursor = 0;
  let loopBase = 0;

  return {
    start(t) {
      newBus();
      clock = { t0: t, c0: ac.currentTime + 0.06 };
      cursor = score.findIndex((event) => event.t >= t - 0.001);
      if (cursor < 0) cursor = score.length;
      loopBase = 0;
    },
    stop() {
      if (bus) newBus();
      clock = null;
    },
    pump() {
      if (!clock) return;
      const now = clock.t0 + (ac.currentTime - clock.c0);
      for (let guard = 0; guard < 4000; guard += 1) {
        if (cursor >= score.length) {
          loopBase += DURATION;
          cursor = 0;
        }
        const event = score[cursor];
        const absolute = loopBase + event.t;
        if (absolute > now + LOOKAHEAD) break;
        const when = clock.c0 + (absolute - clock.t0);
        if (when >= ac.currentTime - 0.02) event.fn(Math.max(when, ac.currentTime));
        cursor += 1;
      }
    },
    time() {
      if (!clock) return null;
      return (clock.t0 + Math.max(0, ac.currentTime - clock.c0)) % DURATION;
    },
    resume: () => ac.resume(),
    suspend() {
      void ac.suspend();
    },
    close() {
      for (const timer of timers) clearTimeout(timer);
      timers.clear();
      clock = null;
      void ac.close();
    },
    state: () => ac.state,
  };
}
