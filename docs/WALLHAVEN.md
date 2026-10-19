# Wallhaven in the Wallpapers picker

The picker shows the pictures in your wallpaper folder. Its second source is
[Wallhaven](https://wallhaven.cc): search it, browse the results in the same wheel or grid, and
set one. Setting it **downloads it into your wallpaper folder** first, so from then on it is an
ordinary wallpaper: per monitor, lockscreen, presets and the Matugen colours all just work.

## Using it

- **My folder | Wallhaven**, the switch beside the "Wallpapers" title, or **Ctrl+Tab**.
  The picker opens on your folder every time, except
  `qs -c sekaipop ipc call wallpaperpicker wallhaven`, which opens it on Wallhaven.
- **Search** as you would on the site: words or tags, `-tag` to leave one out, `@user` for
  someone's uploads, `like:<id>` for similar pictures. With no search it shows the month's top.
- **Sort**: Relevance (needs a search), Top (over a day ... a year), Latest, Views,
  Favourites, Random.
- **Filters** (the badge says how many are changed): categories (General, Anime, People), shape
  (Landscape by default, or an exact ratio, or any), minimum size (this monitor's by default),
  and one of Wallhaven's colours. They apply as you pick, and the sort and filters are
  remembered (they are not part of a desktop preset).
- In the **viewer**: category, size, file type, the picture's colours, views and favourites;
  **Set as Desktop / Lockscreen** (downloads first, with its progress on the key and on the
  picture; **Esc** stops it), **Save to folder** without setting it, and **wallhaven.cc**.
- A picture you already have (any `wallhaven-<id>` file in the folder, including ones saved
  from the site, which uses the same names) has a folder badge and sets at once.

SFW only, with no account or API key.

## How it works

| Piece | File |
|---|---|
| The rules: the search URL, reading the answer, the filters and their wording, file names, the rate limit | `sekaipop/modules/common/functions/WallhavenMath.js` |
| Fetching: search, download (atomic; stopped, it takes curl and the `.part` with it), what is already there | `sekaipop/scripts/wallpapers/wallhaven.sh` |
| Searching, paging, downloading, progress, cancel, the retry countdown, the remembered filters | `sekaipop/services/WallhavenService.qml` |
| The picker: source, gallery, toolbar, messages, viewer | `sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml` and `Wallhaven*.qml`, `WallpaperSourceSwitch.qml` |
| Tests | `sekaipop/tests/wallhaven-test/wallhaven_unit.js` |

On Wallhaven the gallery's list (`matched`) holds the results in the same shape as the
folder's pictures, each with a `wh` (the result). A result's `filePath` is where its download
is once there is one, so the "applied" check and the lockscreen badge work for downloaded ones
like any other picture.

- **Never a blank screen.** A new search keeps the previous results on screen, dimmed, until
  the new ones arrive; with nothing yet, the wheel or the grid shows empty frames.
- **Paging.** 24 pictures a page; the next one loads as you reach the end of the grid, or when
  the wheel comes to rest near its end. On Wallhaven the wheel doesn't wrap round (the list is
  open-ended) and keeps its place when a page is added.
- **Rate limit.** Wallhaven allows 45 requests a minute; the service keeps under 40 by itself.
  If Wallhaven still says no, the message counts down to trying again.
- **Settings**: `wallhaven.sort`, `.topRange`, `.categories`, `.shape`, `.atLeast`, `.colour`.

## Where it departs from the handoff

The design is a Claude Design canvas (the "Wallhaven" page of *SekaiPop Keys in Settings*),
kept locally in `docs/handoffs/wallhaven/`.

- **Only what is new was built.** The handoff redraws the whole picker (title, clock, toolbar,
  grid cells, viewer). The picker's existing parts stay as they are: its title key, its cells
  (the caption shows on hover, the "applied" check top-right), its viewer layout and keys.
- **Everything with words in it is sized by its words.** The handoff gave several keys and
  chips fixed widths too narrow for their labels ("Clear the filters", "Save to folder",
  "This screen · 2560×1440"...). Here chips, the source switch and the Filters key measure their
  text, the Sort chip grows past its 152 px when a label needs it ("Top · 6 months"), the
  viewer's big keys shrink their text rather than run past the key, and the search field's
  placeholder ends in "..." at its edge (every search field).
- **The viewer's panel** stacks for a Wallhaven picture (each piece below the one above it),
  instead of the folder viewer's fixed heights, so the extra details can't overlap the keys.
- **No separate loading grid.** The handoff's "first page loading" is a grid of empty cards;
  here the empty frames are in whichever look is on (the wheel's arc too).
- **Busy glyph.** The shell's turning `sync` icon, as elsewhere, for the handoff's CSS spinner.
- **Downloads go into the folder itself**, not a subfolder: the picker lists only the folder.

## What it doesn't do yet

- **No NSFW / account.** Purity is always SFW and there is no API key setting.
- **Subfolders.** The folder listing isn't recursive (a separate change, if wanted).
- **Tags in the viewer.** Wallhaven has them per picture (one more request each); not shown.
- **The wheel's panel** shows the name ("#id") and the set keys, not the handoff's chips under
  it; the viewer has them.
- **Progress** comes from the downloaded file's size a few times a second, so it moves in steps.
