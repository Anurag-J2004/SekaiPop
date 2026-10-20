# Changelog

## Unreleased
- Wallpapers › Wallhaven: the sort (Top and its period, Latest, Views, Favourites, Random) and the filters are kept again; every choice snapped back to the default because their settings had lost their defaults in a merge.
- Settings > Desktop > Plugins: every installed plugin, whether it is on the desktop and on which monitors, which secrets it found (never their values, only where to put a missing one), and the folders that did not load, in plain words with who has to fix them. Open a plugin to change its settings with the shell's own controls; the widget redraws as you go, and a changed setting can be reset. A plugin can describe its settings with the optional `settingsInfo` (labels, groups, ranges, choices) and `groups`; one without still gets a form. A selected plugin widget in Edit Desktop has a Settings key that opens it there (issue #30; docs/PLUGIN-SETTINGS.md).
- Edit Desktop: pull a widget up off the shelf and drop it where it should go. It follows the pointer as big as it will be on the card and lands centred where you let go; one already on the desktop moves there. Back on the shelf, out on the dark stage or Esc puts it back. Clicking still adds, and dragging sideways still scrolls the shelf (docs/SHELF-DRAG.md).
- Desktop widget plugins: a widget can live in its own folder (its own repo) in `~/.config/sekaipop/plugins/` and plug in. The shell places it, drags it, copies it to other monitors, hides it in Focus Mode and keeps it in presets like the built-in widgets; the plugin only draws, and gets the theme, its settings and its secrets (API tokens from the environment or a file, never saved by the shell) through one `host` object. A plugin that is broken or written for another plugin api is skipped with one notification. `ipc call plugins list | reload | toggle | set | resetPosition` (issue #30; docs/PLUGINS.md; example in examples/plugins/hello-clock).
- Themes: one theme per monitor (Settings > Desktop). With it on, the theme picker sets the monitor it is open on; the bar and its popups, the dock, the widgets and the Quick Panel on that monitor wear it, and a monitor on Matugen takes its colours from its own wallpaper. The first monitor sets the shell's theme (apps, lockscreen); picking its theme on another monitor makes that one follow it again (issue #29; docs/PER-MONITOR-THEME.md).
- Phone: the home screen (Quick Panel) has a wallpaper too, behind see-through cards. Settings > General > Quick Panel > Phone wallpaper: Off, Desktop (the monitor's wallpaper) or A picture of your own, the same on the Quick and Apps screens (it replaces the Apps screen's on / off switch, whose choice carries over). An empty notifications card says so, in one quiet line (issue #41; docs/PHONE-WALLPAPER.md).
- Privacy badge: an app recording what is playing (a screen recorder with sound, a VNC or streaming audio feed) shows as desktop audio, with its own icon, instead of "Microphone in use"; muting the mic no longer hides it, since that doesn't stop it.
- Notifications: the phone that rises for a notification can be put away without opening it: swipe it down or middle-click it (the notification stays in the list), or right-click it to remove the notification too, anywhere on the phone. A click, or resting the pointer on its card for a second (it was a fifth of a second, which opened it under anyone aiming at it), still opens the panel (issue #42).
- Phone: clicking beside the Quick Panel's phone closes it everywhere, including the empty corners of the box around the tilted phone, which used to swallow the click. The click follows the phone's real outline, in 2.5D and 2D (issue #47; docs/PHONE-CLICK-AWAY.md).
- Wallpapers: Wallhaven as a second source (My folder | Wallhaven, or Ctrl+Tab). Search it, sort it (Top over a day to a year, Latest, Views, Favourites, Random), filter it (categories, shape, minimum size, colour), and set a picture: it is downloaded into your wallpaper folder first, with progress, and Esc stops it. SFW only, no account. `ipc call wallpaperpicker wallhaven` opens it there (docs/WALLHAVEN.md).
- Edit Desktop > THEME: the Matugen theme has controls. Click its tile again (or its tune key) for the scheme, which wallpaper colour leads, the contrast, and pins that keep an accent colour fixed whatever the wallpaper says; the shell re-colours live, presets carry them, Esc goes back. `ipc call desktopedit matugen` opens them directly. The tile says so when matugen isn't installed (issue #28; docs/MATUGEN-CONTROLS.md).
- Presets: wearing a preset can be undone. The look it replaced (settings, pictures, image frames and sticky notes) is kept, and an UNDO tile on the PRESETS tab puts it back, then turns into REDO. Deleting a preset can be undone too, for ten minutes (UNDELETE, the last one deleted). The save tile says NOT SAVED when no preset is the current look. IPC: `presets undo`, `presets undelete`.
- Settings > Keys: change what each SekaiPop shortcut does. Click an action, press the new keys, and it works straight away; conflicts ask first, and every change can be reset. Works with the Lua config and with `hyprland.conf` (issue #16).
- Phone: the turn between the Quick Panel and Settings / Wallpapers (both ways) is smooth instead of a snap: one 200 ms speed for every turn of the phone (Settings, Wallpapers, Apps), but on a soft curve, with the two screens dissolving over about 70 - 100 ms instead of swapping in 3 frames, and the turn waits for the phone to be redrawn before it moves so a slow first frame does not skip it.
- Phone: the slide between Quick and Apps is the same 200 ms, softer, with a visible cross-fade.
- Phone: SUPER + N while the Settings (or Wallpapers) are up turns the phone into the Quick Panel, whichever way the Settings were opened; it used to cut or close them.
- Apps: the calculator, clipboard, colour, emoji and web cards fade in over the grid (and out again) instead of replacing it in one frame; system-action rows fade and the grid glides to make room; the card is built before the slide starts and stays until the screen has gone.
- Dock: Reveal zone setting (Auto-hide / Smart hide); pinned apps can be switched on or off in Edit Desktop > DOCK > APPS.
- Notifications: clicking runs the app's default action (Discord opens the message); middle click hides, right click removes; Quiet while fullscreen option.
- Apps: two-line names, a letter icon for apps with no icon, the list refreshes when the Apps screen opens.
- Shadows: tiled windows get shadows again with a stronger default; the phone casts a soft, airbrushed shadow (one small picture, no blur); Settings > Quick > Phone shadow switches it off.
- Lockscreen: optional lyrics under the clock (gacha style; Settings > General).

## 1.0.0 - First release
- Themes: new Monochrome theme and a Custom color theme (make your own palette).
- Windows cursor porter: import .cur / .ani packs (animated too); they show up in Settings > Icons & cursor.
- Desktop widgets: Lyrics, Sticky Notes, Custom Image and Color Palette.
- Capsule bar and dock app style.
- Dock tools.
- Handheld EQ.
- The shell tells you when there is an update.
- Wallpaper folder picker.
- The power button menu now sits at the side of the phone.
- Configurable monitor displays via nwg-displays.
- On-screen keyboard.
- UI consistency adjustments.
- Bug fixes.
