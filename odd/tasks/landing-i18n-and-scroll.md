# Landing i18n (en/es/pt) and scroll motion

## Objective

Make every landing page read in one language, add Portuguese, and make the "Scroll, or click the panel" section move with the scroll instead of jumping.

## Problem

- The English page mixes English copy with Spanish UI: the demo panel, the fake Finder menu bar, the undo bar and the step copy ("Choose `Hecha`") are hardcoded in Spanish.
- The macOS app itself is Spanish-only (strings are hardcoded in Swift, no String Catalog), which is why the demo was in Spanish.
- The site supports only `en` and `es`. It must support `en`, `es` and `pt`.
- The desk section has no scroll-linked motion: scenes switch instantly, the back layer is empty, gaps are long, a clicked step replays intermediate scenes, centering ignores the nav, and phones get no scroll effect.

## Decisions

- 2026-10-17, user: translate the demo panel, menu bar and steps into the page language, and add one line saying the app is in Spanish for now. The website only; the macOS app is not translated in this feature.
- Portuguese covers the whole site (landing and Guide), so the language switch never leads to a missing page. Locale code `pt`, Brazilian Portuguese, neutral register.

## Scope

- In: `website/` only.
- Out: the macOS app (`DailyZGT/`), the hidden motion reel (`components/landing/reel/`, stays as is).

## Tasks

- [x] T1 Hide the motion reel on the landing page. Route: inline (1 file). Commit `60b0405`.
- [x] T2 Localize the landing page: every visible string in `en`/`es`/`pt`, including the demo panel, Finder menu bar, seed priorities, chips, undo bar, step copy; add the "app is in Spanish for now" note. Route: delegated writer (mapping trigger: 4+ files). Commit `9db5a3a`.
- [x] T3 Add the `pt` locale to Rspress and translate the Guide (`docs/pt/**`). Route: delegated writer, same worker as T2. Commit `f25223b`.
- [ ] T4 Scroll motion in the desk section: scroll-linked progress, depth layer, shorter steps, click-scroll guard, nav-aware centering, phone layout. Route: delegated writer (2+ non-trivial files). Starts after T2/T3 land, to keep one writer at a time.

## Acceptance criteria

- On `/`, `/es/` and `/pt/`, no visible text is in another language, except product names (Daily ZGT, SwiftUI, SQLite, macOS) and the note about the app language.
- Labels named in the step copy match the labels shown in the demo panel on the same page.
- `pnpm build` passes and builds all three locales.
- T4: the panel and steps move with the scroll, and reduced motion still shows a still, working section.

## Checks

- TDD: Strict TDD is enabled globally, but `website/` has no test runner. Mode for this feature: functional checks only (source: no runner in project). Disclosed to the user.
- Functional: `pnpm build` in `website/`; grep the built HTML for leftover cross-language strings; browser check of the three locales.
- RDD: off (decided by global), so no native review.

## Progress

- T1 done, `60b0405`.
- T2 done, `9db5a3a`. Demo panel, Finder menu bar, seed data, chips, undo bar, toasts, confirm dialog, aria-labels and step copy come from `i18n.json` (`demo.*` keys) in en/es/pt. `model.ts` is lang-aware (`DemoState.lang`, `msg`, `levelLabel`, `dueLabel(due, now, lang)`). New line `desk.appLang` under the desk lead says the app interface is Spanish for now. Copy that named Spanish labels in en/pt (bento, alerts, shortcut, local) now names the translated labels. Every landing key has en, es and pt (30 Rspress theme keys have es and pt only, as before).
- T3 done, `f25223b`. `pt` locale in `rspress.config.ts`; `docs/pt/**` mirrors `docs/es/**` file for file (index, `_nav.json`, all `_meta.json`, 14 mdx pages). Guide keeps the Spanish UI labels in backticks and bold, as the en and es guides do.
- Checks: `pnpm build` passes and emits `/`, `/es/`, `/pt/` and the pt guide pages; `tsc --noEmit` clean; leftover-language grep on built HTML (script and style stripped) found no cross-language UI text in en, es or pt. Only pt hits are words that are valid Portuguese too (Prioridades, Notas, Semana, Abrir).

## Next step

T4: scroll motion in the desk section, with one delegated writer.
