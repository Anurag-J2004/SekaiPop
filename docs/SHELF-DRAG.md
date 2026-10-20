# Dragging widgets off the Edit Desktop shelf

In Edit Desktop's WIDGETS tab, a widget can be pulled off the shelf and dropped where it should go,
instead of being added at its first spot and then moved.

## Using it

- **Pull a slot up** off the shelf. The widget follows the pointer, as big as it will be on the
  card. Over the card it is upright with a mint outline: let go and it is put there, centred on the
  pointer, and selected for editing.
- **Already on the desktop?** The same pull moves it to where you let go. For a widget that can be
  on several monitors (the clock, the cards, the lyrics, plugins), it moves the copy on the monitor
  being edited, or adds a copy there.
- **Changed your mind?** Bring it back onto the shelf, let go of it out on the dark stage, or press
  **Esc**. Nothing changes.
- **The Image tile** makes a new empty frame where it is dropped.
- **Sticky Notes** arrange themselves, so dropping them just adds them.
- A **click** still adds (or edits) as before, and dragging **sideways** still scrolls the shelf.

Only onto the monitor the shelf is on. To put a widget on another monitor, make that monitor the
main one first (`qs -c sekaipop ipc call desktopedit main DP-2`) or use
`desktopedit movewidget <id> <monitor>`.

## How it works

| File                                              | What it does                                                                                       |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `modules/sekai/editMode/EditTraySlot.qml`         | Decides click, pull or scroll, starts the drag and reports where the pointer is.                   |
| `modules/sekai/editMode/EditDragGhost.qml`        | Draws the widget under the pointer, in a window of its own.                                        |
| `services/EditMode.qml`                           | `dragId` / `dragX` / `dragY` / `dragOver`, `beginDrag`, `moveDrag`, `endDrag`, `dropWidget`.        |
| `modules/common/functions/ShelfDragMath.js`       | The gesture rule, screen point to desktop point, the spot, the ghost's size. Tested in node.       |

**Click, pull or scroll.** The shelf is a sideways-scrolling `Flickable`, and it takes a press for
itself once the pointer has gone about 10 px sideways. So a pull has to be decided before that: it
is one as soon as the pointer has gone **5 px up**, at an angle steeper than about **31°**
(`PULL`, `PULL_SLOPE`). From a slot at the far end of the shelf the way to the card is up *and*
across, and that comes out as a pull. Anything flatter, or downward, is left to the shelf; a press
that moves less than 10 px is still a click. Once it is a pull, the slot's `MouseArea` sets
`preventStealing`, so the shelf can't take it back.

**Why a second window.** The shelf's window is only the strip along the bottom edge and cannot draw
above it. The press that started the drag keeps getting the pointer above the strip (a pressed
button holds the pointer on Wayland), so the slot can still follow it; the picture is drawn by
`EditDragGhost`, a full-screen Overlay window mapped only while a drag is on, with an empty input
mask so it never takes a click.

**Where it lands.** The ghost and the drop use the same maths as the card: `EditMode.cardRect()` is
where the shrunken desktop sits, and `ShelfDragMath.toDesktop()` turns the pointer into desktop
design pixels. `dropWidget()` first adds the widget through the ordinary `addWidget()` (so every
widget keeps its own rules about monitors and copies) and then gives it the spot, through whatever
that widget is placed with: its service's `setPosition`, `WidgetClones.setSpot` for a copy,
`ImageService.addEmpty` with a point, or a plugin's `PluginState`. The widget's own placement keeps
it on screen.

## Tests

```sh
node sekaipop/tests/shelf-drag-test/shelf_drag_unit.js
```

It checks the gesture rule (including that a pull is decided before the shelf's 10 px), the
point-on-card maths, the spot and the ghost's size, and that the pieces are wired together: the slot
starts and drops, Esc and closing Edit Desktop cancel, and the drop places every kind of widget.
