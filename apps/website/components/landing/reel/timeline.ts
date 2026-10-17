export const DURATION = 30;
export const STAGE_W = 1600;
export const STAGE_H = 900;

export const CHAPTERS = [
  { t: 0, key: 'reel.ch.mark' },
  { t: 4, key: 'reel.ch.name' },
  { t: 8, key: 'reel.ch.ask' },
  { t: 12, key: 'reel.ch.panel' },
  { t: 14, key: 'reel.ch.flow' },
  { t: 19.5, key: 'reel.ch.due' },
  { t: 22.5, key: 'reel.ch.alert' },
  { t: 25, key: 'reel.ch.numbers' },
  { t: 27.5, key: 'reel.ch.lockup' },
] as const;

export const STILLS = [
  { t: 3.2, key: 'reel.ch.palette' },
  { t: 6.6, key: 'reel.ch.name' },
  { t: 10.9, key: 'reel.ch.ask' },
  { t: 13.6, key: 'reel.ch.panel' },
  { t: 16.6, key: 'reel.ch.flow' },
  { t: 17.9, key: 'reel.ch.flow' },
  { t: 21.2, key: 'reel.ch.due' },
  { t: 24.3, key: 'reel.ch.alert' },
  { t: 26.9, key: 'reel.ch.numbers' },
] as const;

export const PALETTE = [
  { token: '--palette-yellow', ink: '--band-key-text', role: 'Regresar' },
  { token: '--palette-orange', ink: '--band-key-text', role: 'Media' },
  { token: '--palette-rose', ink: '--band-key-text', role: 'Alta' },
  { token: '--palette-violet', ink: '--color-on-fill', role: 'Hecha' },
  { token: '--palette-blue', ink: '--band-key-text', role: 'Deshacer' },
] as const;

export const DONE_BURST = ['--panel-accent', '--panel-done', '--panel-accent-side', '--panel-done-title'] as const;

export const PANEL_PARTS = [12.42, 12.52, 12.62, 12.74, 12.86, 12.98, 13.1, 13.22];

export const TILE_START = 25;
export const TILE_STEP = 0.125;

export interface Caption {
  key: string;
  y: number;
  size: number;
  a: number;
  b: number;
  x?: number;
  width?: number;
  soft?: boolean;
}

export const CAPTIONS: Caption[] = [
  { key: 'reel.cap.tag', y: 700, size: 46, a: 4.6, b: 7.5, soft: true },
  { key: 'reel.cap.ask', y: 112, size: 76, a: 8.05, b: 11.5 },
  { key: 'reel.cap.panel', x: 110, y: 350, size: 92, width: 800, a: 11.8, b: 13.72 },
  { key: 'reel.cap.due', y: 716, size: 54, a: 19.6, b: 22.15, soft: true },
  { key: 'reel.cap.alert', x: 120, y: 480, size: 84, width: 740, a: 22.55, b: 24.7 },
];

export const STEPS = [
  { key: 'reel.step.add', at: 14.5 },
  { key: 'reel.step.ask', at: 15.5 },
  { key: 'reel.step.undo', at: 17.32 },
] as const;

export const TILES = [
  { value: 6, unit: '', key: 'reel.tile.tables', token: '--palette-yellow', viz: 'tables' },
  { value: 3, unit: '', key: 'reel.tile.levels', token: '--palette-rose', viz: 'levels' },
  { value: 2, unit: '', key: 'reel.tile.lists', token: '--color-text', viz: 'lists' },
  { value: 2, unit: '', key: 'reel.tile.alerts', token: '--palette-orange', viz: 'alerts' },
  { value: 5, unit: ' s', key: 'reel.tile.undo', token: '--palette-blue', viz: 'undo' },
  { value: 1, unit: '', key: 'reel.tile.file', token: '--color-text', viz: 'file' },
] as const;

export const TABLE_NAMES = ['priority', 'subtask', 'note', 'alert', 'priority_event', 'app_state'];
