# Windows: open work

Items left for later on purpose. The repo rule still applies: a behavior change lands in both apps.

## 1. Code signing

What the user sees now: the installer is unsigned, so the first run shows "Windows protected your PC" and the user clicks "More info", then "Run anyway". Defender may warn again on new releases.

What to do: get a certificate (or Azure Trusted Signing) and set the `WINDOWS_SIGN_TEMPLATE` secret. `.github/workflows/release-windows.yml` already signs when that secret exists.

## 2. Update notice inside the app

What the user sees now: a new version needs a new `Setup.exe` from the Releases page. The release workflow already builds delta packages for Velopack.

What to do: check for updates with Velopack's `UpdateManager` against GitHub Releases and show a short notice in the panel, in Spanish, English and Portuguese. Do the same in the macOS app (see `apps/macos/TODO.md`, item 3).

## 3. Unsaved note on uninstall

What can happen: Velopack force-closes a running app on uninstall, so the app does not run its quit path (F16 saves the note on Salir). The note saves 400 ms after typing stops, so the risk is small.

How to check: open the Notes tab, type, uninstall at once, reinstall, and see whether the last characters are there.

## 4. Behaviors verified only by unit tests

F15 "Posponer 15 min", F21 the midnight rollover, and F22 with Windows "Animation effects" off have unit tests but no run on the real app.

How to check: press the bell, wait for the toast and press "Posponer 15 min" (a new toast comes 15 minutes later); keep the panel open across midnight; turn off Settings > Accessibility > Visual effects > Animation effects and open the panel and the capture window (no motion).

## 5. Changes that the macOS app has and Windows does not

The macOS branch `feat/macos-reorder-and-window` changes five behaviors. Windows still has the old behavior. This machine has no .NET, so the Windows side is not done.

- Manual order. The open list sorts by `position` only, not by level and due. A new priority goes to the end. On the first start, `AppStore.adoptManualOrder` writes the old level and due order into `position` one time, and sets the `manual_order` key in `app_state`. A drag starts only from the handle icon at the left of a row. During the drag, a line shows where the row lands, and the database gets one write on the drop.
- Row hover. The trash button stays visible while the pointer is on it. macOS uses a tracking area on the full row for this.
- Done detail. A click on a done row opens its detail. The controls are off, and "Regresar" restores the priority. Back returns to "Historial" when the detail opened from there.
- Desktop window. The footer button "Abrir en ventana" opens a resizable window: the list on the left and the detail on the right. The Notes tab fills the window.
- Development database. A Debug build uses `daily-zgt-dev.sqlite`, so a test run does not change the real data.
- Due-date filter. A filter on the due date replaces the tabs "Hoy · N" and "Semana · N". The options are Hoy, Mañana, Esta semana, Vencidas, Sin fecha, Todas, a picked day and a range. Hoy shows the groups "Vencidas", "Hoy" and "Sin fecha". On a single day, "‹" and "›" step one day. A filter that hides overdue priorities shows the link "N vencidas · Ver". The rules are in `DueFilter.swift` and `DueFilterLabels.swift`, with unit tests.
- Filter state. The `due_filter` key in `app_state` keeps the filter. The first start reads the old `open_scope` key: "week" gives Esta semana. The Notes tab keeps its own Hoy and Semana tabs in the `note_scope` key.
- List column. The UI does not read or write `priority.list` any more. The column stays in the database, and a new priority still gets `today`. The "Lista" row of the detail and the chip "De ayer" are gone.
- Counts, limit and done list. The menu bar count and title, and the limit of 5, use the open priorities that are overdue or due today. A priority with no due shows in Hoy but does not count. The limit blocks a new priority with no due or a due of today, and a due change into today. "Hechas", the footer and the history follow the date window of the filter: by `done_at`, in the day, the week or the range; Todas, Vencidas and Sin fecha use the last 24 h.
- Drag order. A drag reorders the rows inside one date group only.

After the Windows change, update the sort text in `apps/website/i18n.json` (key with "A priority sorts by level first"). That text is now wrong for macOS.
