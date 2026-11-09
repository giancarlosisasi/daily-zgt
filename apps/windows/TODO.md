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

- Manual order. The open list sorts by `position` only, not by level and due. A new priority goes to the end. On the first start, `AppStore.adoptManualOrder` writes the old level and due order into `position` one time, and sets the `manual_order` key in `app_state`. Drag a row onto another row to move it.
- Row hover. The trash button stays visible while the pointer is on it. macOS uses a tracking area on the full row for this.
- Done detail. A click on a done row opens its detail. The controls are off, and "Regresar" restores the priority. Back returns to "Historial" when the detail opened from there.
- Desktop window. The footer button "Abrir en ventana" opens a resizable window: the list on the left and the detail on the right. The Notes tab fills the window.
- Development database. A Debug build uses `daily-zgt-dev.sqlite`, so a test run does not change the real data.

After the Windows change, update the sort text in `apps/website/i18n.json` (key with "A priority sorts by level first"). That text is now wrong for macOS.
