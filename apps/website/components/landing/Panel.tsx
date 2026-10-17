import { Link } from '@rspress/core/theme';
import { useEffect, useRef, useState, type KeyboardEvent, type SubmitEvent } from 'react';
import { useDemo } from './DemoContext';
import {
  ArrowBackIcon,
  BellIcon,
  BigCheckIcon,
  CaretIcon,
  CheckIcon,
  GearIcon,
  NoteIcon,
  PlusIcon,
  TargetIcon,
  TrashIcon,
  WifiIcon,
} from './icons';
import { useDemoLang, useGuideHref, useT } from './i18n';
import {
  LEVEL_BARS,
  NOW,
  countDone,
  countOpen,
  dueLabel,
  levelLabel,
  menuBarTitle,
  sinceLabel,
  sortDone,
  sortOpen,
  type Level,
  type ListName,
  type Priority,
} from './model';

export function LevelBars({ level }: { level: Level }) {
  const filled = LEVEL_BARS[level];
  const lang = useDemoLang();
  return (
    <span className={`dz-bars dz-bars--${level}`} aria-label={levelLabel(level, lang)} role="img">
      {[0, 1, 2].map((index) => (
        <i key={index} className={index < filled ? 'is-on' : ''} />
      ))}
    </span>
  );
}

export function DueChip({ due }: { due: number }) {
  const lang = useDemoLang();
  const { text, tone } = dueLabel(due, NOW, lang);
  return <span className={`dz-chip dz-chip--${tone}`}>{text}</span>;
}

function Checkbox({
  checked,
  small,
  label,
  onClick,
  reel,
}: {
  checked: boolean;
  small?: boolean;
  label: string;
  onClick: () => void;
  reel?: string;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label}
      data-reel={reel}
      className={`dz-checkbox${small ? ' dz-checkbox--small' : ''}${checked ? ' is-checked' : ''}`}
      onClick={onClick}
    >
      {checked ? <CheckIcon size={small ? 9 : 10} /> : null}
    </button>
  );
}

