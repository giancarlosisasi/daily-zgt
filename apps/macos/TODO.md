# macOS: changes to match the Windows app

The Windows app fixes two behaviors that the macOS app still has. Both are open decisions 1 and 2 in `docs/features.md`. The repo rule says a behavior change lands in both apps, so the macOS side is still owed.

## 1. The date next to the scope tabs stays on yesterday (F02, F21)

What the user sees now: the panel is open at midnight, and the date next to `Hoy` and `Semana` still shows the old day (`Lunes 12 oct`) until something else redraws the panel. The week label has the same problem on the first day of a new ISO week.

What the Windows app does: the date is part of the shell model, which recomputes it on every store change, every minute tick and every day change. At 00:00 the date reads `Martes 13 oct` with no user action. Test: `The_date_turns_over_at_midnight_on_the_minute_tick` in `apps/windows/tests/DailyZGT.Platform.Tests/ShellModelTests.cs`.

Swift files that likely own it:

- `apps/macos/DailyZGT/App/PanelView.swift`, `scopeRow`: it reads `store.now()` in a plain `Text`. Only the footer sits inside `TimelineView(.everyMinute)`. Wrap the date `Text` (and the `Hoy`/`Semana` counts if they should follow the clock) in the same kind of `TimelineView(.everyMinute)`.
- `apps/macos/DailyZGT/App/PanelLabels.swift`, `date(for:at:in:)`: pure, needs no change.

How to verify: add a test that calls `PanelLabels.date(for:at:)` on both sides of midnight if none exists. Then run the app, open the panel at 23:59, wait one minute and check that the date changes without a click. A debug clock or a system clock change also works.

## 2. The day note and the week note do not switch at midnight (F16, F21)

What the user sees now: the panel is open on the Notes tab at midnight. The field still shows the old day's text. The new day's empty note appears only on focus, on a data change, or on the 30-second check. A person who types in that gap saves into the old day.

What the Windows app does: the notes model also listens to the clock's day change and runs the same `sync` at once. It saves a pending edit to the old day first, then shows the empty note of the new day. For the week note the same happens at midnight between Sunday and Monday (ISO week change). On a day change inside the same week the week note keeps its text. Tests in `apps/windows/tests/DailyZGT.Core.Tests/App/NotesModelTests.cs`:

- `TheDayNoteSwitchesAtMidnightWithoutWaitingForTheCheck`
- `AnUnsavedEditLandsOnTheOldDayWhenMidnightPasses`
- `TheWeekNoteSwitchesAtMidnightOfTheNextIsoWeek`
- `TheWeekNoteStaysOnTheSameWeekWhenOnlyTheDayChanges`

Swift files that likely own it:

- `apps/macos/DailyZGT/Notes/NotesView.swift`, `NotesEditor`: it calls `model.sync()` on `onChange(of: model.externalBody)`, on focus, and in a loop with `Theme.Notes.syncInterval`. Add a trigger at the day boundary, for example a `TimelineView(.everyMinute)` that calls `model.sync()` on each tick, or an observer of `NSCalendarDayChanged`.
- `apps/macos/DailyZGT/Notes/NotesModel.swift`, `sync()`: it already flushes the old period and reloads when `store.period(scope)` changes. No change expected.

How to verify: add a test in `DailyZGTTests/Notes` that builds a `NotesModel`, edits, moves the store clock past midnight, triggers the new day signal, and checks that the old day holds the edit and `period` and `text` are the new day's. Then run the app with the panel open on Notes at 23:59 and watch it switch at 00:00 with no click.

After both fixes, update the "Decisiones abiertas" items 1 and 2 in `docs/features.md`, and the F16 rule that lists when the app detects the new day.

## 3. No installer and no release (distribution)

What the user sees now: there is no download. A person builds the app from source (`apps/macos/scripts/install.sh` copies a Release build to `/Applications`).

What the Windows app does: `just win-pack` makes a per-user `Setup.exe` with Velopack. Pushing a tag `windows-v*` runs `.github/workflows/release-windows.yml`, which builds, packs and uploads the installer to GitHub Releases. Uninstall removes the app and its system entries and keeps the user's data. See `apps/windows/README.md` ("Install" and "Release") and `apps/windows/ARCHITECTURE.md` ("Install and release").

What macOS needs:

- A signed and notarized `.app` in a `.dmg` or `.zip`. This needs an Apple Developer account (Developer ID certificate) and notarization with `notarytool`; without it Gatekeeper blocks the first launch.
- A `release-macos.yml` workflow on a `macos-v*` tag that builds Release, signs, notarizes, staples and uploads to GitHub Releases. Velopack also packs macOS apps, so the same tool can give updates on both platforms.
- Removal: on macOS the user drags the app to the Trash. The login item and the notification permission go with it; the data in `~/Library/Application Support/DailyZGT` stays, the same rule as on Windows.

How to verify: download the release on a Mac that never ran the app, open it without a Gatekeeper block, add a priority, delete the app, and check that the database is still there.

## 4. The app shows Spanish only (all features, product rule on languages)

What the user sees now: every label, message and alert in the macOS app is Spanish, whatever the system language is. The strings are literals in the Swift views and label files, for example `"Hoy"` in `apps/macos/DailyZGT/App/PanelLabels.swift` and `todayLimitTitle` in `apps/macos/DailyZGT/Settings/SettingsView.swift`. The app has no `.xcstrings` or `.lproj` files.

What the Windows app does: it speaks Spanish, English and Portuguese. It follows the system display language, and any other language shows English. The variable `DAILYZGT_LANG` (`es`, `en`, `pt`) overrides it. Every string lives in one table per language: `apps/windows/src/DailyZGT.Core/Localization/SpanishTexts.cs`, `EnglishTexts.cs` and `PortugueseTexts.cs`. `Texts.cs` makes every member `required`, so a missing translation does not compile. The language rule is in `AppLanguage.cs`.

What macOS needs:

- A String Catalog (`Localizable.xcstrings`) with `es`, `en` and `pt`, listed in `project.yml` (`knownRegions`, and Spanish as the development language). Take the English and Portuguese words from the Windows tables, so the two apps say the same thing. Change the Windows words "Windows", "taskbar" and "Settings" to "macOS", "menu bar" and "System Settings".
- The same fallback: a system language other than Spanish, English or Portuguese shows English. A launch argument or environment variable like `DAILYZGT_LANG` helps the tests and the screenshots.
- Dates in the panel (`Lunes 12 oct`, `Semana 42 · 12–18 oct`), the due chip and the footer count in the three languages, with the same formats as the Windows `DayLabel` and `WeekLabel`.
- Alert text and alert actions (`Abrir`, `Posponer 15 min`) in the three languages.

How to verify: a test per language that reads a few known keys, and a check that no key is missing in `en` or `pt`. Then run the app with the system language set to English, to Portuguese and to French (English expected), and check the panel, the settings, the capture window and a test alert.

After this, update the product rule on languages in `docs/features.md` (it says the macOS app still has only Spanish), the root `README.md`, and the website pages that say the macOS app is Spanish only.
