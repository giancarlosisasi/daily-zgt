import { Link } from '@rspress/core/theme';
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { Bento } from './Bento';
import { useDemo } from './DemoContext';
import { Desk } from './Desk';
import { CheckIcon, TargetIcon } from './icons';
import { Rich, useDemoLang, useGuideHref, useT } from './i18n';
import { LATEST_RELEASE, REPO } from './links';
import { useInView, useReveal } from './motion';
import { DueChip, LevelBars, NotificationCard } from './Panel';
import { NOW, dueLabel, type Level } from './model';
import { PALETTE } from './reel/timeline';
import { tokenMs } from './tokens';

function Block({
  className,
  id,
  children,
}: {
  className: string;
  id?: string;
  children: ReactNode;
}) {
  const ref = useReveal<HTMLElement>();
  return (
    <section className={className} id={id} ref={ref}>
      {children}
    </section>
  );
}

const pad = (n: number) => String(n).padStart(2, '0');
const clock = (ms: number) => {
  const date = new Date(ms);
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

function MiniRow({
  title,
  level,
  highlight,
  due,
}: {
  title: string;
  level: Level;
  highlight?: boolean;
  due?: number;
}) {
  return (
    <div className={`dz-row${highlight ? ' is-highlight' : ''}`}>
      <div className="dz-row-line">
        <span className="dz-caret dz-caret--empty" />
        <span className="dz-checkbox" />
        <div className="dz-row-main">
          <span className="dz-row-title">{title}</span>
          <span className="dz-meta">
            <LevelBars level={level} />
            {due !== undefined ? <DueChip due={due} /> : null}
          </span>
        </div>
      </div>
    </div>
  );
}

const PRESETS = [-45, 36, 216];

function DueSection() {
  const t = useT();
  const lang = useDemoLang();
  const [minutes, setMinutes] = useState(36);
  const due = NOW + minutes * 60000;
  const { text, tone } = dueLabel(due, NOW, lang);
  return (
    <Block className={`dz-band dz-due dz-due--${tone}`}>
      <div className="dz-band-inner dz-due-inner">
        <p className="dz-eyebrow" data-reveal>
          {t('due.eyebrow')}
        </p>
        <h2 data-reveal>{t('due.title')}</h2>
        <div className="dz-due-giant" aria-live="polite" data-reveal>
          <span key={tone} className={`dz-chip dz-chip--${tone}`}>
            {text}
          </span>
        </div>
        <div className="dz-due-control" data-reveal>
          <div className="dz-slider">
            <label htmlFor="dz-due-slider">
              {t('due.label')} <b>{clock(due)}</b>
              <span>
                {t('due.now')} {clock(NOW)}
              </span>
            </label>
            <input
              id="dz-due-slider"
              type="range"
              min={-60}
              max={600}
              step={1}
              value={minutes}
              onChange={(event) => setMinutes(Number(event.target.value))}
            />
            <p className="dz-slider-out">
              {minutes < 0 ? t('due.past', { n: -minutes }) : t('due.left', { n: minutes })}
            </p>
          </div>
          <div className="dz-due-real">
            <div className="dz-panel dz-panel--static dz-panel--tight">
              <MiniRow title={t('demo.seed.b')} level="high" due={due} />
            </div>
            <span>{t('due.real')}</span>
          </div>
        </div>
        <dl className="dz-rules" data-reveal>
          {PRESETS.map((preset, index) => {
            const label = dueLabel(NOW + preset * 60000, NOW, lang);
            return (
              <div key={preset} className={label.tone === tone ? 'is-on' : ''}>
                <dt>
                  <button type="button" onClick={() => setMinutes(preset)}>
                    <span className={`dz-chip dz-chip--${label.tone}`}>{label.text}</span>
                  </button>
                </dt>
                <dd>{t(`due.rule${index + 1}`)}</dd>
              </div>
            );
          })}
        </dl>
        <p className="dz-due-sort" data-reveal>
          {t('due.p3')}
        </p>
      </div>
    </Block>
  );
}

type AlertKind = 'before' | 'due' | 'snooze';
const DUE_AT = NOW + 36 * 60000;
const START = -35;
const END = 24;

function AlertsSection() {
  const { reduced } = useDemo();
  const t = useT();
  const lang = useDemoLang();
  const ref = useRef<HTMLDivElement>(null);
  const visible = useInView(ref);
  const [minute, setMinute] = useState(-30);
  const [snoozeAt, setSnoozeAt] = useState<number | null>(null);
  const [dismissed, setDismissed] = useState<AlertKind | null>(null);
  const [opened, setOpened] = useState(0);

  useEffect(() => {
    if (!visible || reduced || minute >= END) return;
    const timer = setTimeout(() => setMinute((current) => current + 1), 130);
    return () => clearTimeout(timer);
  }, [visible, reduced, minute]);

  useEffect(() => {
    if (!opened) return;
    const timer = setTimeout(() => setOpened(0), tokenMs('--duration-highlight'));
    return () => clearTimeout(timer);
  }, [opened]);

  const kind: AlertKind | null =
    snoozeAt !== null ? (minute >= snoozeAt ? 'snooze' : null) : minute >= 0 ? 'due' : minute >= -30 ? 'before' : null;
  const shown = kind && kind !== dismissed ? kind : null;
  const now = DUE_AT + minute * 60000;

  const replay = () => {
    setMinute(START);
    setSnoozeAt(null);
    setDismissed(null);
  };

  const percent = (value: number) => ((value - START) / (END - START)) * 100;
  const statusOf = (target: number) => (minute >= target ? 'delivered' : 'scheduled');

  return (
    <Block className="dz-alerts">
      <div className="dz-section-head" data-reveal>
        <p className="dz-eyebrow">{t('alerts.eyebrow')}</p>
        <h2>{t('alerts.title')}</h2>
        <p>{t('alerts.p1')}</p>
      </div>
      <div className="dz-deck" ref={ref} data-reveal>
        <div className="dz-timeline" aria-hidden="true">
          <div className="dz-timeline-track">
            <i className="dz-timeline-fill" style={{ width: `${percent(minute)}%` }} />
            <span className={`dz-mark${minute >= -30 ? ' is-hit' : ''}`} style={{ left: `${percent(-30)}%` }}>
              <em>
                <b>{clock(DUE_AT - 30 * 60000)}</b>
                {t('alerts.before')}
              </em>
            </span>
            <span className={`dz-mark dz-mark--due${minute >= 0 ? ' is-hit' : ''}`} style={{ left: `${percent(0)}%` }}>
              <em>
                <b>{clock(DUE_AT)}</b>
                {t('alerts.atDue')}
              </em>
            </span>
            {snoozeAt !== null ? (
              <span
                className={`dz-mark dz-mark--snooze${minute >= snoozeAt ? ' is-hit' : ''}`}
                style={{ left: `${percent(snoozeAt)}%` }}
              >
                <em>
                  <b>{clock(DUE_AT + snoozeAt * 60000)}</b>
                  {t('demo.snoozeMark')}
                </em>
              </span>
            ) : null}
          </div>
        </div>
        <div className="dz-deck-grid">
          <div className="dz-deck-cell">
            <div className="dz-panel dz-panel--static dz-panel--tight">
              <MiniRow title={t('demo.seed.b')} level="high" due={DUE_AT} highlight={opened > 0} />
            </div>
            <p className="dz-clock">{t('alerts.clock', { time: clock(now), chip: dueLabel(DUE_AT, now, lang).text })}</p>
          </div>
          <div className="dz-deck-cell">
            <div className="dz-toast-slot">
              {shown ? (
                <NotificationCard
                  key={shown}
                  title={shown === 'before' ? t('demo.notif.before') : t('demo.notif.due')}
                  body={t('demo.seed.b')}
                  onOpen={() => {
                    setOpened(1);
                    setDismissed(shown);
                  }}
                  onSnooze={() => {
                    setSnoozeAt(minute + 15);
                    setDismissed(shown);
                  }}
                />
              ) : (
                <p className="dz-toast-empty">{t('alerts.none')}</p>
              )}
            </div>
            <p className="dz-deck-note">
              <Rich text={t('alerts.p2')} />
            </p>
          </div>
          <div className="dz-deck-cell">
            <table className="dz-table">
              <caption>{t('alerts.table')}</caption>
              <thead>
                <tr>
                  <th>kind</th>
                  <th>fire_at</th>
                  <th>status</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>before_30m</td>
                  <td>{clock(DUE_AT - 30 * 60000)}</td>
                  <td className={`dz-status dz-status--${statusOf(-30)}`}>{statusOf(-30)}</td>
                </tr>
                <tr>
                  <td>at_due</td>
                  <td>{clock(DUE_AT)}</td>
                  <td className={`dz-status dz-status--${snoozeAt !== null ? 'snoozed' : statusOf(0)}`}>
                    {snoozeAt !== null ? 'snoozed' : statusOf(0)}
                  </td>
                </tr>
                {snoozeAt !== null ? (
                  <tr>
                    <td>snooze</td>
                    <td>{clock(DUE_AT + snoozeAt * 60000)}</td>
                    <td className={`dz-status dz-status--${statusOf(snoozeAt)}`}>{statusOf(snoozeAt)}</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
            <p className="dz-deck-note">
              <Rich text={t('alerts.p3')} />
            </p>
          </div>
        </div>
        <button type="button" className="dz-link-button" onClick={replay}>
          {t('alerts.replay')}
        </button>
      </div>
    </Block>
  );
}

function NotesSection() {
  const { state, dispatch } = useDemo();
  const t = useT();
  const rows = [
    { scope: 'day', period: '2026-10-12', text: state.notes.today, key: 'today' as const },
    { scope: 'week', period: '2026-W42', text: state.notes.week, key: 'week' as const },
  ];
  return (
    <Block className="dz-split dz-notes-section">
      <div className="dz-split-copy" data-reveal>
        <p className="dz-eyebrow">{t('notes.eyebrow')}</p>
        <h2>{t('notes.title')}</h2>
        <p>{t('notes.p1')}</p>
        <p>
          <Rich text={t('notes.p2')} />
        </p>
      </div>
      <div className="dz-split-demo" data-reveal>
        <div className="dz-notes-pair">
          {rows.map((row) => (
            <div key={row.key} className="dz-panel dz-panel--static dz-panel--tight">
              <label className="dz-notes-label" htmlFor={`dz-note-${row.key}`}>
                {row.key === 'today' ? t('demo.notes.today') : t('demo.notes.week')}
              </label>
              <textarea
                id={`dz-note-${row.key}`}
                className="dz-textarea dz-textarea--short"
                value={row.text}
                placeholder={t('demo.notes.placeholder')}
                onChange={(event) => dispatch({ type: 'setNote', scope: row.key, text: event.target.value })}
              />
              <span className="dz-notes-hint">{t('demo.notes.hint')}</span>
            </div>
          ))}
        </div>
        <div className="dz-sqlrows">
          <table className="dz-table">
            <caption>select scope, period, body from note</caption>
            <thead>
              <tr>
                <th>scope</th>
                <th>period</th>
                <th>body</th>
              </tr>
            </thead>
            <tbody>
              {rows
                .filter((row) => row.text.length > 0)
                .map((row) => (
                  <tr key={`${row.key}-${row.text}`}>
                    <td>{row.scope}</td>
                    <td>{row.period}</td>
                    <td className="dz-cell-body">{row.text}</td>
                  </tr>
                ))}
              {rows.every((row) => row.text.length === 0) ? (
                <tr>
                  <td colSpan={3} className="dz-cell-empty">
                    {t('notes.empty')}
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </div>
    </Block>
  );
}

const DB_PATH = '"$HOME/Library/Application Support/DailyZGT/daily-zgt.sqlite"';
const TABLES_COMMAND = `sqlite3 ${DB_PATH} ".tables"`;
const TABLES_OUTPUT = [
  'alert            grdb_migrations  priority         subtask',
  'app_state        note             priority_event',
].join('\n');
const QUERY_COMMAND = `sqlite3 ${DB_PATH} "select title, level, list, done_at from priority"`;

function SqliteSection() {
  const { state, reduced } = useDemo();
  const t = useT();
  const ref = useRef<HTMLDivElement>(null);
  const visible = useInView(ref, { once: true, threshold: 0.35 });
  const total = TABLES_COMMAND.length + QUERY_COMMAND.length;
  const [typed, setTyped] = useState(total);
  const [started, setStarted] = useState(false);

  useEffect(() => {
    if (!visible || reduced || started) return;
    setStarted(true);
    setTyped(0);
  }, [visible, reduced, started]);

  useEffect(() => {
    if (!started || reduced || typed >= total) return;
    const delay = typed === 0 ? 350 : typed === TABLES_COMMAND.length ? 700 : 11;
    const timer = setTimeout(() => setTyped((current) => current + 1), delay);
    return () => clearTimeout(timer);
  }, [started, reduced, typed, total]);

  const progress = reduced ? total : typed;
  const first = TABLES_COMMAND.slice(0, progress);
  const firstDone = progress >= TABLES_COMMAND.length;
  const second = QUERY_COMMAND.slice(0, Math.max(0, progress - TABLES_COMMAND.length));
  const secondDone = progress >= total;
  const lines = state.items.map(
    (item) => `${item.title}|${item.level}|${item.list}|${item.doneAt !== null ? '2026-10-12T12:24:00' : ''}`,
  );

  return (
    <Block className="dz-band dz-sql">
      <div className="dz-band-inner dz-sql-inner">
        <div className="dz-terminal" ref={ref} data-reveal>
          <div className="dz-terminal-bar" aria-hidden="true">
            <i />
            <i />
            <i />
            <span>Terminal — zsh</span>
          </div>
          <pre className="dz-terminal-body">
            <span className="dz-prompt">$ </span>
            {first}
            {!firstDone ? <span className="dz-caret-block" /> : null}
            {firstDone ? <span className="dz-out">{`\n${TABLES_OUTPUT}\n`}</span> : null}
            {firstDone ? (
              <>
                <span className="dz-prompt">$ </span>
                {second}
                {!secondDone ? <span className="dz-caret-block" /> : null}
              </>
            ) : null}
            {secondDone ? <span className="dz-out">{`\n${lines.join('\n')}\n`}</span> : null}
            {secondDone ? (
              <>
                <span className="dz-prompt">$ </span>
                <span className="dz-caret-block" />
              </>
            ) : null}
          </pre>
        </div>
        <div className="dz-split-copy" data-reveal>
          <p className="dz-eyebrow">{t('sqlite.eyebrow')}</p>
          <h2>{t('sqlite.title')}</h2>
          <p>
            <Rich text={t('sqlite.p1')} />
          </p>
          <p>{t('sqlite.p2')}</p>
          <p>
            <Rich text={t('sqlite.p3')} />
          </p>
        </div>
      </div>
    </Block>
  );
}

const SHORTCUTS = [
  { platform: 'Windows', label: 'shortcut.keys.win', keys: ['Ctrl', 'Alt', 'Shift', 'P'] },
  { platform: 'macOS', label: 'shortcut.keys.mac', keys: ['⌃', '⌥', '⌘', 'P'] },
];

const isShortcut = (event: KeyboardEvent) =>
  event.code === 'KeyP' && event.ctrlKey && event.altKey && (event.metaKey || event.shiftKey);

function ShortcutSection() {
  const { state, dispatch } = useDemo();
  const t = useT();
  const [open, setOpen] = useState(true);
  const [title, setTitle] = useState('');
  const [added, setAdded] = useState<string | null>(null);
  const [pressed, setPressed] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const byUser = useRef(false);

  const show = () => {
    byUser.current = true;
    setPressed((current) => current + 1);
    setOpen(true);
    inputRef.current?.focus({ preventScroll: true });
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (isShortcut(event)) {
        event.preventDefault();
        byUser.current = true;
        setPressed((current) => current + 1);
        setOpen(true);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => {
    if (open && byUser.current) inputRef.current?.focus({ preventScroll: true });
  }, [open, pressed]);

  const submit = () => {
    const clean = title.trim();
    if (!clean) return;
    dispatch({ type: 'add', title: clean, level: 'medium', list: 'today', due: null });
    setAdded(clean);
    setTitle('');
    setOpen(false);
  };

  const todayOpen = state.items.filter((item) => item.list === 'today' && item.doneAt === null).length;

  return (
    <Block className="dz-shortcut">
      <p className="dz-eyebrow" data-reveal>
        {t('shortcut.eyebrow')}
      </p>
      <h2 data-reveal>{t('shortcut.title')}</h2>
      <div className="dz-keysets">
        {SHORTCUTS.map((shortcut) => (
          <div key={shortcut.platform} className="dz-keyset">
            <span className="dz-keyset-label">{shortcut.platform}</span>
            <div className="dz-keys" aria-label={t(shortcut.label)} data-reveal>
              {shortcut.keys.map((key, index) => (
                <kbd
                  key={`${key}-${pressed}`}
                  className={key.length > 1 ? 'dz-key-word' : undefined}
                  style={{ '--i': index } as CSSProperties}
                >
                  {key}
                </kbd>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div className="dz-capture-slot" data-reveal>
        {open ? (
          <div className="dz-capture" role="group" aria-label={t('demo.quickCapture')}>
            <input
              ref={inputRef}
              className="dz-input"
              value={title}
              placeholder={t('demo.form.placeholder')}
              aria-label={t('demo.form.placeholder')}
              onChange={(event) => setTitle(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter') submit();
                if (event.key === 'Escape') setOpen(false);
              }}
            />
            <span>{t('shortcut.hint')}</span>
          </div>
        ) : (
          <button type="button" className="dz-button dz-button--ghost dz-button--small" onClick={show}>
            {t('shortcut.button')}
          </button>
        )}
      </div>
      <p className="dz-capture-result" aria-live="polite" data-reveal>
        <TargetIcon size={14} /> {t('shortcut.count', { n: todayOpen })}
        {added ? (
          <>
            {' '}
            {t('shortcut.added', { title: `“${added}”` })} <LevelBars level="medium" />
          </>
        ) : null}
      </p>
      <div className="dz-shortcut-copy" data-reveal>
        <p>
          <Rich text={t('shortcut.p1')} />
        </p>
        <p>{t('shortcut.p2')}</p>
        <p>
          <Rich text={t('shortcut.p3')} />
        </p>
      </div>
    </Block>
  );
}

function LocalSection() {
  const t = useT();
  const href = useGuideHref();
  return (
    <Block className="dz-split dz-split--flip dz-local-section">
      <div className="dz-split-copy" data-reveal>
        <p className="dz-eyebrow">{t('local.eyebrow')}</p>
        <h2>{t('local.title')}</h2>
        <p>{t('local.p1')}</p>
        <p>{t('local.p2')}</p>
        <p>{t('local.p3')}</p>
        <div className="dz-actions">
          <Link className="dz-button dz-button--ghost dz-button--small" href={href('/guide/help/privacy')}>
            {t('local.privacy')}
          </Link>
          <a className="dz-button dz-button--ghost dz-button--small" href={REPO}>
            {t('local.repo')}
          </a>
        </div>
      </div>
      <div className="dz-split-demo dz-local" data-reveal>
        <div className="dz-local-mac">
          <span className="dz-local-label">{t('local.device')}</span>
          <div className="dz-local-flow">
            <div className="dz-local-box">
              <TargetIcon size={20} />
              <b>Daily ZGT</b>
              <span>{t('local.appKind')}</span>
            </div>
            <div className="dz-beam" aria-hidden="true">
              <i />
            </div>
            <div className="dz-local-box dz-local-box--file">
              <CheckIcon size={16} className="dz-done-check" />
              <b>daily-zgt.sqlite</b>
              <span>{t('local.fileKind')}</span>
            </div>
          </div>
        </div>
        <div className="dz-local-none">
          <div>
            <s>{t('local.account')}</s>
            <span>{t('local.none')}</span>
          </div>
          <div>
            <s>{t('local.server')}</s>
            <span>{t('local.none')}</span>
          </div>
          <div>
            <s>{t('local.telemetry')}</s>
            <span>{t('local.none')}</span>
          </div>
        </div>
      </div>
    </Block>
  );
}

const COMMANDS = [
  { label: 'build.cmd1', code: 'git clone https://github.com/giancarlosisasi/daily-zgt.git' },
  { label: 'build.cmd2', code: 'cd daily-zgt && ./apps/macos/scripts/install.sh' },
  { label: 'build.cmd3', code: 'open /Applications/DailyZGT.app' },
];

function CopyCommand({ label, code, index }: { label: string; code: string; index: number }) {
  const t = useT();
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      setCopied(false);
    }
  };
  return (
    <div className="dz-command" data-reveal style={{ '--i': index } as CSSProperties}>
      <b className="dz-command-num">{index + 1}</b>
      <div className="dz-command-main">
        <span className="dz-command-label">{t(label)}</span>
        <div className="dz-command-line">
          <code>{code}</code>
          <button type="button" onClick={copy}>
            {copied ? t('build.copied') : t('build.copy')}
          </button>
        </div>
      </div>
    </div>
  );
}

function DownloadSection() {
  const t = useT();
  const href = useGuideHref();
  return (
    <Block className="dz-build" id="download">
      <div className="dz-section-head dz-section-head--center" data-reveal>
        <p className="dz-eyebrow">{t('build.eyebrow')}</p>
        <h2>{t('build.title')}</h2>
        <p>{t('build.lead')}</p>
      </div>
      <div className="dz-platform" data-reveal>
        <h3>Windows</h3>
        <p className="dz-platform-req">{t('build.win.req')}</p>
        <p>{t('build.win.p1')}</p>
        <p>
          <Rich text={t('build.win.smartscreen')} />
        </p>
        <p>{t('build.win.lang')}</p>
        <div className="dz-actions">
          <a className="dz-button dz-button--accent" href={LATEST_RELEASE}>
            {t('hero.download')}
          </a>
        </div>
      </div>
      <div className="dz-platform" id="build" data-reveal>
        <h3>macOS</h3>
        <p className="dz-platform-req">{t('build.mac.req')}</p>
        <p>{t('build.mac.p1')}</p>
        <div className="dz-commands">
          {COMMANDS.map((command, index) => (
            <CopyCommand key={command.label} {...command} index={index} />
          ))}
        </div>
        <p>{t('build.mac.lang')}</p>
      </div>
      <div className="dz-actions dz-actions--center" data-reveal>
        <Link className="dz-button dz-button--primary" href={href('/guide/getting-started/download')}>
          {t('build.guide')}
        </Link>
      </div>
      <div className="dz-lockup" data-reveal>
        <TargetIcon size={44} />
        <div>
          <strong>Daily ZGT</strong>
          <i className="dz-lockup-line" aria-hidden="true">
            {PALETTE.map((item) => (
              <b key={item.token} style={{ background: `var(${item.token})` }} />
            ))}
          </i>
          <span>{t('hero.eyebrow')}</span>
        </div>
      </div>
    </Block>
  );
}

export function Sections() {
  return (
    <>
      <Desk />
      <Bento />
      <DueSection />
      <AlertsSection />
      <NotesSection />
      <SqliteSection />
      <ShortcutSection />
      <LocalSection />
      <DownloadSection />
    </>
  );
}
