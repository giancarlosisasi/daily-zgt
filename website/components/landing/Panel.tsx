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
import { useGuideHref } from './i18n';
import {
  LEVEL_BARS,
  LEVEL_LABEL,
  NOW,
  countDone,
  countOpen,
  dueLabel,
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
  return (
    <span className={`dz-bars dz-bars--${level}`} aria-label={LEVEL_LABEL[level]} role="img">
      {[0, 1, 2].map((index) => (
        <i key={index} className={index < filled ? 'is-on' : ''} />
      ))}
    </span>
  );
}

export function DueChip({ due }: { due: number }) {
  const { text, tone } = dueLabel(due);
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
  const hint =
    openSubtasks === 1
      ? 'Queda 1 subtarea abierta.'
      : openSubtasks > 1
        ? `Quedan ${openSubtasks} subtareas abiertas.`
        : null;
  return (
    <div className="dz-confirm" role="group" aria-label="¿Marcar como hecha?">
      <div className="dz-confirm-text">
        <span className="dz-confirm-title">¿Marcar como hecha?</span>
        {hint ? <span className="dz-confirm-hint">{hint}</span> : null}
      </div>
      <button type="button" className="dz-btn dz-btn--ghost" onClick={onCancel}>
        Cancelar
      </button>
      <button type="button" className="dz-btn dz-btn--done" data-reel="confirm-yes" onClick={onConfirm}>
        Hecha
      </button>
    </div>
  );
}

export function UndoBar({ title, onUndo }: { title: string; onUndo: () => void }) {
  return (
    <div className="dz-undo" role="status">
      <CheckIcon size={12} className="dz-done-check" />
      <span className="dz-undo-text">Hecha: {title}</span>
      <button type="button" className="dz-undo-btn" data-reel="undo" onClick={onUndo}>
        Deshacer
      </button>
      <i className="dz-undo-line" />
    </div>
  );
}

function Row({ item }: { item: Priority }) {
  const { state, dispatch } = useDemo();
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
            aria-label={expanded ? 'Ocultar subtareas' : 'Mostrar subtareas'}
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
          label={`Marcar como hecha: ${item.title}`}
          reel={`check-${item.id}`}
          onClick={() => dispatch({ type: 'ask', id: item.id })}
        />
        <div className="dz-row-main">
          <span className="dz-row-title">{item.title}</span>
          <span className="dz-meta">
            <LevelBars level={item.level} />
            {item.due !== null ? <DueChip due={item.due} /> : null}
            {item.list === 'today' && sinceLabel(item.since) ? (
              <span className="dz-chip dz-chip--later">{sinceLabel(item.since)}</span>
            ) : null}
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
          aria-label="Quitar"
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
        placeholder="¿Qué es prioritario?"
        aria-label="¿Qué es prioritario?"
        maxLength={80}
      />
      <div className="dz-form-row">
        <span className="dz-form-label">Prioridad</span>
        <div className="dz-segment" role="radiogroup" aria-label="Prioridad">
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
              {LEVEL_LABEL[option]}
            </button>
          ))}
        </div>
      </div>
      <div className="dz-form-row">
        <span className="dz-form-label">Fecha límite</span>
        <input
          className="dz-input dz-input--time"
          type="time"
          value={time}
          onChange={(event) => setTime(event.target.value)}
          aria-label="Fecha límite"
        />
      </div>
      {time ? (
        <div className="dz-form-hint">
          <BellIcon size={12} className="dz-ring" />
          <span>Alerta con sonido 30 min antes y al vencer</span>
        </div>
      ) : null}
      <div className="dz-form-actions">
        <button type="button" className="dz-btn dz-btn--ghost" onClick={() => dispatch({ type: 'setForm', open: false })}>
          Cancelar
        </button>
        <button type="submit" className="dz-btn dz-btn--primary">
          Añadir
        </button>
      </div>
    </form>
  );
}

function PrioView() {
  const { state, dispatch } = useDemo();
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
            <span>Todo listo en esta lista</span>
          </div>
        ) : null}
        {!hasAny ? <div className="dz-empty dz-empty--none">Nada pendiente en esta lista.</div> : null}
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
          Nueva prioridad
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
            Hechas ({done.length})
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
                    Regresar
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
  const label = state.scope === 'today' ? 'Notas de hoy' : 'Notas de la semana';
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
        placeholder="Escribe una nota"
      />
      <span className="dz-notes-hint">Se guarda al escribir.</span>
    </div>
  );
}

export function Panel() {
  const { state, dispatch } = useDemo();
  const href = useGuideHref();
  const openToday = countOpen(state.items, 'today');
  const openWeek = countOpen(state.items, 'week');
  const doneCount = countDone(state.items, state.scope);
  const total = state.items.filter((item) => item.list === state.scope).length;
  const scopeWord = state.scope === 'today' ? 'hoy' : 'esta semana';

  return (
    <div className="dz-panel" role="dialog" aria-label="Daily ZGT">
      <div className="dz-top-tabs" role="tablist">
        {(
          [
            ['prio', 'Prioridades'],
            ['notes', 'Notas'],
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
              ['today', `Hoy · ${openToday}`],
              ['week', `Semana · ${openWeek}`],
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
          {state.scope === 'today' ? 'Lunes 12 oct' : 'Semana 42 · 12–18 oct'}
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
          {doneCount} de {total} hechas {scopeWord}
        </span>
        <button
          type="button"
          className="dz-icon-btn"
          aria-label="Probar alerta"
          onClick={() => dispatch({ type: 'ping' })}
        >
          <BellIcon />
        </button>
        <Link className="dz-icon-btn" href={href('/guide/use/settings')} aria-label="Ajustes" title="Ajustes">
          <GearIcon />
        </Link>
        <button type="button" className="dz-quit" onClick={() => dispatch({ type: 'setPanel', open: false })}>
          Salir
        </button>
      </div>
    </div>
  );
}

const FINDER_MENUS = ['Finder', 'Archivo', 'Edición', 'Visualización', 'Ir', 'Ventana', 'Ayuda'];

export function MenuBarStrip() {
  const { state, dispatch } = useDemo();
  const count = countOpen(state.items, 'today');
  const title = menuBarTitle(state.items);
  return (
    <div className="dz-strip" aria-label="Barra de menús de macOS">
      <div className="dz-strip-inner">
        <span className="dz-strip-menus" aria-hidden="true">
          {FINDER_MENUS.map((menu, index) => (
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
          aria-label="Prioridades"
          aria-expanded={state.panelOpen}
          onClick={() => dispatch({ type: 'setPanel', open: !state.panelOpen })}
        >
          <TargetIcon size={16} />
          <span>{count}</span>
          {title ? <span className="dz-strip-title">{title}</span> : null}
        </button>
        <span className="dz-strip-clock">lun 12 oct 12:24</span>
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
  return (
    <div className={`dz-notification ${className}`} role="alert">
      <div className="dz-notification-head">
        <TargetIcon size={14} />
        <span>PRIORIDADES</span>
        <span className="dz-notification-when">ahora</span>
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
          Abrir
        </button>
        <button type="button" className="dz-btn dz-btn--ghost" onClick={onSnooze}>
          Posponer 15 min
        </button>
      </div>
    </div>
  );
}
