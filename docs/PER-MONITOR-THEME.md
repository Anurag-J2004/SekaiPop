# One theme per monitor

Each monitor can wear its own theme on what sits on it: the bar and its popups, the dock,
the desktop widgets, the Quick Panel / Settings phone when it opens there. Apps (GTK, Qt,
the terminal, window borders) keep the one theme, since that is set session-wide.
Issue [#29](https://github.com/Blapples/SekaiPop/issues/29).

## Using it

- **Settings > Desktop > One theme per monitor** (`theme.perMonitor`), next to *One wallpaper
  per monitor* and working the same way. Off (the default), nothing changes: one theme
  everywhere.
- On, a theme picker sets the **monitor it is open on**: Edit Desktop's THEME tab, and
  Settings > Quick > Colours. Each shows that monitor's theme as the one picked.
- The **main monitor** (the first; the same one the wallpaper colours come from) sets the
  shell's theme, the one apps, Settings' own colours elsewhere and the lockscreen wear.
  Every other monitor follows it until it picks its own.
- On another monitor, picking the theme the main monitor wears makes it **follow the main
  monitor again**.
- A monitor on **Matugen** takes its colours from **its own wallpaper** (with *One wallpaper
  per monitor* on and a different picture there), with the same scheme and contrast as the
  main monitor and the same pinned accents. One showing the main monitor's picture simply
  wears the main colours.
- The choices are saved (setting `theme.screens`, `{ monitor: theme }`) and carried by
  desktop presets.
- `qs -c sekaipop ipc call theme screens` says what each monitor wears;
  `ipc call theme screen <monitor> <theme>` sets one (`""` to follow the main monitor).

## How it works

`Theme` used to be one object every file read. Now:

- **`ThemeSet.qml`** is what `Theme.qml` was: a palette (`pal`) and everything worked out
  from it (surfaces, lines, chips, the capsule bar's colours...) and the sizes. Written once.
- **`Theme`** is the shell's own ThemeSet, plus **`Theme.of(window or screen)`**: the ThemeSet
  of that window's monitor. With the setting off, or for a monitor with no theme of its
  own, it is `Theme` itself; otherwise a ThemeSet made for that monitor (once, then kept),
  its `pal` bound to `ThemeService.paletteFor(monitor)`.
- **Every file drawn on a monitor** reads `mt` instead of `Theme`:
  `readonly property var mt: Theme.of(QsWindow.window)` in an Item, `Theme.of(screen)` in a
  PanelWindow's own file, `Theme.of(host.parentWindow)` in the bar popups' frame
  (`SekaiPopup.qml`). An inline component declares its own; a file whose root is another
  converted file inherits it. A QML property can't start with a capital, hence `mt`.
- **`ScreenThemes.js`**: which monitor wears what, where a pick goes, who needs a matugen run
  of their own (pure, unit-tested).
- **`ThemeService.qml`**: `themeFor`, `paletteFor`, `pickTheme`, `setScreenTheme`, and the
  per-monitor matugen runs (`screen-<name>.json` beside `colors.json`).

The conversion (`Theme.` to `mt.` in ~200 files) was done by a script, not by hand:
comments and strings keep `Theme.`, and `Theme.of` / the file `Theme.qml` are left alone.
Tests that read QML as text go through `tests/lib/themetext.js`, which reads `mt.` as
`Theme.`, so they still say what they meant.

## What stays on the shell's theme

- **Apps**: GTK / Qt / KDE colours, the terminal, Hyprland's borders are one setting for the
  whole session.
- **The lockscreen** has its own palette already (`LockPalette`, its own wallpaper's
  colours).
- **The welcome screen** (kept free of Quickshell on purpose; `welcome_unit` checks it).
- **Files whose root isn't drawn on a monitor**: the region selector, the on-screen
  keyboard, the reload popup, the cheat sheet, the overview's wrapper and the Quick Panel's
  wrapper (what they hold, the phone's face, is converted).

## What it doesn't do yet

- **The Matugen controls' preview** (Edit Desktop > THEME > Matugen) shows the main
  monitor's matugen colours, even when opened on another monitor: the knobs are the shared
  matugen settings.
- **Light / Dark / Darker** is one mode for every monitor.
