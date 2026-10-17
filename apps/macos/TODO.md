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
