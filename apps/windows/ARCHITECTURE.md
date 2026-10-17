# Daily ZGT for Windows: architecture

This file is the contract for everyone who writes code in `apps/windows`. Read it in full before you change anything here.

The product reference is `docs/features.md` at the repo root (features F01–F22). The behavior reference is the macOS app in `apps/macos`. When the two disagree, `docs/features.md` wins, then the Swift code. The Windows app copies the macOS behavior and text exactly, except where the "Windows decisions" section below says otherwise.

## Stack

- C# on .NET 10, WPF. `net10.0` for the core library, `net10.0-windows10.0.19041.0` for the app (the Windows 10 SDK target gives the WinRT toast APIs).
- SQLite through `Microsoft.Data.Sqlite`, with the same schema, column formats and `app_state` keys as the macOS app.
- xUnit for tests.

WPF and not WinUI 3: the app is a tray icon, a borderless popup panel and a floating capture window, all drawn with the custom Tecla design. WPF gives transparent borderless windows, a tray icon, full style control and UI Automation for end-to-end tests without a packaging step. WinUI 3 adds Fluent chrome that Tecla replaces anyway, and has no tray icon.

## Layout

```
apps/windows/
  DailyZGT.slnx
  Directory.Build.props        nullable, implicit usings, warnings are errors
  src/DailyZGT.Core/           pure logic and storage, no WPF
    Domain/                    Records.cs (the data shape), LocalTime.cs
    Store/                     schema, migrations, AppStore (every mutation), snapshot
    Repeat/                    F14 repeat planner
    Rules/                     presentation rules: chips, labels, done window, history, tray title, footer count
    Alerts/                    F15 alert planner, copy, reconciler (pure) and the alert coordinator
    Localization/              the Texts catalog (es, en, pt)
    App/                       UI state models the views bind to (panel, flow, form, detail, notes, capture, settings, tray summary, clock)
  src/DailyZGT/                the WPF app
    Theme/                     TeclaTokens.cs (generated), resource dictionaries, control styles
    Assets/Fonts/              static font instances (generated from the macOS variable fonts)
    Assets/Icons/              icon geometry, app icon
    Program.cs                 Main: runs the Velopack hooks first, then starts WPF
    Platform/                  tray icon, toast notifications, global hotkey, start with Windows, animation setting, single instance, install and uninstall cleanup
    Shell/                     app host, panel window, shell view, footer, data error view
    Notes/                     notes tab
    Settings/                  settings page
    Capture/                   capture window
    Priorities/                PrioritiesView (list, rows, form, confirm bar, done), HistoryView, DetailView, UndoBarView
    UiText.cs                  UiText.Current, the Texts instance every view reads
  tests/DailyZGT.Core.Tests/   unit tests for DailyZGT.Core
  tests/DailyZGT.Platform.Tests/ unit tests for the pure parts of the app project (shortcut, tray badge, placement, adapters)
  tests/DailyZGT.UiTests/      end-to-end tests that launch the app and drive it with UI Automation
```

## Data

- `Domain/Records.cs` is the data shape. Do not add a second model of a priority. Extend this file when a field is truly missing, and say so in your report.
- The database file is `%LOCALAPPDATA%\DailyZGT\daily-zgt.sqlite`. The environment variable `DAILYZGT_DATA_DIR` replaces the folder. Tests and the end-to-end harness always set it.
- Times are local wall-clock `DateTime` values, truncated to seconds, stored as `yyyy-MM-ddTHH:mm:ss` text (`LocalTime.Text` and `LocalTime.Parse`). Day keys are `yyyy-MM-dd`, week keys are `yyyy-Www` (ISO).
- Enum values are stored as the macOS strings: `high`, `medium`, `low`, `today`, `week`, `none`, `daily`, `day`, `week`, `before_30m`, `at_due`, `snooze`, `scheduled`, `delivered`, `snoozed`, `cancelled`, `created`, `edited`, `moved`, `done`, `restored`, `subtask_done`.
- WAL journal, foreign keys on, busy timeout 2 s.
- All time-dependent code takes a `TimeProvider`. Never call `DateTime.Now` directly in Core.
- The store is single-writer. The app calls it on the UI thread. After every write it reads a new `StoreSnapshot` and raises one change event.

## Windows decisions

These follow the "Adaptación a Windows" table in `docs/features.md`.

