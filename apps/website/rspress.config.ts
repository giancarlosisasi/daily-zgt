import * as path from 'node:path';
import { defineConfig } from '@rspress/core';

const PRELOADED_FONTS = ['gabarito-latin-wght-normal', 'onest-latin-wght-normal', 'martian-mono-latin-wght-normal'];

export default defineConfig({
  root: path.join(import.meta.dirname, 'docs'),
  lang: 'en',
  locales: [
    {
      lang: 'en',
      label: 'English',
      title: 'Daily ZGT',
      description:
        'A native, open source app for Windows (system tray) and macOS (menu bar) for the priorities and notes of the day and the week. Your data stays on your computer.',
    },
    {
      lang: 'es',
      label: 'Español',
      title: 'Daily ZGT',
      description:
        'Una app nativa y de código abierto para Windows (bandeja del sistema) y macOS (barra de menús) para las prioridades y las notas del día y de la semana. Tus datos se quedan en tu computadora.',
    },
    {
      lang: 'pt',
      label: 'Português',
      title: 'Daily ZGT',
      description:
        'Um app nativo e de código aberto para Windows (bandeja do sistema) e macOS (barra de menus) para as prioridades e as notas do dia e da semana. Seus dados ficam no seu computador.',
    },
  ],
  icon: '/favicon.svg',
  logo: '/logo.svg',
  logoText: 'Daily ZGT',
  route: {
    cleanUrls: true,
    localeRedirect: 'never',
  },
  head: PRELOADED_FONTS.map((name): [string, Record<string, string>] => [
    'link',
    { rel: 'preload', as: 'font', type: 'font/woff2', crossorigin: '', href: `/static/font/${name}.woff2` },
  ]),
  builderConfig: {
    output: {
      filename: {
        font: '[name][ext]',
      },
    },
  },
  globalStyles: path.join(import.meta.dirname, 'styles/global.css'),
  themeConfig: {
    darkMode: 'force-dark',
    socialLinks: [{ icon: 'github', mode: 'link', content: 'https://github.com/giancarlosisasi/daily-zgt' }],
  },
});
