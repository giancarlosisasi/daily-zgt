# Daily ZGT for Windows

Daily ZGT for Windows is the native Windows version of Daily ZGT. It runs in the system tray and keeps your priorities in a panel.

- Features: see `docs/features.md` at the repo root.
- Design and rules: see `ARCHITECTURE.md` in this folder.

## Requirements

- Windows 10, build 19041 or later.
- The .NET 10 SDK.
- Python 3, for the design token generator.

## Tasks

Run these from the repo root with [`just`](https://github.com/casey/just).

- `just win-build` builds the solution.
- `just win-test` runs the tests.
- `just win-check` checks the design tokens, builds, and runs the tests. Run it before every commit.
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

## Languages

The app has Spanish, English and Portuguese. It follows the Windows display language. Any other language shows English. Set `DAILYZGT_LANG` to override it.
