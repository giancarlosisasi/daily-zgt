import { Link } from '@rspress/core/theme';
import { Fragment, useEffect, useRef, type CSSProperties } from 'react';
import { useDemo } from './DemoContext';
import { useGuideHref, useT } from './i18n';
import { createSpring2D, useReveal } from './motion';
// The motion reel is hidden for now. Restore this import and the block below to show it again.
// import { Reel } from './reel/Reel';
import { tokenSpring } from './tokens';

const RINGS = [
  { r: 250, level: 'high', start: -62, sweep: 44 },
  { r: 450, level: 'medium', start: 196, sweep: 30 },
  { r: 650, level: 'low', start: 12, sweep: 22 },
] as const;

function Words({ text }: { text: string }) {
  return (
    <>
      {text.split(' ').map((word, index) => (
        <Fragment key={index}>
          <span className="dz-word" style={{ '--i': index } as CSSProperties}>
            {word}
          </span>{' '}
        </Fragment>
      ))}
    </>
  );
}

export function Hero() {
  const { reduced } = useDemo();
  const t = useT();
  const href = useGuideHref();
  const ref = useReveal<HTMLElement>();
  const markRef = useRef<SVGSVGElement>(null);
  const ringsRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    const hero = ref.current;
    const mark = markRef.current;
    const rings = ringsRef.current;
    if (!hero || !mark || !rings || reduced) return;
    if (!window.matchMedia('(pointer: fine)').matches) return;
    const layers = Array.from(mark.querySelectorAll<SVGGElement>('g'));
    const depth = [0.5, 1.1, 1.9];
    const spring = createSpring2D(
      (x, y) => {
        layers.forEach((layer, index) => {
          layer.setAttribute('transform', `translate(${x * depth[index]} ${y * depth[index]})`);
        });
        rings.style.transform = `translate(${-x * 9}px, ${-y * 9}px)`;
      },
      tokenSpring('momentum'),
    );
    const move = (event: PointerEvent) => {
      const box = mark.getBoundingClientRect();
      const dx = (event.clientX - (box.left + box.width / 2)) / (window.innerWidth / 2);
      const dy = (event.clientY - (box.top + box.height / 2)) / 420;
      spring.to(Math.max(-1, Math.min(1, dx)), Math.max(-1, Math.min(1, dy)));
    };
    const leave = () => spring.to(0, 0);
    hero.addEventListener('pointermove', move);
    hero.addEventListener('pointerleave', leave);
    return () => {
      hero.removeEventListener('pointermove', move);
      hero.removeEventListener('pointerleave', leave);
      spring.stop();
    };
  }, [ref, reduced]);

  return (
    <header className="dz-hero" ref={ref}>
      <svg className="dz-hero-rings" ref={ringsRef} viewBox="-700 -700 1400 1400" aria-hidden="true">
        {RINGS.map((ring) => (
          <g key={ring.r}>
            <circle className="dz-ring" r={ring.r} />
            <circle
              className={`dz-ring-arc dz-ring-arc--${ring.level}`}
              r={ring.r}
              pathLength={360}
              strokeDasharray={`${ring.sweep} 360`}
              style={{ '--start': `${ring.start}deg` } as CSSProperties}
            />
          </g>
        ))}
      </svg>
      <div className="dz-hero-copy">
        <svg className="dz-brand" ref={markRef} viewBox="0 0 24 24" role="img" aria-label="Daily ZGT">
          <g>
            <circle className="dz-brand-outer" cx="12" cy="12" r="9" pathLength={1} />
          </g>
          <g>
            <circle className="dz-brand-inner" cx="12" cy="12" r="5" pathLength={1} />
          </g>
          <g>
            <circle className="dz-brand-dot" cx="12" cy="12" r="1.2" />
          </g>
        </svg>
        <p className="dz-pill" data-reveal>
          <i />
          {t('hero.eyebrow')}
        </p>
        <h1 data-reveal>
          <Words text={t('hero.title')} />
        </h1>
        <p className="dz-lead" data-reveal>
          {t('hero.lead')}
        </p>
        <div className="dz-actions" data-reveal>
          <Link className="dz-button dz-button--accent" href={href('/guide/getting-started/introduction')}>
            {t('hero.guide')}
          </Link>
          <a className="dz-button dz-button--ghost" href="#build">
            {t('hero.build')}
          </a>
        </div>
        <ul className="dz-facts" data-reveal>
          <li>SwiftUI</li>
          <li>SQLite</li>
          <li>{t('hero.fact.dark')}</li>
          <li>{t('hero.fact.local')}</li>
        </ul>
      </div>
      {/*
      <div className="dz-hero-reel" data-reveal>
        <div className="dz-reel-head">
          <span className="dz-eyebrow">{t('reel.eyebrow')}</span>
          <span className="dz-reel-meta">30 s · 120 bpm</span>
        </div>
        <Reel />
      </div>
      */}
    </header>
  );
}
