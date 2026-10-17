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
- [x] T4 Scroll motion in the desk section: scroll-linked progress, depth layer, shorter steps, click-scroll guard, nav-aware centering, phone layout. Route: delegated writer (2+ non-trivial files). Starts after T2/T3 land, to keep one writer at a time. Commit `e45fece`.

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
- T4 done, `e45fece`. New `useDeskScroll.ts`: one passive scroll listener, rAF throttled, one rect read per frame, writes `--desk-p` (wall, stage) and `--step-p` (each step). Active step = nearest to the focus line (middle of the area below the nav, or below the pinned panel on phones) with 12% hysteresis; replaces the 2% IntersectionObserver band. Click goes straight to the step and holds scroll-derived changes until `scrollend` (1.2 s fallback, wheel/touch/key release it); centering is computed against the focus line, so the nav is respected. `.dz-desk-wall` now holds a parallax back layer (target rings + soft glow, aria-hidden). Scene change lifts the panel through a Web Animations call (no remount). Steps 62vh -> 44vh, last margin 26vh -> 24vh. Short laptops: panel zoom at max-height 620/540. Phones: panel pinned under the nav (zoom .74), steps scroll beneath with scroll-derived activation. Reduced motion writes no progress vars and the transform rules are off.
- T4 checks: `.dz-desk` height at 1440x900 3330px -> 2502px (phone 390x844: 1985px). 150px-step scroll shows steps 0..4 active in order with continuous `--step-p`/`--desk-p`; jumps 100,1700,300,2000,900,50 land on 0,4,1,4,2,0. Click step 4 from step 1 passed only 1 then 4 and ended with offset 0px from the focus center (nav 64px). 1280x720 panel bottom at most 577px of 720; at 1280x560 505px. 390x844 no horizontal scroll, steps 0..4 activate in order. Reduced motion: transforms constant across scroll, steps switch on scroll and click. `playwright-cli console error`: 0. `pnpm build` passes, `tsc --noEmit` clean. Not changed: the toast key (a scene change clears the toast because the reducer rebuilds the state).

## Next step

All four tasks done. Next: the user reviews the branch and decides on push and pull request (about 700 authored lines across T1-T4).
