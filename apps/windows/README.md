# Daily ZGT for Windows

This folder will hold the native Windows app of Daily ZGT, written in C#.

The app does not exist yet. The UI framework (WinUI 3 or WPF) is still open.

## Planned layout

```
apps/windows/
  DailyZGT.sln
  src/DailyZGT/          the app
  tests/DailyZGT.Tests/  the tests
```

## Shared parts

- The design tokens come from `packages/design-tokens/tecla.json`. A C# generator will write the tokens for this app, as `generate-tecla-tokens` does for the macOS app.
- The app builds with `dotnet` and MSBuild. A `windows.yml` workflow and `just win-*` tasks come with the first version of the app.