export function ConfirmBar({
  openSubtasks,
  onCancel,
  onConfirm,
}: {
  openSubtasks: number;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const t = useT();
  const hint =
    openSubtasks === 1
      ? t('demo.confirm.one')
      : openSubtasks > 1
        ? t('demo.confirm.many', { n: openSubtasks })
        : null;
  return (
    <div className="dz-confirm" role="group" aria-label={t('demo.confirm.title')}>
      <div className="dz-confirm-text">
        <span className="dz-confirm-title">{t('demo.confirm.title')}</span>
        {hint ? <span className="dz-confirm-hint">{hint}</span> : null}
      </div>
      <button type="button" className="dz-btn dz-btn--ghost" onClick={onCancel}>
        {t('demo.cancel')}
      </button>
      <button type="button" className="dz-btn dz-btn--done" data-reel="confirm-yes" onClick={onConfirm}>
        {t('demo.done')}
      </button>
    </div>
  );
}

export function UndoBar({ title, onUndo }: { title: string; onUndo: () => void }) {
  const t = useT();
  return (
    <div className="dz-undo" role="status">
      <CheckIcon size={12} className="dz-done-check" />
      <span className="dz-undo-text">{t('demo.undoText', { title })}</span>
      <button type="button" className="dz-undo-btn" data-reel="undo" onClick={onUndo}>
        {t('demo.undo')}
      </button>
      <i className="dz-undo-line" />
    </div>
  );
}

function Row({ item }: { item: Priority }) {
  const { state, dispatch } = useDemo();
  const t = useT();
  const lang = useDemoLang();
  const since = item.list === 'today' ? sinceLabel(item.since, lang) : null;
  const expanded = state.expanded.includes(item.id);
  const confirming = state.confirming === item.id;
  const leaving = state.leaving === item.id;
  const highlighted = state.highlight === item.id;
  const done = item.subtasks.filter((sub) => sub.done).length;
  const openSubtasks = item.subtasks.length - done;

  return (
    <div
      className={`dz-row${leaving ? ' is-leaving' : ''}${highlighted ? ' is-highlight' : ''}`}
      data-row={item.id}
    >
      <div className="dz-row-line">
        {item.subtasks.length > 0 ? (
          <button
            type="button"
            className={`dz-caret${expanded ? ' is-open' : ''}`}
            aria-label={expanded ? t('demo.hideSubtasks') : t('demo.showSubtasks')}
            aria-expanded={expanded}
            onClick={() => dispatch({ type: 'toggleCaret', id: item.id })}
          >
            <CaretIcon />
          </button>
        ) : (
          <span className="dz-caret dz-caret--empty" />
        )}
        <Checkbox
          checked={confirming}
          label={t('demo.markDone', { title: item.title })}
          reel={`check-${item.id}`}
          onClick={() => dispatch({ type: 'ask', id: item.id })}
        />
        <div className="dz-row-main">
          <span className="dz-row-title">{item.title}</span>
          <span className="dz-meta">
            <LevelBars level={item.level} />
            {item.due !== null ? <DueChip due={item.due} /> : null}
            {since ? <span className="dz-chip dz-chip--later">{since}</span> : null}
            {item.subtasks.length > 0 ? (
              <span className="dz-progress">
                {done}/{item.subtasks.length}
              </span>
            ) : null}
            {item.hasNote ? <NoteIcon /> : null}
          </span>
        </div>
        <button
          type="button"
          className="dz-remove"
          aria-label={t('demo.remove')}
          onClick={() => dispatch({ type: 'remove', id: item.id })}
        >
          <TrashIcon />
        </button>
      </div>
      {confirming ? (
        <ConfirmBar
          openSubtasks={openSubtasks}
          onCancel={() => dispatch({ type: 'cancel' })}
          onConfirm={() => dispatch({ type: 'confirm', id: item.id })}
        />
      ) : null}
      {expanded ? (
        <div className="dz-subtasks">
          {item.subtasks.map((sub) => (
            <div key={sub.id} className={`dz-subtask${sub.done ? ' is-done' : ''}`}>
              <Checkbox
                small
                checked={sub.done}
                label={sub.title}
                onClick={() => dispatch({ type: 'toggleSub', id: item.id, subId: sub.id })}
              />
              <span>{sub.title}</span>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function NewPriorityForm({ list }: { list: ListName }) {
  const { dispatch } = useDemo();
  const t = useT();
  const lang = useDemoLang();
  const [title, setTitle] = useState('');
  const [level, setLevel] = useState<Level>('medium');
  const [time, setTime] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus({ preventScroll: true });
  }, []);

  const submit = (event?: SubmitEvent) => {
    event?.preventDefault();
    const clean = title.trim();
    if (!clean) return;
    let due: number | null = null;
    if (time) {
      const [hours, minutes] = time.split(':').map(Number);
      const base = new Date(NOW);
      due = new Date(base.getFullYear(), base.getMonth(), base.getDate(), hours, minutes).getTime();
    }
    dispatch({ type: 'add', title: clean, level, list, due });
  };

  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') dispatch({ type: 'setForm', open: false });
  };

  return (
    <form className="dz-form" onSubmit={submit} onKeyDown={onKeyDown}>
      <input
        ref={inputRef}
        className="dz-input"
        value={title}
        onChange={(event) => setTitle(event.target.value)}
        placeholder={t('demo.form.placeholder')}
        aria-label={t('demo.form.placeholder')}
        maxLength={80}
      />
      <div className="dz-form-row">
        <span className="dz-form-label">{t('demo.form.priority')}</span>
        <div className="dz-segment" role="radiogroup" aria-label={t('demo.form.priority')}>
          {(['high', 'medium', 'low'] as Level[]).map((option) => (
            <button
              key={option}
              type="button"
              role="radio"
              aria-checked={level === option}
              className={level === option ? 'is-on' : ''}
              onClick={() => setLevel(option)}
            >
              <LevelBars level={option} />
              {levelLabel(option, lang)}
            </button>
          ))}
        </div>
      </div>
      <div className="dz-form-row">
        <span className="dz-form-label">{t('demo.form.due')}</span>
        <input
          className="dz-input dz-input--time"
          type="time"
          value={time}
          onChange={(event) => setTime(event.target.value)}
          aria-label={t('demo.form.due')}
        />
      </div>
      {time ? (
        <div className="dz-form-hint">
          <BellIcon size={12} className="dz-ring" />
          <span>{t('demo.form.alert')}</span>
        </div>
      ) : null}
      <div className="dz-form-actions">
        <button type="button" className="dz-btn dz-btn--ghost" onClick={() => dispatch({ type: 'setForm', open: false })}>
          {t('demo.cancel')}
        </button>
        <button type="submit" className="dz-btn dz-btn--primary">
          {t('demo.form.add')}
        </button>
      </div>
    </form>
  );
}

function PrioView() {
  const { state, dispatch } = useDemo();
  const t = useT();
  const open = sortOpen(state.items.filter((item) => item.list === state.scope));
  const done = sortDone(state.items.filter((item) => item.list === state.scope));
  const hasAny = state.items.some((item) => item.list === state.scope);

  return (
    <>
      <div className="dz-list" key={state.scope}>
        {open.map((item) => (
          <Row key={item.id} item={item} />
        ))}
        {open.length === 0 && hasAny ? (
          <div className="dz-empty">
            <BigCheckIcon />
            <span>{t('demo.empty.done')}</span>
          </div>
        ) : null}
        {!hasAny ? <div className="dz-empty dz-empty--none">{t('demo.empty.none')}</div> : null}
      </div>
      {state.formOpen ? (
        <NewPriorityForm list={state.scope} />
      ) : (
        <button
          type="button"
          className="dz-new"
          onClick={() => dispatch({ type: 'setForm', open: true })}
        >
          <PlusIcon />
          {t('demo.new')}
        </button>
      )}
      {done.length > 0 ? (
        <div className="dz-hechas">
          <button
            type="button"
            className="dz-hechas-head"
            aria-expanded={state.hechasOpen}
            onClick={() => dispatch({ type: 'toggleHechas' })}
          >
            <CaretIcon size={10} className={state.hechasOpen ? 'is-open' : ''} />
            {t('demo.completedCount', { n: done.length })}
          </button>
          {state.hechasOpen
            ? done.map((item) => (
                <div key={item.id} className="dz-done-row">
                  <CheckIcon size={12} className="dz-done-check" />
                  <span className="dz-done-title">{item.title}</span>
                  <button
                    type="button"
                    className="dz-regresar"
                    onClick={() => dispatch({ type: 'regresar', id: item.id })}
                  >
                    <ArrowBackIcon size={11} />
                    {t('demo.reopen')}
                  </button>
                </div>
              ))
            : null}
        </div>
      ) : null}
    </>
  );
}

function UndoSlot() {
  const { state, dispatch } = useDemo();
  const undoItem = state.undo ? state.items.find((item) => item.id === state.undo?.id) : null;
  if (!undoItem) return null;
  return <UndoBar title={undoItem.title} onUndo={() => dispatch({ type: 'undo' })} />;
}

function NotesView() {
  const { state, dispatch } = useDemo();
  const t = useT();
  const label = state.scope === 'today' ? t('demo.notes.today') : t('demo.notes.week');
  return (
    <div className="dz-notes">
      <label className="dz-notes-label" htmlFor="dz-hero-note">
        {label}
      </label>
      <textarea
        id="dz-hero-note"
        className="dz-textarea"
        data-reel="note-field"
        value={state.notes[state.scope]}
        onChange={(event) =>
          dispatch({ type: 'setNote', scope: state.scope, text: event.target.value })
        }
        placeholder={t('demo.notes.placeholder')}
      />
      <span className="dz-notes-hint">{t('demo.notes.hint')}</span>
    </div>
  );
}

export function Panel() {
  const { state, dispatch } = useDemo();
  const href = useGuideHref();
  const t = useT();
  const openToday = countOpen(state.items, 'today');
  const openWeek = countOpen(state.items, 'week');
  const doneCount = countDone(state.items, state.scope);
  const total = state.items.filter((item) => item.list === state.scope).length;

  return (
    <div className="dz-panel" role="dialog" aria-label="Daily ZGT">
      <div className="dz-top-tabs" role="tablist">
        {(
          [
            ['prio', t('demo.tab.prio')],
            ['notes', t('demo.tab.notes')],
          ] as const
        ).map(([tab, label]) => (
          <button
            key={tab}
            type="button"
            role="tab"
            aria-selected={state.tab === tab}
            data-reel={`tab-${tab}`}
            className={state.tab === tab ? 'is-on' : ''}
            onClick={() => dispatch({ type: 'setTab', tab })}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="dz-scope">
        <div className="dz-scope-tabs" role="tablist">
          {(
            [
              ['today', `${t('demo.scope.today')} · ${openToday}`],
              ['week', `${t('demo.scope.week')} · ${openWeek}`],
            ] as const
          ).map(([scope, label]) => (
            <button
              key={scope}
              type="button"
              role="tab"
              aria-selected={state.scope === scope}
              data-reel={`scope-${scope}`}
              className={state.scope === scope ? 'is-on' : ''}
              onClick={() => dispatch({ type: 'setScope', scope })}
            >
              {label}
            </button>
          ))}
        </div>
        <span className="dz-date">
          {state.scope === 'today' ? t('demo.date.today') : t('demo.date.week')}
        </span>
      </div>
      {state.tab === 'prio' ? (
        <>
          <PrioView />
          <UndoSlot />
        </>
      ) : (
        <>
          <UndoSlot />
          <NotesView />
        </>
      )}
      <div className="dz-footer">
        <span className="dz-footer-count">
          {t(state.scope === 'today' ? 'demo.footer.today' : 'demo.footer.week', { done: doneCount, total })}
        </span>
        <button
          type="button"
          className="dz-icon-btn"
          aria-label={t('demo.testAlert')}
          onClick={() => dispatch({ type: 'ping' })}
        >
          <BellIcon />
        </button>
        <Link className="dz-icon-btn" href={href('/guide/features/settings')} aria-label={t('demo.settings')} title={t('demo.settings')}>
          <GearIcon />
        </Link>
        <button type="button" className="dz-quit" onClick={() => dispatch({ type: 'setPanel', open: false })}>
          {t('demo.quit')}
        </button>
      </div>
    </div>
  );
}

export function MenuBarStrip() {
  const { state, dispatch } = useDemo();
  const t = useT();
  const menus = t('demo.menus').split(',');
  const count = countOpen(state.items, 'today');
  const title = menuBarTitle(state.items);
  return (
    <div className="dz-strip" aria-label={t('demo.menubar')}>
      <div className="dz-strip-inner">
        <span className="dz-strip-menus" aria-hidden="true">
          {menus.map((menu, index) => (
            <span key={menu} className={index === 0 ? 'is-app' : ''}>
              {menu}
            </span>
          ))}
        </span>
        <span className="dz-strip-spacer" />
        <WifiIcon size={14} className="dz-strip-icon" />
        <button
          type="button"
          className={`dz-strip-item${state.panelOpen ? ' is-active' : ''}`}
          data-reel="menubar"
          aria-label={t('demo.tab.prio')}
          aria-expanded={state.panelOpen}
          onClick={() => dispatch({ type: 'setPanel', open: !state.panelOpen })}
        >
          <TargetIcon size={16} />
          <span>{count}</span>
          {title ? <span className="dz-strip-title">{title}</span> : null}
        </button>
        <span className="dz-strip-clock">{t('demo.clock')}</span>
      </div>
    </div>
  );
}

export function NotificationCard({
  title,
  body,
  onOpen,
  onSnooze,
  className = '',
}: {
  title: string;
  body: string;
  onOpen?: () => void;
  onSnooze?: () => void;
  className?: string;
}) {
  const t = useT();
  return (
    <div className={`dz-notification ${className}`} role="alert">
      <div className="dz-notification-head">
        <TargetIcon size={14} />
        <span>{t('demo.notif.head')}</span>
        <span className="dz-notification-when">{t('demo.notif.now')}</span>
      </div>
      <div className="dz-notification-main">
        <BellIcon size={16} className="dz-ring" />
        <div>
          <strong>{title}</strong>
          <span className="dz-notification-body">{body}</span>
        </div>
      </div>
      <div className="dz-notification-actions">
        <button type="button" className="dz-btn dz-btn--primary" onClick={onOpen}>
          {t('demo.notif.open')}
        </button>
        <button type="button" className="dz-btn dz-btn--ghost" onClick={onSnooze}>
          {t('demo.notif.snooze')}
        </button>
      </div>
    </div>
  );
}
