export type Level = 'high' | 'medium' | 'low';
export type ListName = 'today' | 'week';
export type TabName = 'prio' | 'notes';

export interface Subtask {
  id: string;
  title: string;
  done: boolean;
}

export interface Priority {
  id: string;
  title: string;
  level: Level;
  list: ListName;
  due: number | null;
  doneAt: number | null;
  subtasks: Subtask[];
  hasNote: boolean;
  since: number;
}

export type DueTone = 'late' | 'soon' | 'later';

export const NOW = new Date(2026, 9, 12, 12, 24, 0).getTime();

const at = (dayOffset: number, hour: number, minute: number) =>
  new Date(2026, 9, 12 + dayOffset, hour, minute, 0).getTime();

const WEEKDAYS = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
const RANK: Record<Level, number> = { high: 0, medium: 1, low: 2 };

export const LEVEL_LABEL: Record<Level, string> = {
  high: 'Alta',
  medium: 'Media',
  low: 'Baja',
};

export const LEVEL_BARS: Record<Level, number> = { high: 3, medium: 2, low: 1 };

const pad = (n: number) => String(n).padStart(2, '0');

export function dueLabel(due: number, now: number = NOW): { text: string; tone: DueTone } {
  const minutes = Math.round((due - now) / 60000);
  if (minutes < 0) return { text: 'Vencida', tone: 'late' };
  if (minutes < 120) {
    if (minutes < 60) return { text: `En ${minutes} min`, tone: 'soon' };
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return { text: `En ${hours} h ${rest} min`, tone: 'soon' };
  }
  const date = new Date(due);
  const time = `${pad(date.getHours())}:${pad(date.getMinutes())}`;
  const sameDay = date.toDateString() === new Date(now).toDateString();
  return {
    text: sameDay ? `Hoy ${time}` : `${WEEKDAYS[date.getDay()]} ${time}`,
    tone: 'later',
  };
}

export function sinceLabel(days: number, now: number = NOW): string | null {
  if (days < 1) return null;
  if (days === 1) return 'De ayer';
  const base = new Date(now);
  const date = new Date(base.getFullYear(), base.getMonth(), base.getDate() - days);
  return `Desde ${WEEKDAYS[date.getDay()]} ${date.getDate()}`;
}

export const MENU_BAR_TITLE_MAX = 24;

export function menuBarTitle(items: Priority[]): string | null {
  const first = sortOpen(items.filter((item) => item.list === 'today'))[0];
  if (!first) return null;
  const clean = first.title.trim();
  if (clean.length <= MENU_BAR_TITLE_MAX) return clean;
  return `${clean.slice(0, MENU_BAR_TITLE_MAX - 1).trimEnd()}…`;
}

export function sortOpen(items: Priority[]): Priority[] {
  return items
    .filter((item) => item.doneAt === null)
    .sort((a, b) => {
      if (RANK[a.level] !== RANK[b.level]) return RANK[a.level] - RANK[b.level];
      if (a.due === null && b.due === null) return 0;
      if (a.due === null) return 1;
      if (b.due === null) return -1;
      return a.due - b.due;
    });
}

export function sortDone(items: Priority[]): Priority[] {
  return items
    .filter((item) => item.doneAt !== null)
    .sort((a, b) => (b.doneAt ?? 0) - (a.doneAt ?? 0));
}

export const seed = (): Priority[] => [
  {
    id: 'a',
    title: 'Revisar el contrato de Lima',
    level: 'high',
    list: 'today',
    due: at(0, 11, 30),
    doneAt: null,
    subtasks: [],
    hasNote: true,
    since: 0,
  },
  {
    id: 'b',
    title: 'Enviar la propuesta',
    level: 'high',
    list: 'today',
    due: at(0, 13, 0),
    doneAt: null,
    subtasks: [
      { id: 'b1', title: 'Armar el PDF', done: true },
      { id: 'b2', title: 'Revisar los precios', done: false },
      { id: 'b3', title: 'Mandar el correo', done: false },
    ],
    hasNote: true,
    since: 0,
  },
  {
    id: 'c',
    title: 'Preparar la demo del jueves',
    level: 'medium',
    list: 'today',
    due: at(0, 16, 0),
    doneAt: null,
    subtasks: [],
    hasNote: false,
    since: 3,
  },
  {
    id: 'd',
    title: 'Ordenar el escritorio',
    level: 'low',
    list: 'today',
    due: null,
    doneAt: null,
    subtasks: [],
    hasNote: false,
    since: 1,
  },
  {
    id: 'e',
    title: 'Llamar a Marta',
    level: 'medium',
    list: 'today',
    due: null,
    doneAt: 1,
    subtasks: [],
    hasNote: false,
    since: 0,
  },
  {
    id: 'f',
    title: 'Planear el trimestre',
    level: 'medium',
    list: 'week',
    due: at(4, 18, 0),
    doneAt: null,
    subtasks: [],
    hasNote: false,
    since: 0,
  },
  {
    id: 'g',
    title: 'Pagar el hosting',
    level: 'low',
    list: 'week',
    due: null,
    doneAt: null,
    subtasks: [],
    hasNote: false,
    since: 0,
  },
  {
    id: 'h',
    title: 'Escribir el resumen del sprint',
    level: 'high',
    list: 'week',
    due: at(2, 17, 0),
    doneAt: null,
    subtasks: [],
    hasNote: false,
    since: 0,
  },
];

