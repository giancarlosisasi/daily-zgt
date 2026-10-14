import { memo, type Ref } from 'react';
import { BellIcon, CaretIcon, CheckIcon, GearIcon, NoteIcon, PlusIcon, TargetIcon, WifiIcon } from '../icons';
import { LevelBars } from '../Panel';
import type { DueTone, Level } from '../model';
import { CAPTIONS, PALETTE, STEPS, TABLE_NAMES, TILES } from './timeline';

type Translate = (key: string) => string;

function StageRow({
  title,
  level,
  chip,
  tone = 'later',
  since,
  note,
  progress,
  checkName,
}: {
  title: string;
  level: Level;
  chip?: string;
  tone?: DueTone;
  since?: string;
  note?: boolean;
  progress?: string;
  checkName?: string;
}) {
  return (
    <div className="dz-row-line">
      <span className="dz-caret dz-caret--empty" />
      <span className="dz-checkbox" data-r={checkName}>
        <CheckIcon size={10} />
      </span>
      <div className="dz-row-main">
        <span className="dz-row-title">{title}</span>
        <span className="dz-meta">
          <LevelBars level={level} />
          {chip ? <span className={`dz-chip dz-chip--${tone}`}>{chip}</span> : null}
          {since ? <span className="dz-chip dz-chip--later">{since}</span> : null}
          {progress ? <span className="dz-progress">{progress}</span> : null}
          {note ? <NoteIcon /> : null}
        </span>
      </div>
    </div>
  );
}

function ConfirmMock({ hint, yesName }: { hint?: string; yesName?: string }) {
  return (
    <div className="dz-confirm">
      <div className="dz-confirm-text">
        <span className="dz-confirm-title">¿Marcar como hecha?</span>
        {hint ? <span className="dz-confirm-hint">{hint}</span> : null}
      </div>
      <button type="button" className="dz-btn dz-btn--ghost">
        Cancelar
      </button>
      <button type="button" className="dz-btn dz-btn--done" data-r={yesName}>
        Hecha
      </button>
    </div>
  );
}

function NotificationMock({ name, title }: { name: string; title: string }) {
  return (
    <div className="rl-abs rl-note" data-r={name}>
      <div className="dz-notification">
        <div className="dz-notification-head">
          <TargetIcon size={14} />
          <span>PRIORIDADES</span>
          <span className="dz-notification-when">ahora</span>
        </div>
        <div className="dz-notification-main">
          <BellIcon size={16} data-r={`${name}Bell`} />
          <div>
            <strong>{title}</strong>
            <span className="dz-notification-body">Enviar la propuesta</span>
          </div>
        </div>
        <div className="dz-notification-actions">
          <button type="button" className="dz-btn dz-btn--primary">
            Abrir
          </button>
          <button type="button" className="dz-btn dz-btn--ghost">
            Posponer 15 min
          </button>
        </div>
      </div>
    </div>
  );
}

function Mark({ name, className }: { name: string; className: string }) {
  return (
    <svg
      className={`rl-abs ${className}`}
      data-r={name}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
    >
      <circle data-r={`${name}Outer`} cx="12" cy="12" r="9" pathLength={1} strokeDasharray="1 1" />
      <circle data-r={`${name}Inner`} cx="12" cy="12" r="5" pathLength={1} strokeDasharray="1 1" />
      <circle data-r={`${name}Dot`} cx="12" cy="12" r="1.2" fill="currentColor" />
    </svg>
  );
}

const chars = (text: string, name: string) =>
  [...text].map((char, index) => (
    <span key={index} data-r={name}>
      {char === ' ' ? ' ' : char}
    </span>
  ));

function TileViz({ kind }: { kind: (typeof TILES)[number]['viz'] }) {
  if (kind === 'tables') {
    return (
      <div className="rl-viz rl-viz--tables">
        {TABLE_NAMES.map((name) => (
          <code key={name} data-r="vizTable">
            {name}
          </code>
        ))}
      </div>
    );
  }
  if (kind === 'levels') {
    return (
      <div className="rl-viz rl-viz--levels">
        {(['high', 'medium', 'low'] as Level[]).map((level) => (
          <span key={level} data-r="vizLevel">
            <LevelBars level={level} />
          </span>
        ))}
      </div>
    );
  }
  if (kind === 'lists') {
    return (
      <div className="rl-viz rl-viz--lists">
        <div className="dz-scope-tabs">
          <button type="button" data-r="vizList">
            Hoy · 4
          </button>
          <button type="button" data-r="vizList">
            Semana · 3
          </button>
        </div>
      </div>
    );
  }
  if (kind === 'alerts') {
    return (
      <div className="rl-viz rl-viz--alerts">
        <span data-r="vizBell">
          <BellIcon size={44} />
          <em>12:30</em>
        </span>
        <span data-r="vizBell">
          <BellIcon size={44} />
          <em>13:00</em>
        </span>
      </div>
    );
  }
  if (kind === 'undo') {
    return (
      <div className="rl-viz rl-viz--undo">
        <div className="dz-undo">
          <CheckIcon size={12} className="dz-done-check" />
          <span className="dz-undo-text">Hecha: Enviar la propuesta</span>
          <button type="button" className="dz-undo-btn">
            Deshacer
          </button>
          <i className="dz-undo-line" data-r="vizUndo" />
        </div>
      </div>
    );
  }
  return (
    <div className="rl-viz rl-viz--file">
      <code data-r="vizFile">daily-zgt.sqlite</code>
      <span>~/Library/Application Support/DailyZGT/</span>
    </div>
  );
}