| Feature | Decision |
|---|---|
| F01 | Tray icon. The icon is the crosshair with a badge that shows the open count of Hoy (`9+` above 9, no badge on a data error). The tooltip is `Daily ZGT · N` and, when the setting is on, a second line with the truncated title. A left click opens or closes the panel. A right click shows a menu with `Abrir` and `Salir`. |
| F02 | The panel opens above the tray, at the bottom right of the work area (it follows the taskbar edge when the taskbar is on another side). It closes when it loses focus. No taskbar button. |
| F15 | Alerts are Windows toast notifications. "Alertas apagadas" means Windows reports the app's notifications as disabled. There is no permission prompt, so the "never asked" state does not exist on Windows. `Abrir ajustes` opens `ms-settings:notifications`. |
| F17 | Default shortcut `Ctrl+Alt+Mayús+P` (Ctrl+Alt+Shift+P). The shortcut is stored in `HKCU\Software\DailyZGT`, not in the database. |
| F18 | Start with Windows uses `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. When the user disabled it in Settings > Apps > Startup, the row shows `Falta tu aprobación en Configuración.` with `Abrir ajustes` (`ms-settings:startupapps`). Copy changes: `Abre Daily ZGT cuando inicias sesión en tu computadora.`, `Siguiente prioridad en la barra de tareas`, `Muestra al pasar sobre el ícono el título de la primera prioridad abierta de Hoy.`, `Windows no aceptó el cambio.` In an installed copy (Velopack) the Run value points at the launcher `%LOCALAPPDATA%\DailyZGT.Windows\Daily ZGT.exe`, which survives updates, not at `current\DailyZGT.exe`. |
| F22 | Windows "Animation effects" (`SPI_GETCLIENTAREAANIMATION`) off means no motion. |
| Open decisions 1 and 2 | Windows fixes both. The date next to the scope tabs follows the minute tick and the day change (`ShellModel`). The day and week notes switch on `UiClock.DayChanged` (`NotesModel`), saving a pending edit to the old period first. `apps/macos/TODO.md` lists the matching macOS change. |
| Open decisions 3–7 | Windows copies the macOS behavior. The repo rule says a behavior change lands in both apps, so a fix for any of them is a separate change to both apps. |

## Install and release

Velopack packs the app. `Program.Main` calls `VelopackApp.Build()...Run()` before anything else, because Velopack runs the install, update and uninstall hooks by starting the exe with a flag. The uninstall hook (`UninstallCleanup`) removes the Run value, the toast registration and `HKCU\Software\DailyZGT`. It never touches the data folder. The package id is not `DailyZGT`, because Velopack deletes `%LOCALAPPDATA%\<packId>` on uninstall and `%LOCALAPPDATA%\DailyZGT` holds the database. The version is `Version` in `Directory.Build.props`. See the README for `just win-pack` and the release workflow.

## Languages

The app speaks Spanish, English and Portuguese. It follows the Windows display language (`CultureInfo.CurrentUICulture`): `es*` gives Spanish, `pt*` gives Portuguese, anything else gives English. The environment variable `DAILYZGT_LANG` (`es`, `en`, `pt`) overrides it.

- Every user-facing string, plural and date pattern lives in one typed catalog in `src/DailyZGT.Core/Localization/`: a `Texts` type with `required` members and one instance per language (`Texts.Es`, `Texts.En`, `Texts.Pt`). A missing translation is a compile error. No string literal shown to the user lives anywhere else.
- Plurals and patterns are functions on the catalog (for example `SubtasksLeft(int)`, `DueIn(int hours, int minutes)`, `DayLabel(DateTime)`), because word order differs between languages: `Lunes 12 oct`, `Monday Oct 12`, `Segunda 12 out`.
- The Spanish text is exactly what `docs/features.md` writes. English and Portuguese reuse the website wording first (`apps/website/i18n.json`, the `demo.*` keys), so the app and the site say the same thing.
- Rules in Core that build text take a `Texts` argument. Views bind to the current `Texts` instance.
- macOS gets the same languages in separate work by another agent. Do not edit `apps/macos` here.

## Test seams

- `DAILYZGT_DATA_DIR` sets the data folder.
- `DAILYZGT_NO_HOTKEY=1` skips the global hotkey registration, so a test run does not steal the user's shortcut.
- Command-line `--show-panel` opens the panel at start. `--show-capture` opens the capture window at start. A second launch of the exe passes its arguments to the running instance.
- Every interactive or asserted element has an `AutomationProperties.AutomationId` in PascalCase that names its role: `TabPriorities`, `ScopeToday`, `NewPriorityButton`, `NewPriorityTitle`, `PriorityRow_<id>`, `RowCheckbox_<id>`, `ConfirmDone`, `UndoButton`, `FooterSummary`, and so on.

## Rules for code

- Read the Swift file that owns a behavior before you port it. Port its tests to xUnit as well, renamed to C# style.
- Put every user-facing string in the `Texts` catalog in all three languages (see "Languages"). The Spanish text is exactly what `docs/features.md` writes.
- Comments only for a non-obvious why. No comments that narrate what the code does.
- A control template reads an attached property of its control with `{theme:ParentValue theme:KeyFace.Radius}`, never with a Binding path such as `{Binding (theme:KeyFace.Radius), RelativeSource=...}`. WPF resolves the prefix of such a path in the view that uses the style, and never on a transform, so the binding fails without an error.
- Business rules live in `DailyZGT.Core`, pure and tested. Views stay thin.
- `dotnet build apps/windows/DailyZGT.slnx` has zero warnings and `dotnet test apps/windows/DailyZGT.slnx` is green before every commit.
- Commit messages: Conventional Commits, scope `windows`, feature codes in the body, for example `feat(windows): add the priority store` with `F03 F05 F07` in the body. Do not add a `Co-Authored-By` trailer.
