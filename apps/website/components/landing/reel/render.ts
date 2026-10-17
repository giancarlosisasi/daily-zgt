import { clamp, createMotion, lerp, seg } from '../motion';
import { NOW, dueLabel } from '../model';
import { token, tokenHex, tokenSeconds } from '../tokens';
import { CAPTIONS, DONE_BURST, PALETTE, PANEL_PARTS, STEPS, TILES, TILE_START, TILE_STEP } from './timeline';

const T_ADD = 14.5;
const T_ASK = 15.5;
const T_DONE = 17;
const T_GONE = 17.32;
const T_UNDO = 18.5;
const ROW = 48;
const CONFIRM = 48;
const PRESSES = [9, 10, 12.3, T_ADD, T_ASK, T_DONE, T_UNDO];
const CURSOR: [number, number, number][] = [
  [8.4, 420, 780],
  [8.95, 162, 466],
  [9.45, 162, 466],
  [9.95, 922, 460],
  [11.6, 922, 460],
  [11.9, 1150, 420],
  [12.27, 1390, 24],
  [13.7, 1390, 24],
  [14.45, 1254, 572],
  [14.95, 1254, 572],
  [15.45, 1031, 322],
  [16.3, 1031, 322],
  [16.92, 1472, 409],
  [17.9, 1472, 409],
  [18.45, 1472, 647],
  [19.3, 1472, 647],
];
const CLOCK: [number, number][] = [
  [19.2, 640],
  [20.5, 661],
  [21.6, 781],
  [22.5, 810],
];
const DUE_AT = NOW + 36 * 60000;
const DAY_START = NOW - (12 * 60 + 24) * 60000;
const RING = [0, 14, -12, 8, -4, 0];
const RING_AT = [0, 0.25, 0.45, 0.65, 0.85, 1];
const SCRAMBLE = '0123456789ABCDEF';
const GLOW = {
  late: '--panel-late-bg',
  soon: '--panel-soon-bg',
  later: '--panel-later-bg',
};

const pad = (n: number) => String(n).padStart(2, '0');

const scramble = (target: string, p: number, seed: number) =>
  [...target]
    .map((char, index) => {
      if (p >= (index + 1) / target.length) return char;
      if (p <= 0) return '';
      return SCRAMBLE[(Math.floor(p * 60) + index * 7 + seed * 3) % SCRAMBLE.length];
    })
    .join('');

const ring = (p: number) => {
  if (p <= 0 || p >= 1) return 0;
  for (let i = 1; i < RING.length; i += 1) {
    if (p <= RING_AT[i]) {
      return lerp(RING[i - 1], RING[i], seg(p, RING_AT[i - 1], RING_AT[i]));
    }
  }
  return 0;
};

const piecewise = (points: [number, number][], t: number) => {
  if (t <= points[0][0]) return points[0][1];
  for (let i = 1; i < points.length; i += 1) {
    if (t <= points[i][0]) return lerp(points[i - 1][1], points[i][1], seg(t, points[i - 1][0], points[i][0]));
  }
  return points[points.length - 1][1];
};

const random = (seed: number) => () => {
  seed = (seed * 16807) % 2147483647;
  return (seed - 1) / 2147483646;
};

interface Particle {
  vx: number;
  vy: number;
  color: string;
  size: number;
  rot: number;
  spin: number;
  square: boolean;
  life: number;
}

interface Burst {
  t0: number;
  x: number;
  y: number;
  gravity: number;
  parts: Particle[];
}

const makeBurst = (
  t0: number,
  x: number,
  y: number,
  count: number,
  speed: number,
  seed: number,
  colors: readonly string[],
  gravity: number,
): Burst => {
  const next = random(seed);
  const parts = Array.from({ length: count }, () => {
    const angle = next() * Math.PI * 2;
    const velocity = speed * (0.35 + next() * 0.75);
    return {
      vx: Math.cos(angle) * velocity,
      vy: Math.sin(angle) * velocity - (gravity > 400 ? 380 : 0),
      color: colors[Math.floor(next() * colors.length)],
      size: 6 + next() * 12,
      rot: next() * 6,
      spin: (next() - 0.5) * 14,
      square: next() < 0.5,
      life: 0.9 + next() * 0.8,
    };
  });
  return { t0, x, y, gravity, parts };
};

