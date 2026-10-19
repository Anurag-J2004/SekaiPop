# Matugen controls (Edit Desktop > THEME)

The **Matugen** theme takes the shell's colours from the wallpaper. These controls let you
steer how, right where the theme is picked, and the shell re-colours live as you go.
Issue [#28](https://github.com/Blapples/SekaiPop/issues/28).

## Using it

- Pick **Matugen** in Edit Desktop's THEME tab as usual. While it isn't the theme on, its
  tile has a small *tune* mark: it has options.
- Click it **again** (or the round tune key on its corner) and the tile row gives way to
  the controls. **Themes** (the first block) or **Esc** brings the tiles back.
- `qs -c sekaipop ipc call desktopedit matugen` goes straight there: it switches to the
  Matugen theme if needed and opens Edit Desktop with the controls up.

| Control | What it does |
|---|---|
| **Scheme** | matugen's `--type`: Tonal (the default), Vibrant, Expressive, Fidelity, Content, Neutral, Mono, Rainbow, Fruit salad. |
| **Seed** | Which of the wallpaper's colours leads. **Auto** is matugen's own pick; the swatches are the wallpaper's candidates (`matugen --show-source-colors`). |
| **Contrast** | matugen's `--contrast`, in five steps from −1 (softer) to +1 (sharper). |
| **Accents** | The shell's two accent colours (the stops of its gradient) as they are now. The pin keeps one fixed whatever the wallpaper says: the colour it has now, one of the wallpaper's, any hex, or one picked off the screen (`hyprpicker`). The pinned key unpins. |

While matugen re-runs, the first block says **Working** and the scheme in use shows the
busy glyph. When an accent is pinned, the Matugen tile and the first block wear a pin
badge. When `matugen` isn't installed, the tile says so (dashed, faded) and does nothing.

## Where it lives

| Piece | File |
|---|---|
| The knobs, as pure functions (schemes, contrast steps, cleaning, `--show-source-colors` parsing, pins) | `sekaipop/modules/common/functions/MatugenMath.js` |
| Running matugen with them, the wallpaper's candidates, "is it installed" | `sekaipop/services/ThemeService.qml` (`matugen*`), `sekaipop/scripts/theming/matugen-state.sh` (`apply … [seed] [contrast]`, `sources`, `installed`) |
| The settings | `matugen.scheme`, `matugen.seed` (−1 = Auto), `matugen.contrast`, `matugen.pinA`, `matugen.pinB` in `sekaipop/services/SettingsService.qml` |
| The controls | `sekaipop/modules/sekai/editMode/EditMatugenControls.qml` |
| The tile's states, the swap | `sekaipop/modules/sekai/editMode/EditThemeBoard.qml`, `EditPinBadge.qml` |
| Esc, the how-to lines | `sekaipop/modules/sekai/editMode/EditTray.qml` |
| The IPC | `sekaipop/services/EditMode.qml` (`openMatugen`, `matugenAsked`) |
| Tests | `sekaipop/tests/matugen-test/matugen_unit.js` |

Being settings, the knobs are saved, carried by **desktop presets**, and re-run matugen the
moment they change (`ThemeService.matugenTuning`). Pins don't re-run anything: they are put
on the palette afterwards (`MatugenMath.applyPins`), and only A and B change.

**Auto and the first swatch are the same colour.** matugen's own pick *is* its first
candidate (the script has always passed `--source-color-index 0`, since matugen 4 would
otherwise ask in a prompt). The difference is what happens on another wallpaper: Auto keeps
following the wallpaper's first colour, a picked swatch keeps its number. A number the new
wallpaper has no colour for counts as Auto.

## Where it departs from the handoff

The design is a Claude Design canvas (the "Wallpaper colours" page of *SekaiPop Keys in
Settings*), kept locally in `docs/handoffs/matugen-controls/`.

- **Rings.** The handoff draws every key and tile with a 3–4 px inner ring, the existing
  tiles included. The shelf's real keys and tiles have a thin one (`Pill`'s `ringWidth`
  counts from the outer edge, outline included), so the controls follow the shelf, to sit
  with the tiles and tabs next to them.
- **Scheme keys are 27 px tall, not 30**, and the Scheme, Seed and Contrast blocks keep
  16 px on both sides. As drawn, three rows of 30 px keys under the header ran past the
  bottom of the 138 px block, and the key rows 6–8 px past the right side.
- **Busy glyph.** The handoff's spinner is a CSS ring; the shell's busy look is the turning
  `sync` icon (`UpdatesBadge.qml`), used here too.
- **Font.** The handoff renders in Nunito as a stand-in; the shell's own font is used.
- **The tile's picture** stays the shell's existing drawing (the handoff redraws it a few
  pixels differently); only the new marks (tune, pin, missing) are added on top.
- **The "Needs matugen" tile** didn't exist before (the brief wrongly said it did): the
  shell now asks `matugen-state.sh installed` once at startup.

## What it doesn't do yet

- **GTK / Qt / KDE and the terminal follow the scheme only.** `system-theme.sh` and the
  app themes run matugen with `matugenType`, so a new scheme reaches them, but not the seed,
  the contrast or the pins: apps can keep the wallpaper's first colour while the shell leads
  with another.
- **The lockscreen's own wallpaper** (Separate lockscreen wallpaper) uses the scheme, the
  contrast and the pins, but always its own first colour: the seed is an index into the
  *desktop* wallpaper's colours.
- **Per monitor.** Everything here is one setting for the whole shell; a monitor with its own
  theme (issue #29) doesn't get its own knobs.
- **Installing matugen while the shell runs** isn't noticed until the shell restarts.
