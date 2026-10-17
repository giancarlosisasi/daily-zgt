export interface Spring {
  response: number;
  damping: number;
}

export type SpringName = 'default' | 'momentum' | 'press';

export const token = (name: string) =>
  getComputedStyle(document.documentElement).getPropertyValue(name).trim();

export function tokenSeconds(name: string) {
  const raw = token(name);
  const value = Number.parseFloat(raw);
  return raw.endsWith('ms') ? value / 1000 : value;
}

export const tokenMs = (name: string) => tokenSeconds(name) * 1000;

export const tokenNumber = (name: string) => Number.parseFloat(token(name));

export function tokenHex(name: string) {
  const raw = token(name).replace('#', '');
  const full = raw.length === 3 ? [...raw].map((char) => char + char).join('') : raw;
  return full.toUpperCase();
}

export function tokenBezier(name: string): [number, number, number, number] {
  const numbers = token(name).match(/-?\d*\.?\d+/g)?.map(Number) ?? [];
  return [numbers[0], numbers[1], numbers[2], numbers[3]];
}

export const tokenSpring = (name: SpringName): Spring => ({
  response: tokenSeconds(`--spring-${name}-response`),
  damping: tokenNumber(`--spring-${name}-damping`),
});

export const keyTime = () => tokenSeconds('--duration-key');
