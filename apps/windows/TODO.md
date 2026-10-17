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
