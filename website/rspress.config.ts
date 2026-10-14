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
        'A macOS menu bar app for the priorities and notes of the day and the week.',
    },
    {
      lang: 'es',
      label: 'Español',
      title: 'Daily ZGT',
      description:
        'Una app de barra de menús de macOS para las prioridades y las notas del día y de la semana.',
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
  },
});
