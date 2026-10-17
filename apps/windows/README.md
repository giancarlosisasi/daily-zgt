# Daily ZGT for Windows

Daily ZGT for Windows is the native Windows version of Daily ZGT. It runs in the system tray and keeps your priorities in a panel.

- Features: see `docs/features.md` at the repo root.
- Design and rules: see `ARCHITECTURE.md` in this folder.

## Install

1. Open the [Releases page](https://github.com/giancarlosisasi/daily-zgt/releases) and download `DailyZGT.Windows-win-Setup.exe` from the latest `windows-v*` release.
2. Run it. It installs for your user only and needs no admin rights. It does not need .NET installed. Daily ZGT opens when it finishes, and a `Daily ZGT` shortcut appears in the Start menu.

The installer is not code-signed yet, so Windows SmartScreen shows "Windows protected your PC". Click "More info", then "Run anyway".

The app installs in `%LOCALAPPDATA%\DailyZGT.Windows`. It is a different folder from your data on purpose.

### Uninstall

Open Settings > Apps > Installed apps, find Daily ZGT, and choose Uninstall. The uninstaller removes the app, the Start menu shortcut, the "Open at login" entry and the shortcut setting in the registry. It keeps your data: `%LOCALAPPDATA%\DailyZGT\daily-zgt.sqlite` stays on your computer. Delete the folder yourself if you want it gone.

### Updates

The app does not check for updates yet. To update, uninstall Daily ZGT, then run the newer `Setup.exe`. Your data stays.

## Requirements

To build and run from source:

- Windows 10, build 19041 or later.
- The .NET 10 SDK.
- Python 3, for the design token generator.

## Tasks

Run these from the repo root with [`just`](https://github.com/casey/just).

- `just win-build` builds the solution.
- `just win-test` runs the tests, except the end-to-end UI tests.
- `just win-check` checks the design tokens, builds, and runs the tests. Run it before every commit.
- `just win-e2e` builds the app, then runs the end-to-end tests in `tests/DailyZGT.UiTests`. Each test starts `DailyZGT.exe` with an empty data folder and uses it through UI Automation. The tests move the mouse and type, so do not use the computer while they run. They need a signed-in desktop, so CI does not run them. Set `DAILYZGT_EXE` to test another build of the exe.
- `just win-pack` publishes the app self-contained for win-x64 and packs the installer with [Velopack](https://velopack.io) into `artifacts/releases` (ignored by git). `Setup.exe` is in that folder. `just win-pack -Version 0.2.0` packs another version. The `vpk` tool installs as a local dotnet tool from `.config/dotnet-tools.json`.
- `just readme-shots` renders the images of the root README into `assets/readme`. It runs `DailyZGT.exe --readme-snapshots assets/readme --lang en`, which draws each screen from a visual tree offscreen over an English demo store, at 2x. It never captures the screen. The macOS app does not build on Windows, so these images come from the Windows app. The code is in `src/DailyZGT/Gallery`.
- `just docs-shots` renders the screenshots of the website docs the same way, with `--docs-snapshots`, once per language into `apps/website/docs/public/shots/en`, `es` and `pt`.
- `just win-run` starts the app with the panel open. Extra arguments go to the app, for example `just win-run --show-capture`.

## Environment variables and flags

- `DAILYZGT_DATA_DIR` sets the data folder. The default is `%LOCALAPPDATA%\DailyZGT`.
- `DAILYZGT_NO_HOTKEY=1` skips the global shortcut, so a test run does not take it.
- `DAILYZGT_LANG` sets the language to `es`, `en` or `pt`.
- `--show-panel` opens the panel at start.
- `--show-capture` opens the capture window at start.

When the app runs already, a second launch passes its arguments to the running copy.

## Data

The database is `%LOCALAPPDATA%\DailyZGT\daily-zgt.sqlite`. It is a SQLite file with the same schema as the macOS app.

## Release

The version lives in `Directory.Build.props` (`Version`). The workflow `.github/workflows/release-windows.yml` runs when a tag `windows-v*` is pushed. It runs the same checks as `windows.yml`, takes the version from the tag, downloads the previous release so Velopack builds delta packages, packs, and uploads to a GitHub Release with `vpk upload github`.

To cut a release:

1. Set `Version` in `Directory.Build.props` to the new version and commit it, so local builds match the release.
2. Tag and push:

```
git tag windows-v0.1.0 && git push origin windows-v0.1.0
```

The workflow can also run by hand from the Actions tab (`workflow_dispatch`, with a version). A manual run leaves the release as a draft.

Code signing is off. To turn it on, add the repository secret `WINDOWS_SIGN_TEMPLATE`: a `vpk --signTemplate` string, for example a `jsign` command ending in `{{file}}`. The workflow passes it to `pack.ps1` as `DAILYZGT_SIGN_TEMPLATE`. Do the same locally by setting that variable before `just win-pack`.

The package id is `DailyZGT.Windows` (`VelopackPackId` in `Directory.Build.props`). Never change it to `DailyZGT`: Velopack deletes the folder named after the package id on uninstall, and `%LOCALAPPDATA%\DailyZGT` is where the data lives. Changing the id after a release also breaks updates for the people who installed.

## Languages

The app has Spanish, English and Portuguese. It follows the Windows display language. Any other language shows English. Set `DAILYZGT_LANG` to override it.