function StageInner({ t, rootRef }: { t: Translate; rootRef: Ref<HTMLDivElement> }) {
  return (
    <div className="dz-reel-stage" ref={rootRef} inert>
      <div className="rl-glow" data-r="glow" />
      <div className="rl-abs rl-shock" data-r="shock" />
      <Mark name="mark" className="rl-mark" />

      {PALETTE.map((item) => (
        <div
          key={item.token}
          className="rl-abs rl-bar"
          data-r="bar"
          style={{ background: `var(${item.token})`, color: `var(${item.ink})` }}
        >
          <div className="rl-hex" data-r="hexBox">
            <small>{item.role}</small>
            <span data-r="hex" />
          </div>
        </div>
      ))}

      <div className="rl-abs rl-word" data-r="word">
        {[...'Daily ZGT'].map((char, index) => (
          <span key={index} className="rl-mask">
            <span data-r="letter">{char === ' ' ? ' ' : char}</span>
          </span>
        ))}
      </div>

      <div className="rl-abs rl-cmp" data-r="cmpA">
        <span className="rl-cmp-label">{t('reel.cmp.list')}</span>
        <div className="rl-plain">
          <div className="rl-plain-row" data-r="plainRow">
            <i className="rl-plain-box" data-r="plainBox">
              <CheckIcon size={26} />
            </i>
            <span>Enviar la propuesta</span>
          </div>
          <div className="rl-plain-row">
            <i className="rl-plain-box" />
            <b style={{ width: '58%' }} />
          </div>
          <div className="rl-plain-row">
            <i className="rl-plain-box" />
            <b style={{ width: '44%' }} />
          </div>
        </div>
      </div>

      <div className="rl-abs rl-cmp" data-r="cmpB">
        <span className="rl-cmp-label">Daily ZGT</span>
        <div className="rl-cmp-panel">
          <div className="dz-panel dz-panel--static">
            <div className="dz-row">
              <StageRow
                title="Enviar la propuesta"
                level="high"
                chip="En 36 min"
                tone="soon"
                progress="1/3"
                checkName="cmpCheck"
              />
              <div className="rl-clip" data-r="cmpConfirm">
                <ConfirmMock hint="Quedan 2 subtareas abiertas." />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="rl-abs rl-strip" data-r="strip">
        <div className="dz-strip">
          <div className="dz-strip-inner">
            <span className="dz-strip-menus">
              <span className="is-app">Finder</span>
              <span>Archivo</span>
              <span>Edición</span>
              <span>Visualización</span>
              <span>Ir</span>
              <span>Ventana</span>
              <span>Ayuda</span>
            </span>
            <span className="dz-strip-spacer" />
            <WifiIcon size={14} className="dz-strip-icon" />
            <span className="dz-strip-item" data-r="stripItem">
              <TargetIcon size={16} />
              <span data-r="stripCount">3</span>
              <span className="dz-strip-title">Revisar el contrato de…</span>
            </span>
            <span className="dz-strip-clock">lun 12 oct 12:24</span>
          </div>
        </div>
      </div>

      <div className="rl-abs rl-panel-wrap" data-r="panelWrap">
        <div className="dz-panel" data-r="panel">
          <div className="dz-top-tabs" data-part>
            <button type="button" className="is-on">
              Prioridades
            </button>
            <button type="button">Notas</button>
          </div>
          <div className="dz-scope" data-part>
            <div className="dz-scope-tabs">
              <button type="button" className="is-on" data-r="scopeToday">
                Hoy · 3
              </button>
              <button type="button">Semana · 3</button>
            </div>
            <span className="dz-date">Lunes 12 oct</span>
          </div>
          <div className="rl-list" data-r="list">
            <div className="rl-row" data-r="row">
              <div className="dz-row" data-part>
                <StageRow title="Revisar el contrato de Lima" level="high" chip="Vencida" tone="late" note />
              </div>
            </div>
            <div className="rl-row" data-r="row">
              <div className="dz-row" data-r="newRow">
                <StageRow
                  title="Enviar la propuesta"
                  level="high"
                  chip="En 36 min"
                  tone="soon"
                  checkName="rowCheck"
                />
                <div className="rl-clip" data-r="confirm">
                  <ConfirmMock yesName="confirmYes" />
                </div>
              </div>
            </div>
            <div className="rl-row" data-r="row">
              <div className="dz-row" data-part>
                <StageRow
                  title="Preparar la demo del jueves"
                  level="medium"
                  chip="Hoy 16:00"
                  since="Desde vie 9"
                />
              </div>
            </div>
            <div className="rl-row" data-r="row">
              <div className="dz-row" data-part>
                <StageRow title="Ordenar el escritorio" level="low" since="De ayer" />
              </div>
            </div>
          </div>
          <span className="dz-new" data-part data-r="newBtn">
            <PlusIcon />
            Nueva prioridad
          </span>
          <div className="dz-hechas" data-part>
            <span className="dz-hechas-head">
              <CaretIcon size={10} />
              <span data-r="hechas">Hechas (1)</span>
            </span>
          </div>
          <div className="rl-undo-slot" data-r="undo">
            <div className="dz-undo">
              <CheckIcon size={12} className="dz-done-check" />
              <span className="dz-undo-text">Hecha: Enviar la propuesta</span>
              <button type="button" className="dz-undo-btn" data-r="undoBtn">
                Deshacer
              </button>
              <i className="dz-undo-line" data-r="undoLine" />
            </div>
          </div>
          <div className="dz-footer" data-part>
            <span className="dz-footer-count" data-r="footer">
              1 de 4 hechas hoy
            </span>
            <span className="dz-icon-btn">
              <BellIcon />
            </span>
            <span className="dz-icon-btn">
              <GearIcon />
            </span>
            <span className="dz-quit">Salir</span>
          </div>
        </div>
      </div>
      <div className="rl-abs rl-undo-clock" data-r="undoClock" />

      {STEPS.map((step, index) => (
        <div key={step.key} className="rl-abs rl-step" data-r="step">
          <b>{index + 1}</b>
          <span>{t(step.key)}</span>
        </div>
      ))}

      <div className="rl-abs rl-clock" data-r="clock">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
          <circle cx="12" cy="12" r="9" />
          <line data-r="hourHand" x1="12" y1="12" x2="12" y2="7.6" strokeWidth="1.8" />
          <line data-r="minuteHand" x1="12" y1="12" x2="12" y2="5.2" strokeWidth="1.3" />
          <circle cx="12" cy="12" r="1.2" fill="currentColor" />
        </svg>
        <span data-r="clockText" />
      </div>
      <div className="rl-abs rl-bigchip" data-r="bigChip">
        <span className="dz-chip" data-r="bigChipText" />
      </div>

      <div className="rl-abs rl-tl" data-r="tl">
        <i className="rl-tl-line" data-r="tlLine" />
        <i className="rl-tl-head" data-r="tlHead" />
        <span className="rl-tl-mark rl-tl-mark--soon" data-r="tlMark">
          <em>12:30</em>
        </span>
        <span className="rl-tl-mark rl-tl-mark--late" data-r="tlMark">
          <em>13:00</em>
        </span>
      </div>
      <NotificationMock name="note1" title="Vence en 30 min" />
      <NotificationMock name="note2" title="Prioridad vencida" />

      {TILES.map((tile) => (
        <div key={tile.key} className="rl-abs rl-tile" data-r="tile">
          <b style={{ color: `var(${tile.token})` }}>
            <span data-r="tileNum">{tile.value}</span>
            {tile.unit}
          </b>
          <span className="rl-tile-label">{t(tile.key)}</span>
          <TileViz kind={tile.viz} />
        </div>
      ))}

      <Mark name="lockMark" className="rl-lockmark" />
      <div className="rl-abs rl-lockword" data-r="lockWord">
        Daily ZGT
      </div>
      <div className="rl-abs rl-lockline" data-r="lockLine" />
      <div className="rl-abs rl-locktag" data-r="lockTag">
        {chars(t('reel.cap.tag'), 'lockTagChar')}
      </div>
      <div className="rl-abs rl-lockcredit" data-r="lockCredit">
        {chars(t('reel.credit'), 'lockCreditChar')}
      </div>

      {CAPTIONS.map((caption) => (
        <div
          key={caption.key}
          className={`rl-cap${caption.x !== undefined ? ' rl-cap--left' : ''}${caption.soft ? ' rl-cap--soft' : ''}`}
          data-r="cap"
          style={{
            top: caption.y,
            fontSize: caption.size,
            ...(caption.x !== undefined ? { left: caption.x, width: caption.width } : {}),
          }}
        >
          {t(caption.key)
            .split(' ')
            .map((word, index) => (
              <span key={index} className="rl-w">
                {word}
              </span>
            ))}
        </div>
      ))}

      <div className="rl-abs rl-ripple" data-r="ripple" />
      <div className="rl-abs rl-cursor" data-r="cursor">
        <svg width="44" height="44" viewBox="0 0 24 24">
          <path
            d="M5 3l14 8.5-6.2 1.6 3.6 6.4-2.6 1.5-3.6-6.4L5 20z"
            strokeWidth="1.4"
            strokeLinejoin="round"
          />
        </svg>
      </div>
      <canvas className="rl-fx" data-r="fx" width={1600} height={900} />
    </div>
  );
}

export const Stage = memo(StageInner, () => true);
