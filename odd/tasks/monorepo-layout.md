# Monorepo layout for the macOS, Windows and web apps

## Objective

Turn the repository into a plain folder monorepo that holds the macOS app, a future native Windows app (C#) and the website, with shared design tokens.

## Problem

- The macOS app, its scripts and the website sit at the repository root. A second native app has no place to go.
- The design tokens live under `design-system-prototypes/tokens/`, a folder that reads as a prototype, not as a shared package.
- There is no task runner and no CI.

## Decisions

- 2026-10-17, user: no Bazel. Each app keeps its native build tool (XcodeGen/xcodebuild, dotnet/MSBuild, Rspress). A `justfile` sits on top. CI uses one workflow per app with path filters.
- 2026-10-17, user: commit and push straight to `main` for this feature.
- The Windows app is not scaffolded here. Its UI framework (WinUI 3 or WPF) is still open, so `apps/windows/` gets only a README. The C# token generator and `windows.yml` come with the Windows app.
- `tecla.json` is not edited, so `TeclaTokens.swift` and its digests stay the same. Its `source` field keeps the old prototype path as provenance.
- The untracked root `package.json` and `pnpm-lock.yaml` are a leftover `npm init` with no dependencies. They are deleted, not turned into a workspace root.

## Layout

```
apps/macos/        DailyZGT/, DailyZGTTests/, project.yml, scripts/
apps/windows/      README only (for now)
apps/website/      Rspress site
packages/design-tokens/  tecla.json, tecla.css, generate-tecla-tokens
assets/  odd/  .github/workflows/  justfile
```

## Scope

- In: folder moves, path fixes in code, scripts, config, README and the Guide (en/es/pt), `justfile`, CI for macOS and the website.
- Out: Windows app code, behavior changes in any app.

## Tasks

- [x] T1 Move the macOS app to `apps/macos/` (sources, tests, `project.yml`, `install.sh`, `generate-app-icon.swift`) and fix the commands in the README and the Guide. Route: inline (mechanical moves and path edits, already mapped with one search). Commit `6cfdaa9`.
- [x] T2 Move the tokens and their generator to `packages/design-tokens/`; fix `project.yml`, the generator, the icon script, the website CSS import and `.gitignore`. Route: inline (mechanical). Commit `eea245a`.
- [x] T3 Move the website to `apps/website/`; delete the leftover root `package.json` and `pnpm-lock.yaml`. Route: inline (mechanical). Commit `7fafefc`.
- [x] T4 Add `apps/windows/README.md`, the `justfile`, `.github/workflows/macos.yml` and `website.yml`, and the layout section of the root README. Route: inline (4 new small files, no research). Commit `4687af2`.

## Acceptance criteria

- No tracked file refers to an old path (`design-system-prototypes/tokens`, root `project.yml`, root `scripts/install.sh`, root `website/`).
- `packages/design-tokens/generate-tecla-tokens --check` passes.
- `pnpm build` passes in `apps/website/`.
- After the push, the macOS and website workflows pass on GitHub.

## Checks

- TDD: Strict TDD is on globally, but this feature changes no behavior, and the macOS tests cannot run on Windows. Mode: functional checks (source: no behavior change; runner `xcodebuild test` needs macOS, so CI runs it).
- Functional: old-path search, token `--check`, website `pnpm build`, GitHub Actions runs after the push.
- RDD: off (decided by global), so no native review.

## Progress

- T1-T4 done and pushed to `main` (`599f312..4687af2`).
- Checks: old-path search finds no tracked reference; `generate-tecla-tokens --check` passes; `pnpm build` passes in `apps/website/` and the built CSS holds the tecla tokens; `just --list` shows all tasks.
- CI on the push: `Website` run 39055216381 success; `macOS` run 39055216380 success on Xcode 26.6, 776 tests in 85 suites passed.
- Fixed during the work: a Python edit turned `Sections.tsx` from CRLF to LF (692-line diff); CRLF restored before the push. T3 first staged 6 untracked Playwright CLI logs; removed and `.playwright-cli/` is now ignored.
- Open: if a Vercel project deploys the site from the folder `website`, its root directory must change to `apps/website`. Not checked here (no local Vercel link).

## Next step

The Windows app: choose WinUI 3 or WPF, then scaffold `apps/windows/`, the C# token generator, `windows.yml` and `just win-*` tasks.
