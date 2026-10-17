import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useDemo } from './DemoContext';
import { BellIcon, CheckIcon } from './icons';
import { Rich, useDemoLang, useT } from './i18n';
import { springValue, useInView, useReveal } from './motion';
import { LevelBars } from './Panel';
import { levelLabel, type Level } from './model';
import { tokenSpring } from './tokens';

const TABLES = [
  { name: 'priority', columns: 12 },
  { name: 'subtask', columns: 6 },
  { name: 'note', columns: 4 },
  { name: 'alert', columns: 5 },
  { name: 'priority_event', columns: 4 },
  { name: 'app_state', columns: 2 },
];

function Count({ value, run }: { value: number; run: boolean }) {
  const { reduced } = useDemo();
  const [shown, setShown] = useState(value);
  useEffect(() => {
    if (!run || reduced || value === 0) return;
    let frame = 0;
    const start = performance.now();
    const spring = tokenSpring('default');
    const tick = (now: number) => {
      const time = (now - start) / 1000;
      const done = time >= spring.response * 2;
      setShown(done ? value : Math.round(value * Math.min(1, springValue(spring, time))));
      if (!done) frame = requestAnimationFrame(tick);
    };
    setShown(0);
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [run, reduced, value]);
  return <>{shown}</>;
}

function Tile({
  area,
  tone,
  value,
  unit,
  label,
  children,
  index,
}: {
  area: string;
  tone: string;
  value: number;
  unit?: string;
  label: string;
  children: ReactNode;
  index: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const seen = useInView(ref, { once: true, threshold: 0.35 });
  return (
    <div
      ref={ref}
      className={`dz-tile dz-tile--${area} dz-tone--${tone}${seen ? ' is-seen' : ''}`}
      style={{ '--i': index } as CSSProperties}
      data-reveal
    >
      <p className="dz-tile-num">
        <Count value={value} run={seen} />
        {unit ? <small>{unit}</small> : null}
      </p>
      <p className="dz-tile-label">{label}</p>
      <div className="dz-tile-viz">{children}</div>
    </div>
  );
}

export function Bento() {
  const t = useT();
  const lang = useDemoLang();
  const ref = useReveal<HTMLElement>();
  return (
    <section className="dz-bento" ref={ref}>
      <div className="dz-bento-head" data-reveal>
        <p className="dz-eyebrow">{t('bento.eyebrow')}</p>
        <h2>{t('bento.title')}</h2>
        <p>
          <Rich text={t('bento.lead')} />
        </p>
      </div>
      <div className="dz-bento-grid">
        <Tile area="tables" tone="yellow" value={6} label={t('bento.tables')} index={0}>
          <ul className="dz-schema">
            {TABLES.map((table) => (
              <li key={table.name}>
                <code>{table.name}</code>
                <span>{t('bento.columns', { n: table.columns })}</span>
              </li>
            ))}
          </ul>
        </Tile>
        <Tile area="levels" tone="rose" value={3} label={t('bento.levels')} index={1}>
          <div className="dz-levels">
            {(['high', 'medium', 'low'] as Level[]).map((level) => (
              <span key={level} className={`dz-level dz-level--${level}`}>
                <LevelBars level={level} />
                {levelLabel(level, lang)}
              </span>
            ))}
          </div>
        </Tile>
        <Tile area="lists" tone="plain" value={2} label={t('bento.lists')} index={2}>
          <div className="dz-scope-tabs dz-scope-tabs--mock" aria-hidden="true">
            <span className="is-on">{t('demo.scope.today')} · 4</span>
            <span>{t('demo.scope.week')} · 3</span>
          </div>
        </Tile>
        <Tile area="alerts" tone="orange" value={2} label={t('bento.alerts')} index={3}>
          <div className="dz-bells">
            <span>
              <BellIcon size={22} />
              {t('alerts.before')}
            </span>
            <span>
              <BellIcon size={22} />
              {t('alerts.atDue')}
            </span>
          </div>
        </Tile>
        <Tile area="undo" tone="blue" value={5} unit="s" label={t('bento.undo')} index={4}>
          <div className="dz-undo dz-undo--mock" aria-hidden="true">
            <CheckIcon size={12} className="dz-done-check" />
            <span className="dz-undo-text">{t('demo.undoText', { title: t('demo.seed.b') })}</span>
            <span className="dz-undo-btn">{t('demo.undo')}</span>
            <i className="dz-undo-line" />
          </div>
        </Tile>
        <Tile area="file" tone="plain" value={1} label={t('bento.file')} index={5}>
          <div className="dz-paths">
            <code className="dz-path">%LOCALAPPDATA%\DailyZGT\daily-zgt.sqlite</code>
            <code className="dz-path">~/Library/Application Support/DailyZGT/daily-zgt.sqlite</code>
          </div>
        </Tile>
        <Tile area="snooze" tone="orange" value={15} unit="min" label={t('bento.snooze')} index={6}>
          <span className="dz-fake-action" aria-hidden="true">
            {t('demo.notif.snooze')}
          </span>
        </Tile>
        <Tile area="accounts" tone="muted" value={0} label={t('bento.accounts')} index={7}>
          <p className="dz-tile-note">{t('bento.accountsNote')}</p>
        </Tile>
      </div>
    </section>
  );
}
