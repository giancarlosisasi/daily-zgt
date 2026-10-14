import { useCallback, useEffect, useRef, useState } from 'react';
import { useDemo } from './DemoContext';
import { Rich, useT } from './i18n';
import { useReveal } from './motion';
import { MenuBarStrip, NotificationCard, Panel } from './Panel';

const STEPS = ['open', 'ask', 'done', 'back', 'notes'] as const;

export function Desk() {
  const { state, dispatch, reduced } = useDemo();
  const t = useT();
  const ref = useReveal<HTMLElement>();
  const listRef = useRef<HTMLOListElement>(null);
  const current = useRef(0);
  const [step, setStep] = useState(0);

  const go = useCallback(
    (index: number) => {
      if (current.current === index) return;
      current.current = index;
      setStep(index);
      dispatch({ type: 'scene', scene: index });
    },
    [dispatch],
  );

  useEffect(() => {
    const list = listRef.current;
    if (!list) return;
    const media = window.matchMedia('(min-width: 961px)');
    let observer: IntersectionObserver | null = null;
    const setup = () => {
      observer?.disconnect();
      observer = null;
      if (!media.matches) return;
      observer = new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            if (entry.isIntersecting) go(Number((entry.target as HTMLElement).dataset.step));
          }
        },
        { rootMargin: '-49% 0px -49% 0px', threshold: 0 },
      );
      for (const item of Array.from(list.children)) observer.observe(item);
    };
    setup();
    media.addEventListener('change', setup);
    return () => {
      observer?.disconnect();
      media.removeEventListener('change', setup);
    };
  }, [go]);

  const pick = (index: number, element: HTMLElement) => {
    current.current = index;
    setStep(index);
    dispatch({ type: 'scene', scene: index });
    if (window.matchMedia('(min-width: 961px)').matches) {
      element.closest('li')?.scrollIntoView({ block: 'center', behavior: reduced ? 'auto' : 'smooth' });
    }
  };

  const toast = state.toast > 0;

  return (
    <section className="dz-desk" id="panel" ref={ref}>
      <div className="dz-desk-wall" aria-hidden="true" />
      <div className="dz-desk-stage">
        <MenuBarStrip />
        <div className="dz-desk-inner">
          <div className="dz-panel-slot">
            {state.panelOpen ? <Panel /> : <p className="dz-desk-closed">{t('desk.closed')}</p>}
          </div>
          {toast ? (
            <NotificationCard
              key={state.toast}
              className="dz-toast"
              title="Vence en 30 min"
              body="Enviar la propuesta"
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
        </div>
        <ol className="dz-desk-steps" ref={listRef}>
          {STEPS.map((name, index) => (
            <li key={name} data-step={index} className={step === index ? 'is-on' : ''}>
              <button
                type="button"
                aria-pressed={step === index}
                onClick={(event) => pick(index, event.currentTarget)}
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