export interface DemoState {
  items: Priority[];
  tab: TabName;
  scope: ListName;
  panelOpen: boolean;
  expanded: string[];
  confirming: string | null;
  leaving: string | null;
  undo: { id: string; token: number } | null;
  hechasOpen: boolean;
  formOpen: boolean;
  highlight: string | null;
  notes: Record<ListName, string>;
  toast: number;
  seq: number;
}

export const initialState = (): DemoState => ({
  items: seed(),
  tab: 'prio',
  scope: 'today',
  panelOpen: true,
  expanded: [],
  confirming: null,
  leaving: null,
  undo: null,
  hechasOpen: false,
  formOpen: false,
  highlight: null,
  notes: {
    today: 'Llamar a Marta antes de las 5',
    week: 'Cerrar el contrato de Lima el viernes',
  },
  toast: 0,
  seq: 10,
});

export type Action =
  | { type: 'reset'; panelOpen: boolean }
  | { type: 'scene'; scene: number }
  | { type: 'setTab'; tab: TabName }
  | { type: 'setScope'; scope: ListName }
  | { type: 'setPanel'; open: boolean }
  | { type: 'toggleCaret'; id: string }
  | { type: 'toggleSub'; id: string; subId: string }
  | { type: 'ask'; id: string }
  | { type: 'cancel' }
  | { type: 'confirm'; id: string }
  | { type: 'finish'; id: string }
  | { type: 'clearUndo'; token: number }
  | { type: 'undo' }
  | { type: 'regresar'; id: string }
  | { type: 'clearHighlight'; id: string }
  | { type: 'toggleHechas' }
  | { type: 'setForm'; open: boolean }
  | { type: 'add'; title: string; level: Level; list: ListName; due: number | null }
  | { type: 'remove'; id: string }
  | { type: 'setNote'; scope: ListName; text: string }
  | { type: 'ping' }
  | { type: 'clearToast'; token: number };

export function reducer(state: DemoState, action: Action): DemoState {
  switch (action.type) {
    case 'reset':
      return { ...initialState(), panelOpen: action.panelOpen };
    case 'scene': {
      const base = { ...initialState(), notes: state.notes };
      if (action.scene === 1) return { ...base, confirming: 'b' };
      if (action.scene === 2) return { ...base, leaving: 'b' };
      if (action.scene === 3) {
        return {
          ...base,
          hechasOpen: true,
          items: base.items.map((item) => (item.id === 'b' ? { ...item, doneAt: 2 } : item)),
        };
      }
      if (action.scene === 4) return { ...base, tab: 'notes' };
      return base;
    }
    case 'setTab':
      return { ...state, tab: action.tab, confirming: null };
    case 'setScope':
      return { ...state, scope: action.scope, confirming: null };
    case 'setPanel':
      return { ...state, panelOpen: action.open };
    case 'toggleCaret':
      return {
        ...state,
        expanded: state.expanded.includes(action.id)
          ? state.expanded.filter((id) => id !== action.id)
          : [...state.expanded, action.id],
      };
    case 'toggleSub':
      return {
        ...state,
        items: state.items.map((item) =>
          item.id === action.id
            ? {
                ...item,
                subtasks: item.subtasks.map((sub) =>
                  sub.id === action.subId ? { ...sub, done: !sub.done } : sub,
                ),
              }
            : item,
        ),
      };
    case 'ask':
      return { ...state, confirming: state.confirming === action.id ? null : action.id };
    case 'cancel':
      return { ...state, confirming: null };
    case 'confirm':
      return { ...state, confirming: null, leaving: action.id };
    case 'finish': {
      const seq = state.seq + 1;
      return {
        ...state,
        seq,
        leaving: null,
        undo: { id: action.id, token: seq },
        items: state.items.map((item) =>
          item.id === action.id ? { ...item, doneAt: seq } : item,
        ),
      };
    }
    case 'clearUndo':
      return state.undo?.token === action.token ? { ...state, undo: null } : state;
    case 'undo': {
      const target = state.undo?.id;
      if (!target) return state;
      return {
        ...state,
        undo: null,
        items: state.items.map((item) =>
          item.id === target ? { ...item, doneAt: null } : item,
        ),
      };
    }
    case 'regresar':
      return {
        ...state,
        highlight: action.id,
        items: state.items.map((item) =>
          item.id === action.id ? { ...item, doneAt: null } : item,
        ),
      };
    case 'clearHighlight':
      return state.highlight === action.id ? { ...state, highlight: null } : state;
    case 'toggleHechas':
      return { ...state, hechasOpen: !state.hechasOpen };
    case 'setForm':
      return { ...state, formOpen: action.open };
    case 'add': {
      const seq = state.seq + 1;
      return {
        ...state,
        seq,
        formOpen: false,
        items: [
          ...state.items,
          {
            id: `n${seq}`,
            title: action.title,
            level: action.level,
            list: action.list,
            due: action.due,
            doneAt: null,
            subtasks: [],
            hasNote: false,
            since: 0,
          },
        ],
      };
    }
    case 'remove':
      return {
        ...state,
        confirming: state.confirming === action.id ? null : state.confirming,
        items: state.items.filter((item) => item.id !== action.id),
      };
    case 'setNote':
      return { ...state, notes: { ...state.notes, [action.scope]: action.text } };
    case 'ping':
      return { ...state, toast: state.toast + 1 };
    case 'clearToast':
      return state.toast === action.token ? { ...state, toast: 0 } : state;
    default:
      return state;
  }
}

export const countOpen = (items: Priority[], list: ListName) =>
  items.filter((item) => item.list === list && item.doneAt === null).length;

export const countDone = (items: Priority[], list: ListName) =>
  items.filter((item) => item.list === list && item.doneAt !== null).length;
