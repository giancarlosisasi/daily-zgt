import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react';
import { useDemo } from './DemoContext';
import { Rich, useT } from './i18n';
import { useReveal } from './motion';
import { MenuBarStrip, NotificationCard, Panel } from './Panel';
import { token, tokenMs } from './tokens';
import { useDeskScroll } from './useDeskScroll';

const STEPS = ['open', 'ask', 'done', 'back', 'notes'] as const;

const RINGS = [
  { r: 250, sweep: 44, start: -62 },
  { r: 450, sweep: 30, start: 196 },
  { r: 650, sweep: 22, start: 12 },
] as const;

export function Desk() {
  const { state, dispatch, reduced } = useDemo();
  const t = useT();
  const ref = useReveal<HTMLElement>();
  const slotRef = useRef<HTMLDivElement>(null);
  const current = useRef(0);
  const [step, setStep] = useState(0);

  const select = useCallback(
    (index: number, force = false) => {
      if (current.current === index && !force) return;
      current.current = index;
      setStep(index);
      dispatch({ type: 'scene', scene: index });
    },
    [dispatch],
  );

  const scrollToStep = useDeskScroll(ref, { reduced, current, onStep: select });

  // The panel keeps its state across scenes, so the change is a short lift instead of a remount.
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (reduced) return;
    slotRef.current?.animate(
      [
        { opacity: 0.6, transform: 'translateY(8px) scale(0.985)' },
        { opacity: 1, transform: 'none' },
      ],
      { duration: tokenMs('--duration-slow'), easing: token('--ease-out') },
    );
  }, [step, reduced]);

  const pick = (index: number) => {
    select(index, true);
    scrollToStep(index);
  };

  const toast = state.toast > 0;

  return (
    <section className="dz-desk" id="panel" ref={ref}>
      <div className="dz-desk-wall" aria-hidden="true">
        <div className="dz-wall-glow" />
        <svg className="dz-wall-rings" viewBox="-700 -700 1400 1400">
          {RINGS.map((ring) => (
            <g key={ring.r}>
              <circle className="dz-wall-ring" r={ring.r} />
              <circle
                className="dz-wall-arc"
                r={ring.r}
                pathLength={360}
                strokeDasharray={`${ring.sweep} 360`}
                style={{ '--start': `${ring.start}deg` } as CSSProperties}
              />
            </g>
          ))}
        </svg>
      </div>
      <div className="dz-desk-stage">
        <MenuBarStrip />
        <div className="dz-desk-inner">
          <div className="dz-panel-slot" ref={slotRef}>
            {state.panelOpen ? <Panel /> : <p className="dz-desk-closed">{t('desk.closed')}</p>}
          </div>
          {toast ? (
            <NotificationCard
              key={state.toast}
              className="dz-toast"
              title={t('demo.notif.before')}
              body={t('demo.seed.b')}
              onOpen={() => {
                dispatch({ type: 'setPanel', open: true });
                dispatch({ type: 'clearToast', token: state.toast });
              }}
              onSnooze={() => dispatch({ type: 'clearToast', token: state.toast })}
            />
          ) : null}
        </div>
      </div>
      <div className="dz-desk-copy">
        <div className="dz-desk-head" data-reveal>
          <p className="dz-eyebrow">{t('desk.eyebrow')}</p>
          <h2>{t('desk.title')}</h2>
          <p className="dz-desk-lead">{t('desk.lead')}</p>
          <p className="dz-desk-note">{t('desk.platform')}</p>
        </div>
        <ol className="dz-desk-steps">
          {STEPS.map((name, index) => (
            <li key={name} data-step={index} className={step === index ? 'is-on' : ''}>
              <button
                type="button"
                aria-pressed={step === index}
                onClick={() => pick(index)}
              >
                <b>{index + 1}</b>
                <span className="dz-step-title">
                  <Rich text={t(`desk.${name}.title`)} />
                </span>
                <span className="dz-step-text">
                  <Rich text={t(`desk.${name}.text`)} />
                </span>
              </button>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
