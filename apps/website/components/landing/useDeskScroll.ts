import { useCallback, useEffect, useRef, type MutableRefObject, type RefObject } from 'react';
import { clamp } from './motion';

// The next step must be this share of a step closer to the focus line before it takes over.
const HOLD = 0.12;
// A clicked step ignores scroll-derived changes until the smooth scroll ends, or this long.
const LOCK_MS = 1200;

interface Options {
  reduced: boolean;
  current: MutableRefObject<number>;
  onStep: (index: number) => void;
}

function write(element: HTMLElement, name: string, value: number) {
  const text = value.toFixed(3);
  if (element.style.getPropertyValue(name) !== text) element.style.setProperty(name, text);
}

/**
 * One passive scroll listener, throttled by rAF, reads one rect per frame. It writes --desk-p
 * (0..1 over the steps) on the wall and the stage, and --step-p (1 at the focus line, 0 a step
 * away) on each step. The active step is the one nearest the focus line: the middle of the area
 * below the nav, or below the pinned panel on phones. Reduced motion writes no progress at all.
 * Returns scrollToStep, which centers a step on the focus line and holds the active step until
 * the scroll ends.
 */
export function useDeskScroll(root: RefObject<HTMLElement | null>, { reduced, current, onStep }: Options) {
  const scrollTo = useRef<(index: number) => void>(() => {});

  useEffect(() => {
    const section = root.current;
    const list = section?.querySelector<HTMLElement>('.dz-desk-steps');
    const stage = section?.querySelector<HTMLElement>('.dz-desk-stage');
    const wall = section?.querySelector<HTMLElement>('.dz-desk-wall');
    const inner = section?.querySelector<HTMLElement>('.dz-desk-inner');
    if (!section || !list || !stage || !wall || !inner) return;

    const items = Array.from(list.children) as HTMLElement[];
    const wide = window.matchMedia('(min-width: 961px)');
    let centers: number[] = [];
    let pitch = 1;
    let top = 0;
    let frame = 0;
    let locked = false;
    let release = () => {};

    const measure = () => {
      const box = list.getBoundingClientRect();
      centers = items.map((item) => {
        const rect = item.getBoundingClientRect();
        return rect.top - box.top + rect.height / 2;
      });
      pitch = centers.length > 1 ? (centers[centers.length - 1] - centers[0]) / (centers.length - 1) : 1;
      const pinned = Number.parseFloat(getComputedStyle(stage).top) || 0;
      top = wide.matches ? pinned : pinned + stage.offsetHeight;
    };

    const focus = () => top + (window.innerHeight - top) / 2;

    const update = () => {
      frame = 0;
      if (!centers.length) return;
      const box = list.getBoundingClientRect();
      if (box.bottom < 0 || box.top > window.innerHeight) return;
      const line = focus();
      const distance = centers.map((center) => box.top + center - line);

      if (!locked) {
        let best = 0;
        distance.forEach((value, index) => {
          if (Math.abs(value) < Math.abs(distance[best])) best = index;
        });
        const now = current.current;
        if (best !== now && Math.abs(distance[best]) + pitch * HOLD < Math.abs(distance[now])) onStep(best);
      }

      if (reduced) return;
      const span = centers[centers.length - 1] - centers[0] || 1;
      const progress = clamp((line - box.top - centers[0]) / span);
      write(wall, '--desk-p', progress);
      write(inner, '--desk-p', progress);
      items.forEach((item, index) => {
        write(item, '--step-p', clamp((0.8 - Math.abs(distance[index]) / pitch) / 0.65));
      });
    };

    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };

    const remeasure = () => {
      measure();
      schedule();
    };

    scrollTo.current = (index) => {
      release();
      const item = items[index];
      if (!item || !centers.length) return;
      const target = window.scrollY + list.getBoundingClientRect().top + centers[index] - focus();
      locked = true;
      const done = () => {
        release();
        schedule();
      };
      const timer = window.setTimeout(done, LOCK_MS);
      const cancel = ['wheel', 'touchstart', 'keydown'] as const;
      window.addEventListener('scrollend', done, { once: true });
      cancel.forEach((name) => window.addEventListener(name, done, { once: true, passive: true }));
      release = () => {
        locked = false;
        window.clearTimeout(timer);
        window.removeEventListener('scrollend', done);
        cancel.forEach((name) => window.removeEventListener(name, done));
        release = () => {};
      };
      window.scrollTo({ top: Math.max(0, target), behavior: reduced ? 'auto' : 'smooth' });
    };

    const resize = new ResizeObserver(remeasure);
    resize.observe(list);
    resize.observe(stage);
    wide.addEventListener('change', remeasure);
    window.addEventListener('resize', remeasure);
    window.addEventListener('scroll', schedule, { passive: true });
    document.fonts?.ready.then(remeasure);
    remeasure();

    return () => {
      if (frame) cancelAnimationFrame(frame);
      release();
      resize.disconnect();
      wide.removeEventListener('change', remeasure);
      window.removeEventListener('resize', remeasure);
      window.removeEventListener('scroll', schedule);
      scrollTo.current = () => {};
      wall.style.removeProperty('--desk-p');
      inner.style.removeProperty('--desk-p');
      items.forEach((item) => item.style.removeProperty('--step-p'));
    };
  }, [root, reduced, current, onStep]);

  return useCallback((index: number) => scrollTo.current(index), []);
}