const PALETTE_TOKENS = PALETTE.map((item) => item.token);
const BURSTS = [
  makeBurst(0.85, 800, 450, 42, 820, 7, PALETTE_TOKENS, 120),
  makeBurst(T_DONE, 1472, 409, 54, 760, 42, DONE_BURST, 900),
  makeBurst(28, 330, 450, 84, 1050, 99, PALETTE_TOKENS, 900),
];

export function createRenderer(root: HTMLElement) {
  const m = createMotion();
  const undoTime = tokenSeconds('--duration-undo');
  const paint = new Map([...PALETTE_TOKENS, ...DONE_BURST, ...Object.values(GLOW)].map((name) => [name, token(name)]));
  const hexCodes = PALETTE.map((item) => tokenHex(item.token));
  const pressScale = Number.parseFloat(token('--control-press-scale'));
  const depth = (t: number, at: number) => {
    if (t < at) return 0;
    if (t < at + m.keyTime) return seg(t, at, at + m.keyTime);
    return 1 - m.press(t - at - m.keyTime);
  };
  const one = <T extends Element = HTMLElement>(name: string) =>
    root.querySelector(`[data-r="${name}"]`) as unknown as T;
  const all = <T extends Element = HTMLElement>(name: string) =>
    Array.from(root.querySelectorAll(`[data-r="${name}"]`)) as unknown as T[];
  const text = (element: Element, value: string) => {
    if (element.textContent !== value) element.textContent = value;
  };

  const glow = one('glow');
  const shock = one('shock');
  const mark = one('mark');
  const markOuter = one<SVGCircleElement>('markOuter');
  const markInner = one<SVGCircleElement>('markInner');
  const markDot = one<SVGCircleElement>('markDot');
  const bars = all('bar');
  const hexBoxes = all('hexBox');
  const hexes = all('hex');
  const word = one('word');
  const letters = all('letter');
  const cmpA = one('cmpA');
  const cmpB = one('cmpB');
  const plainRow = one('plainRow');
  const cmpCheck = one('cmpCheck');
  const cmpConfirm = one('cmpConfirm');
  const strip = one('strip');
  const stripItem = one('stripItem');
  const stripCount = one('stripCount');
  const panelWrap = one('panelWrap');
  const panel = one('panel');
  const parts = Array.from(root.querySelectorAll<HTMLElement>('[data-part]'));
  const scopeToday = one('scopeToday');
  const list = one('list');
  const rows = all('row');
  const newRow = one('newRow');
  const rowCheck = one('rowCheck');
  const confirm = one('confirm');
  const hechas = one('hechas');
  const newBtn = one('newBtn');
  const undo = one('undo');
  const undoBtn = one('undoBtn');
  const undoLine = one('undoLine');
  const confirmYes = one('confirmYes');
  const undoClock = one('undoClock');
  const footer = one('footer');
  const steps = all('step');
  const clock = one('clock');
  const hourHand = one<SVGLineElement>('hourHand');
  const minuteHand = one<SVGLineElement>('minuteHand');
  const clockText = one('clockText');
  const bigChip = one('bigChip');
  const bigChipText = one('bigChipText');
  const timeline = one('tl');
  const tlLine = one('tlLine');
  const tlHead = one('tlHead');
  const tlMarks = all('tlMark');
  const notes = [one('note1'), one('note2')];
  const noteBells = [one<SVGElement>('note1Bell'), one<SVGElement>('note2Bell')];
  const tiles = all('tile');
  const tileNums = all('tileNum');
  const vizTables = all('vizTable');
  const vizLevels = all('vizLevel');
  const vizLists = all('vizList');
  const vizBells = all('vizBell');
  const vizUndo = one('vizUndo');
  const vizFile = one('vizFile');
  const lockMark = one('lockMark');
  const lockWord = one('lockWord');
  const lockLine = one('lockLine');
  const lockTagChars = all('lockTagChar');
  const lockCreditChars = all('lockCreditChar');
  const caps = all('cap').map((element, index) => ({
    element,
    words: Array.from(element.querySelectorAll<HTMLElement>('.rl-w')),
    caption: CAPTIONS[index],
  }));
  const ripple = one('ripple');
  const cursor = one('cursor');
  const canvas = one<HTMLCanvasElement>('fx');
  const fx = canvas.getContext('2d');

  const drawFx = (t: number) => {
    if (!fx) return;
    fx.clearRect(0, 0, 1600, 900);
    for (const burst of BURSTS) {
      const dt = t - burst.t0;
      if (dt < 0 || dt > 2) continue;
      for (const part of burst.parts) {
        if (dt > part.life) continue;
        const drag = (1 - Math.exp(-2.6 * dt)) / 2.6;
        const x = burst.x + part.vx * drag;
        const y = burst.y + part.vy * drag + 0.5 * burst.gravity * dt * dt;
        fx.save();
        fx.globalAlpha = 1 - seg(dt, part.life * 0.6, part.life);
        fx.translate(x, y);
        fx.rotate(part.rot + part.spin * dt);
        fx.fillStyle = paint.get(part.color) ?? '';
        if (part.square) {
          fx.fillRect(-part.size / 2, -part.size / 4, part.size, (part.size / 2) * Math.abs(Math.cos(part.spin * dt * 1.4)) + 1);
        } else {
          fx.beginPath();
          fx.arc(0, 0, part.size * 0.32, 0, Math.PI * 2);
          fx.fill();
        }
        fx.restore();
      }
    }
  };

  const renderOpen = (t: number) => {
    const visible = t > 0.06 && t < 1.5;
    mark.style.opacity = visible ? '1' : '0';
    if (visible) {
      const dip = seg(t, 0.72, 0.85);
      const punch = m.momentum(t - 0.85);
      const leave = m.in(seg(t, 1.1, 1.48));
      const scale = (1 - 0.14 * Math.sin(dip * Math.PI * 0.5) * (t < 0.85 ? 1 : 0) + (t >= 0.85 ? -0.14 + 0.14 * punch : 0)) * (1 - leave);
      mark.style.transform = `translate(670px,320px) rotate(${lerp(-40, 0, m.out(seg(t, 0.08, 0.8)))}deg) scale(${scale})`;
      markDot.setAttribute('r', String(1.2 * m.momentum(t - 0.08)));
      markInner.style.strokeDashoffset = String(1 - m.out(seg(t, 0.2, 0.6)));
      markOuter.style.strokeDashoffset = String(1 - m.out(seg(t, 0.32, 0.78)));
    }
    const wave = seg(t, 0.85, 1.5);
    const waveScale = m.out(wave) * 5;
    shock.style.opacity = wave > 0 && wave < 1 ? String(1 - wave) : '0';
    shock.style.transform = `translate(740px,390px) scale(${waveScale})`;
    shock.style.borderWidth = `${8 / Math.max(0.4, waveScale)}px`;
  };

  const renderPalette = (t: number) => {
    const column = 1600 / bars.length;
    bars.forEach((bar, index) => {
      const shown = t > 0.9 && t < 7.95;
      bar.style.opacity = shown ? '1' : '0';
      if (!shown) return;
      const angle = seg(t, 0.9, 1.7) * Math.PI * 2 + (index * Math.PI * 2) / bars.length;
      const orbit = 120 * m.momentum(t - 0.9) * (1 - m.out(seg(t, 1.4, 1.7)));
      const originX = 800 + Math.cos(angle) * orbit;
      const originY = 450 + Math.sin(angle) * orbit;
      const centerX = lerp(originX, index * column + column / 2, m.out(seg(t, 1.4, 1.8)));
      const grow = m.out(seg(t, 1.6 + index * 0.05, 2.15 + index * 0.05));
      let width = lerp(26, column + 1, grow);
      let height = lerp(26, 900, grow);
      let x = centerX - width / 2;
      let y = lerp(originY - 13, 0, grow);
      let radius = lerp(13, 0, grow);
      const fold = m.out(seg(t, 4 + index * 0.04, 4.45 + index * 0.04));
      if (fold > 0) {
        height = lerp(900, 8, fold);
        y = lerp(0, 640, fold);
        width = lerp(column + 1, 121, fold);
        x = lerp(index * column, 800 - bars.length * 60 + index * 120, fold);
        radius = lerp(0, 4, fold);
      }
      const leave = m.in(seg(t, 7.5, 7.9));
      if (leave > 0) {
        x = lerp(x, 800, leave);
        width *= 1 - leave;
      }
      bar.style.width = `${width}px`;
      bar.style.height = `${height}px`;
      bar.style.borderRadius = `${radius}px`;
      bar.style.transform = `translate(${x}px,${y}px)`;
      const label = seg(t, 1.9 + index * 0.02, 2.4 + index * 0.02);
      text(hexes[index], `#${scramble(hexCodes[index], label, index)}`);
      hexBoxes[index].style.opacity = label > 0 ? String(1 - seg(t, 3.95, 4.08)) : '0';
      hexBoxes[index].style.transform = `translateY(${(1 - m.out(seg(t, 1.9 + index * 0.02, 2.3 + index * 0.02))) * 24}px)`;
    });
  };

  const renderName = (t: number) => {
    const shown = t > 4 && t < 8;
    word.style.opacity = shown ? '1' : '0';
    if (!shown) return;
    letters.forEach((letter, index) => {
      const p = m.out(seg(t, 4.05 + index * 0.06, 4.75 + index * 0.06));
      const out = m.in(seg(t, 7.5 + index * 0.03, 7.85 + index * 0.03));
      const wave = seg(t, 4.9, 5.9);
      const weight = wave > 0 && wave < 1 ? 800 - 400 * Math.max(0, Math.sin((wave * 1.6 - index * 0.1) * Math.PI)) : 800;
      letter.style.fontWeight = weight.toFixed(0);
      letter.style.transform = `translateY(${(1 - p) * 110 + out * -120}%) rotate(${(1 - p) * 10}deg)`;
      letter.style.filter = out > 0 ? `blur(${out * 10}px)` : 'none';
      letter.style.opacity = String(1 - out);
    });
  };

  const renderCompare = (t: number) => {
    const shown = t > 8.05 && t < 11.95;
    cmpA.style.opacity = shown ? '1' : '0';
    cmpB.style.opacity = t > 8.15 && t < 11.95 ? '1' : '0';
    if (!shown) return;
    const inA = m.momentum(t - 8.05);
    const inB = m.momentum(t - 8.15);
    const out = m.in(seg(t, 11.5, 11.9));
    cmpA.style.transform = `translate(${lerp(-760, 100, inA) - out * 900}px,310px) rotate(${(1 - inA) * -4}deg)`;
    cmpB.style.transform = `translate(${lerp(1700, 820, inB) + out * 900}px,310px) rotate(${(1 - inB) * 4}deg)`;
    cmpA.style.filter = out > 0 ? `blur(${out * 10}px)` : 'none';
    cmpB.style.filter = out > 0 ? `blur(${out * 10}px)` : 'none';
    plainRow.classList.toggle('is-done', t >= 9);
    cmpCheck.classList.toggle('is-checked', t >= 10);
    const bar = m.settle(t - 10);
    cmpConfirm.style.height = `${bar * 52}px`;
    cmpConfirm.style.opacity = String(m.out(seg(t, 10, 10.22)));
  };

  const renderPanel = (t: number) => {
    const stripIn = m.out(seg(t, 11.7, 12.1));
    const stripOut = m.in(seg(t, 24.7, 25));
    strip.style.opacity = t > 11.7 && t < 25 ? '1' : '0';
    strip.style.transform = `translateY(${-46 * (1 - stripIn) - 46 * stripOut}px) scale(1.5)`;
    stripItem.classList.toggle('is-active', t >= 12.3 && t < 19.3);

    const open = t < T_ADD ? 3 : t < T_DONE ? 4 : t < T_UNDO ? 3 : 4;
    const done = t >= T_DONE && t < T_UNDO ? 2 : 1;
    const total = t < T_ADD ? 4 : 5;
    text(stripCount, String(open));

    const shown = t >= 12.3 && t < 19.5;
    panelWrap.style.opacity = shown ? '1' : '0';
    if (!shown) {
      undoClock.style.opacity = '0';
      return;
    }
    const pop = m.out(seg(t, 12.3, 12.5));
    const leave = m.in(seg(t, 19.15, 19.5));
    panelWrap.style.transform = `translateX(${leave * 260}px) scale(1.7)`;
    panelWrap.style.filter = leave > 0 ? `blur(${leave * 8}px)` : 'none';
    panel.style.opacity = String(pop * (1 - leave));
    panel.style.transform = `translateY(${-8 * (1 - pop)}px) scale(${lerp(0.96, 1, pop)})`;

    parts.forEach((part, index) => {
      const p = m.out(seg(t, PANEL_PARTS[index], PANEL_PARTS[index] + 0.22));
      part.style.opacity = String(p);
      part.style.transform = `translateY(${-4 * (1 - p)}px)`;
    });

    text(scopeToday, `Hoy · ${open}`);
    text(hechas, `Hechas (${done})`);
    text(footer, `${done} de ${total} hechas hoy`);

    let space = 0;
    if (t < T_GONE) {
      space = ROW * m.settle(t - T_ADD) + CONFIRM * m.settle(t - T_ASK);
    } else if (t < T_UNDO) {
      space = (ROW + CONFIRM) * (1 - m.settle(t - T_GONE));
    } else {
      space = ROW * m.settle(t - T_UNDO);
    }
    const tops = [0, ROW, ROW + space, ROW * 2 + space];
    rows.forEach((row, index) => {
      row.style.transform = `translateY(${tops[index]}px)`;
    });
    list.style.height = `${ROW * 3 - 2 + space}px`;

    let rowOpacity = 0;
    let rowX = 0;
    let rowY = 0;
    if (t >= T_ADD && t < T_DONE) {
      rowOpacity = m.out(seg(t, T_ADD + 0.1, T_ADD + 0.32));
      rowY = -4 * (1 - rowOpacity);
    } else if (t >= T_DONE && t < T_GONE) {
      const p = m.out(seg(t, T_DONE, T_GONE));
      rowOpacity = 1 - p;
      rowX = 28 * p;
    } else if (t >= T_UNDO) {
      rowOpacity = m.out(seg(t, T_UNDO + 0.1, T_UNDO + 0.32));
      rowY = -4 * (1 - rowOpacity);
    }
    newRow.style.opacity = String(rowOpacity);
    newRow.style.transform = `translate(${rowX}px,${rowY}px)`;
    rowCheck.classList.toggle('is-checked', t >= T_ASK && t < T_GONE);
    const asking = t >= T_ASK && t < T_GONE;
    confirm.style.height = asking ? `${CONFIRM * m.settle(t - T_ASK)}px` : '0px';
    confirm.style.opacity = asking ? String(m.out(seg(t, T_ASK, T_ASK + 0.22))) : '0';
    confirmYes.classList.toggle('is-down', t >= T_DONE && t < T_GONE);

    newBtn.style.scale = String(1 - (1 - pressScale) * depth(t, T_ADD));
    undoBtn.style.scale = String(1 - (1 - pressScale) * depth(t, T_UNDO));

    const undoIn = t >= T_GONE ? m.out(seg(t, T_GONE, T_GONE + 0.22)) * (1 - seg(t, T_UNDO, T_UNDO + 0.14)) : 0;
    const undoLeft = Math.max(0, undoTime - (Math.min(t, T_UNDO) - T_GONE));
    undo.style.height = `${36 * undoIn}px`;
    undo.style.marginTop = `${-10 * (1 - undoIn)}px`;
    undo.style.opacity = String(undoIn);
    undoLine.style.transform = `scaleX(${undoLeft / undoTime})`;
    undoClock.style.opacity = String(undoIn * (1 - leave));
    undoClock.style.transform = `translate(${792 - (1 - undoIn) * 20}px,622px)`;
    if (undoIn > 0) text(undoClock, `${undoLeft.toFixed(1)} s`);
  };

  const renderSteps = (t: number) => {
    const current = STEPS.reduce((found, step, index) => (t >= step.at ? index : found), -1);
    steps.forEach((step, index) => {
      const at = STEPS[index].at;
      const p = m.out(seg(t, at, at + 0.5));
      const out = m.in(seg(t, 19.1 + index * 0.03, 19.4 + index * 0.03));
      const shown = t >= at && t < 19.5;
      const dim = index === current ? 1 : 0.42;
      step.style.opacity = shown ? String(p * (1 - out) * dim) : '0';
      step.style.transform = `translate(${110 - out * 40}px,${250 + index * 132 + (1 - p) * 36}px)`;
      step.classList.toggle('is-on', index === current);
    });
  };

  const renderDue = (t: number) => {
    const shown = t >= 19.2 && t < 22.5;
    bigChip.style.opacity = shown ? '1' : '0';
    clock.style.opacity = shown ? '1' : '0';
    if (!shown) {
      glow.style.opacity = '0';
      return;
    }
    const minutes = Math.floor(piecewise(CLOCK, t));
    const label = dueLabel(DUE_AT, DAY_START + minutes * 60000);
    text(bigChipText, label.text);
    bigChipText.className = `dz-chip dz-chip--${label.tone}`;
    text(clockText, `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`);
    hourHand.setAttribute('transform', `rotate(${((minutes / 60) % 12) * 30} 12 12)`);
    minuteHand.setAttribute('transform', `rotate(${(minutes % 60) * 6} 12 12)`);

    const grow = m.out(seg(t, 19.2, 19.85));
    const leave = m.in(seg(t, 22.15, 22.5));
    let pulse = 1;
    for (const at of [20.5, 21.6]) {
      const k = seg(t, at, at + 0.6);
      if (k > 0 && k < 1) pulse = 1 + 0.12 * (1 - m.momentum(t - at));
    }
    const x = lerp(340, 0, grow);
    const y = lerp(-124, 0, grow);
    const scale = lerp(0.08, 1, grow) * pulse * (1 - leave * 0.25);
    bigChip.style.transform = `translate(${x}px,${y - leave * 40}px) scale(${scale})`;
    bigChip.style.opacity = String(clamp(grow * 4) * (1 - leave));
    bigChip.style.filter = leave > 0 ? `blur(${leave * 10}px)` : 'none';

    const clockIn = m.out(seg(t, 19.55, 20));
    clock.style.opacity = String(clockIn * (1 - leave));
    clock.style.transform = `translateY(${(1 - clockIn) * -30 - leave * 30}px)`;

    glow.style.opacity = String(seg(t, 19.4, 19.9) * (1 - leave));
    glow.style.background = `radial-gradient(circle at 50% 54%, ${paint.get(GLOW[label.tone])}, transparent 62%)`;
  };

  const renderAlert = (t: number) => {
    const shown = t >= 22.5 && t < 25;
    timeline.style.opacity = shown ? '1' : '0';
    notes.forEach((note, index) => {
      const at = 22.5 + index;
      const visible = t >= at && t < 25;
      note.style.opacity = visible ? '1' : '0';
      if (!visible) return;
      const p = m.out(seg(t, at, at + 0.35));
      const out = m.in(seg(t, 24.7 + index * 0.04, 24.95 + index * 0.04));
      note.style.opacity = String(p * (1 - out));
      note.style.transform = `translate(${908 + (1 - p) * 84 + out * 84}px,${84 + index * 268}px) scale(2.1)`;
      noteBells[index].style.transform = `rotate(${ring(seg(t, at + 0.35, at + 1.05))}deg)`;
    });
    if (!shown) return;
    const out = seg(t, 24.7, 24.95);
    timeline.style.opacity = String(1 - out);
    tlLine.style.transform = `scaleX(${m.out(seg(t, 22.5, 22.9))})`;
    const head = t < 23.5 ? lerp(160, 540, seg(t, 22.5, 23.5)) : lerp(540, 690, seg(t, 23.5, 24.7));
    tlHead.style.transform = `translateX(${head}px)`;
    tlMarks.forEach((mark, index) => {
      const p = m.momentum(t - 22.5 - index);
      mark.style.transform = `translateX(${160 + index * 380}px) scale(${p})`;
      mark.style.opacity = p > 0 ? '1' : '0';
    });
  };

  const renderTiles = (t: number) => {
    tiles.forEach((tile, index) => {
      const column = index % 3;
      const row = Math.floor(index / 3);
      const at = TILE_START + index * TILE_STEP;
      const p = m.momentum(t - at);
      const out = m.in(seg(t, 27.2 + index * 0.03, 27.5 + index * 0.03));
      tile.style.transform = `translate(${110 + column * 470}px,${95 + row * 370 + (1 - p) * 60}px) perspective(1200px) rotateX(${(1 - p) * 70}deg) scale(${1 - out * 0.6})`;
      tile.style.opacity = t > at && t < 27.6 ? String(clamp(p * 3) * (1 - out)) : '0';
      const count = m.out(seg(t, at + 0.1, at + 0.6));
      text(tileNums[index], String(Math.round(TILES[index].value * count)));
    });
    if (t < TILE_START || t > 27.6) return;
    const local = t - TILE_START;
    vizTables.forEach((item, index) => {
      const p = m.momentum(local - 0.2 - index * 0.06);
      item.style.transform = `scale(${p})`;
      item.style.opacity = String(clamp(p * 2));
    });
    vizLevels.forEach((item, index) => {
      const p = m.momentum(local - 0.3 - index * 0.1);
      item.style.transform = `scaleY(${p})`;
    });
    const active = Math.floor(local / 0.6) % 2;
    vizLists.forEach((item, index) => item.classList.toggle('is-on', index === active));
    vizBells.forEach((item, index) => {
      const at = 0.6 + index * 0.6;
      const svg = item.firstElementChild as SVGElement;
      svg.style.transform = `rotate(${ring(seg(local, at, at + 0.7))}deg)`;
      item.style.opacity = String(lerp(0.4, 1, seg(local, at, at + 0.1)));
    });
    vizUndo.style.transform = `scaleX(${1 - seg(local, 0.5, 0.5 + undoTime)})`;
    vizFile.style.transform = `scale(${m.momentum(local - 0.75)})`;
  };

  const renderLockup = (t: number) => {
    const shown = t >= 27.5;
    const fade = 1 - seg(t, 29.6, 30);
    lockMark.style.opacity = shown ? String(fade) : '0';
    lockWord.style.opacity = '0';
    lockLine.style.opacity = '0';
    if (!shown) {
      lockTagChars.forEach((char) => {
        char.style.opacity = '0';
      });
      lockCreditChars.forEach((char) => {
        char.style.opacity = '0';
      });
      return;
    }
    const fly = m.out(seg(t, 27.5, 28));
    const land = seg(t, 28, 28.5);
    const squash = land > 0 && land < 1 ? 0.16 * (1 - m.momentum(t - 28)) : 0;
    const x = lerp(1420, 245, fly);
    const y = lerp(760, 365, fly) - Math.sin(fly * Math.PI) * 180;
    lockMark.style.transform = `translate(${x}px,${y}px) rotate(${(1 - fly) * 200}deg) scale(${lerp(0.3, 1, fly) * (1 + squash)},${lerp(0.3, 1, fly) * (1 - squash)})`;
    const reveal = m.out(seg(t, 28, 28.5));
    lockWord.style.opacity = String(reveal * fade);
    lockWord.style.transform = `translate(${455 + (1 - reveal) * 60}px,345px)`;
    lockWord.style.clipPath = `inset(-10% ${(1 - reveal) * 100}% -10% 0)`;
    lockLine.style.opacity = String(fade);
    lockLine.style.width = `${720 * m.out(seg(t, 28.2, 28.6))}px`;
    lockTagChars.forEach((char, index) => {
      const p = seg(t, 28.4 + index * 0.012, 28.65 + index * 0.012);
      char.style.opacity = String(p * fade);
      char.style.transform = `translateY(${(1 - m.out(p)) * 14}px)`;
    });
    lockCreditChars.forEach((char, index) => {
      const p = seg(t, 28.8 + index * 0.01, 29 + index * 0.01);
      char.style.opacity = String(p * fade);
      char.style.transform = `translateY(${(1 - m.out(p)) * 10}px)`;
    });
  };

  const renderCaptions = (t: number) => {
    for (const { element, words, caption } of caps) {
      const on = t > caption.a - 0.05 && t < caption.b + 0.4;
      element.style.opacity = on ? '1' : '0';
      if (!on) continue;
      words.forEach((item, index) => {
        const p = m.out(seg(t, caption.a + index * 0.035, caption.a + index * 0.035 + 0.5));
        const out = m.in(seg(t, caption.b + index * 0.012, caption.b + index * 0.012 + 0.25));
        item.style.opacity = String(p * (1 - out));
        item.style.transform = `translateY(${(1 - p) * 0.5 - out * 0.35}em)`;
        item.style.filter = out > 0 ? `blur(${out * 8}px)` : 'none';
      });
    }
  };

  const renderCursor = (t: number) => {
    const visible = (t >= 8.4 && t < 11.6) || (t >= 11.9 && t < 19.3);
    let opacity = 0;
    if (visible) {
      opacity =
        t < 11.6
          ? seg(t, 8.4, 8.55) * (1 - seg(t, 11.45, 11.6))
          : seg(t, 11.9, 12.05) * (1 - seg(t, 19.1, 19.3));
    }
    cursor.style.opacity = String(opacity);
    let x = CURSOR[0][1];
    let y = CURSOR[0][2];
    for (let i = 1; i < CURSOR.length; i += 1) {
      const [t0, x0, y0] = CURSOR[i - 1];
      const [t1, x1, y1] = CURSOR[i];
      if (t >= t0) {
        const p = m.out(seg(t, t0, t1));
        x = lerp(x0, x1, p);
        y = lerp(y0, y1, p);
      }
    }
    let scale = 1;
    let wave = 0;
    for (const at of PRESSES) {
      if (t < at) continue;
      scale = 1 - 0.2 * depth(t, at);
      wave = seg(t, at, at + 0.45);
    }
    cursor.style.transform = `translate(${x - 9}px,${y - 6}px) scale(${scale})`;
    ripple.style.opacity = wave > 0 && wave < 1 && opacity > 0 ? String((1 - wave) * 0.7) : '0';
    ripple.style.transform = `translate(${x - 26}px,${y - 26}px) scale(${0.3 + m.out(wave) * 1.5})`;
  };

  return (t: number) => {
    renderOpen(t);
    renderPalette(t);
    renderName(t);
    renderCompare(t);
    renderPanel(t);
    renderSteps(t);
    renderDue(t);
    renderAlert(t);
    renderTiles(t);
    renderLockup(t);
    renderCaptions(t);
    renderCursor(t);
    drawFx(t);
  };
}
