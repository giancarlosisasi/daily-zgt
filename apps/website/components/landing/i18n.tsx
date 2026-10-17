import { useI18n, useLang } from '@rspress/core/runtime';
import { Fragment, type ReactNode } from 'react';
import { toLang, type Lang } from './model';

export function useT() {
  const t = useI18n<Record<string, unknown>>();
  return (key: string, vars?: Record<string, string | number>) => {
    let text: string = t(key);
    if (vars) {
      for (const [name, value] of Object.entries(vars)) {
        text = text.replaceAll(`{${name}}`, String(value));
      }
    }
    return text;
  };
}

export function useDemoLang(): Lang {
  return toLang(useLang());
}

export function useGuideHref() {
  const lang = useLang();
  return (path: string) => (lang === 'en' ? path : `/${lang}${path}`);
}

export function Rich({ text }: { text: string }): ReactNode {
  return (
    <>
      {text.split('`').map((part, index) =>
        index % 2 === 1 ? <code key={index}>{part}</code> : <Fragment key={index}>{part}</Fragment>,
      )}
    </>
  );
}
