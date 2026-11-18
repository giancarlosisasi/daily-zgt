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
- Filter state. The `due_filter` key in `app_state` keeps the filter. The first start reads the old `open_scope` key: "week" gives Esta semana.
- List column. The UI does not read or write `priority.list` any more. The column stays in the database, and a new priority still gets `today`. The "Lista" row of the detail and the chip "De ayer" are gone.
- Counts, limit and done list. The menu bar count and title, and the limit of 5, use the open priorities that are overdue or due today. A priority with no due shows in Hoy but does not count. The limit blocks a new priority with no due or a due of today, and a due change into today. "Hechas", the footer and the history follow the date window of the filter: by `done_at`, in the day, the week or the range; Todas, Vencidas and Sin fecha use the last 24 h.
- Drag order. A drag reorders the rows inside one date group only.
- Rich note field. The task note is a Markdown field that styles each block while you type, like Notion. It knows headings 1 to 3, paragraphs, bullets (Tab and Shift+Tab nest them), numbered lists (a nested list starts at 1), checkboxes, quotes, fenced code blocks, inline code, a divider, bold, italic, strikethrough, links, tables and images. The heading and quote markers stay hidden, also on the caret line. Backspace right after a block prefix turns the block into a paragraph. "[ ] " at the line start becomes "- [ ] ". Cmd+B, Cmd+I and Cmd+K act on the focused note only. The stored value stays plain Markdown in `priority.note`.
- Image table. The migration `003_add_image` adds `image` (`id` TEXT uuid, `mime` "image/png" or "image/jpeg", `width`, `height`, `bytes` BLOB, `created_at`). A note refers to an image as `![](zgt-image:<id>)`. Windows must read the bytes of that row to show the image. A pasted image is at most 2400 px on its long edge: PNG when it has alpha, JPEG at quality 0.85 when it does not. At launch the app deletes images older than one day that no `priority.note`, no `note.body` and no `note_item.body` refers to.
- Image block. A line that holds only `![](zgt-image:<id>)` is an image block, also with no blank line before or after it. Windows must show that line as a block image at the width of the field, not as inline text.
- Notes as a list. The Notes tab is a list of notes, not one note for each day and each week. "Nueva nota" (and Cmd+N on the Notes tab) adds a note and opens it with the caret in the rich note field. A note has no title column: the row shows the first line of the Markdown as the title, with the markers removed, and the next line as a dim preview. The right side shows the time for a note of today, else the weekday and day ("lun 16"), else the day and month. The list sorts newest first, with no drag order. The detail shows "Creada mar 17 nov · 16:20 · Editada hace 5 min", the field and "Se guarda al escribir.". A note that is empty when the person leaves it goes away. Delete works from the row (trash on hover) and from the detail. The undo bar shows "Borrada: <title>" with "Deshacer".
- Note table. The migration `004_add_note_item` adds `note_item` (`id` TEXT uuid, `body` TEXT, `created_at`, `updated_at`) and an index on `created_at`. It copies each old `note` row that has text into one `note_item` row with the same body. Its `created_at` is the start of the day, or the Monday of the ISO week, and its `updated_at` is the old one. A period that does not read gives `created_at` = `updated_at`. The old `note` table stays, and the app does not write it any more.
- Creation-date filter. The Notes tab uses the filter header and popover of priorities on `created_at`. The options are Todas, Hoy, Ayer, Esta semana, a picked day and a range. The subtitle says "creadas" ("martes 17 nov · creadas hoy"). "›" does not step past today. A new note under a filter that does not hold today switches the filter to Hoy. The `note_filter` key in `app_state` keeps the filter. The first start reads the old `note_scope` key one time: "week" gives Esta semana. The empty lines are "Sin notas de hoy.", "Sin notas de esta semana.", "Sin notas del jueves 19 nov.", "Sin notas en este rango." and "Sin notas.".
- Due text under a day header. In a group whose header names one day (Hoy, Mañana, each day group, and the list of a single-day filter), a row shows only the time ("17:00", not "Hoy 17:00"). "Vencida" and "En N min" do not change.
- Soft delete. The migration `005_add_soft_delete` adds `deleted_at` TEXT (NULL means live) to `priority` and `note_item`. A delete sets `deleted_at` and keeps the row, its subtasks and its events. Each live read skips a row with `deleted_at`: the lists, "Hechas", the history, the counts, the menu bar title, the limit, the alert plan and the repeat copies. A deleted open copy of a daily priority stops its series; "Borrar para siempre" on that copy sets the series to `none`, as the old hard delete did. An empty note still goes away for ever. The image cleanup keeps images that a deleted row uses.
- Eliminadas section. A collapsed "Eliminadas N" section shows under "Hechas" and under the notes list. It lists each deleted item, newest first, with no date filter. A row shows the title, the delete time, the "Restaurar" key and a trash button on hover. The trash asks "¿Borrar para siempre?" with "Cancelar" and "Borrar", and then deletes the row and its cascades. A click on a row opens a read-only detail with "Restaurar". The `deleted_open` key in `app_state` keeps the open state of the section. The note undo bar "Deshacer" clears `deleted_at`.

After the Windows change, update the sort text in `apps/website/i18n.json` (key with "A priority sorts by level first"). That text is now wrong for macOS.
