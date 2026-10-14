import { useEffect, useRef, useState, type RefObject } from 'react';
import { keyTime, tokenBezier, tokenSpring, type Spring } from './tokens';

export const clamp = (value: number, min = 0, max = 1) => Math.min(max, Math.max(min, value));
export const lerp = (from: number, to: number, p: number) => from + (to - from) * p;
export const seg = (t: number, start: number, end: number) => clamp((t - start) / (end - start));

function bezier(x1: number, y1: number, x2: number, y2: number) {
  const curve = (a: number, b: number, u: number) =>
    3 * a * u * (1 - u) * (1 - u) + 3 * b * u * u * (1 - u) + u * u * u;
  return (x: number) => {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let low = 0;
    let high = 1;
    let u = x;
    for (let step = 0; step < 18; step += 1) {
      const guess = curve(x1, x2, u);
      if (Math.abs(guess - x) < 0.0005) break;
      if (guess < x) low = u;
      else high = u;
      u = (low + high) / 2;
    }
    return curve(y1, y2, u);
  };
}

export function springValue(spring: Spring, time: number) {
  if (time <= 0) return 0;
  const omega = (2 * Math.PI) / spring.response;
  if (spring.damping >= 1) return 1 - Math.exp(-omega * time) * (1 + omega * time);
  const damped = omega * Math.sqrt(1 - spring.damping * spring.damping);
  const decay = Math.exp(-spring.damping * omega * time);
  return 1 - decay * (Math.cos(damped * time) + ((spring.damping * omega) / damped) * Math.sin(damped * time));
}

export interface Motion {
  out: (p: number) => number;
  in: (p: number) => number;
  settle: (time: number) => number;
  momentum: (time: number) => number;
  press: (time: number) => number;
  keyTime: number;
}

export function createMotion(): Motion {
  const springs = {
    default: tokenSpring('default'),
    momentum: tokenSpring('momentum'),
    press: tokenSpring('press'),
  };
  return {
    out: bezier(...tokenBezier('--ease-out')),
    in: bezier(...tokenBezier('--ease-in')),
    settle: (time) => springValue(springs.default, time),
    momentum: (time) => springValue(springs.momentum, time),
    press: (time) => springValue(springs.press, time),
    keyTime: keyTime(),
  };
}

export function useInView<T extends Element>(
  ref: RefObject<T | null>,
  options: { once?: boolean; threshold?: number; rootMargin?: string } = {},
) {
  const { once = false, threshold = 0.3, rootMargin = '0px' } = options;
  const [seen, setSeen] = useState(false);
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const observer = new IntersectionObserver(
      (entries) => {
        const hit = entries.some((entry) => entry.isIntersecting);
        setSeen((current) => (once ? current || hit : hit));
      },
      { threshold, rootMargin },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref, once, threshold, rootMargin]);
  return seen;
}

export function useReveal<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  useEffect(() => {
    const root = ref.current;
    if (!root) return;
    const targets = [root, ...Array.from(root.querySelectorAll<HTMLElement>('[data-reveal]'))];
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          entry.target.setAttribute('data-in', '');
          observer.unobserve(entry.target);
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -6% 0px' },
    );
    for (const target of targets) observer.observe(target);
    return () => observer.disconnect();
  }, []);
  return ref;
}

export function useTabVisible() {
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    const update = () => setVisible(document.visibilityState === 'visible');
    update();
    document.addEventListener('visibilitychange', update);
    return () => document.removeEventListener('visibilitychange', update);
  }, []);
  return visible;
}

interface SpringAxis {
  value: number;
  velocity: number;
  target: number;
}

export function createSpring2D(apply: (x: number, y: number) => void, { response, damping }: Spring) {
  const x: SpringAxis = { value: 0, velocity: 0, target: 0 };
  const y: SpringAxis = { value: 0, velocity: 0, target: 0 };
  const omega = (2 * Math.PI) / response;
  let frame = 0;
  let last = 0;

  const step = (axis: SpringAxis, dt: number) => {
    const force = -omega * omega * (axis.value - axis.target) - 2 * damping * omega * axis.velocity;
    axis.velocity += force * dt;
    axis.value += axis.velocity * dt;
  };

  const tick = (now: number) => {
    const dt = Math.min(0.032, (now - last) / 1000);
    last = now;
    step(x, dt);
    step(y, dt);
    apply(x.value, y.value);
    const still =
      Math.abs(x.velocity) + Math.abs(y.velocity) < 0.02 &&
      Math.abs(x.value - x.target) + Math.abs(y.value - y.target) < 0.02;
    if (still) {
      frame = 0;
      return;
    }
    frame = requestAnimationFrame(tick);
  };

  return {
    to(nextX: number, nextY: number) {
      x.target = nextX;
      y.target = nextY;
      if (!frame) {
        last = performance.now();
        frame = requestAnimationFrame(tick);
      }
    },
    stop() {
      if (frame) cancelAnimationFrame(frame);
      frame = 0;
    },
  };
}
