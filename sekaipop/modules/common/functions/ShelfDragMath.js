.pragma library

// Dragging a widget off Edit Desktop's shelf onto the desktop (EditTraySlot.qml starts it,
// EditDragGhost.qml draws it, EditMode.dropWidget() puts the widget down). Pure functions,
// unit-tested with node: tests/shelf-drag-test/shelf_drag_unit.js.
//
// The shelf scrolls sideways, so a press on a slot means one of three things, decided once
// the pointer has moved far enough:
//   up, steeper than PULL_SLOPE   "pull": the widget comes off the shelf and follows
//   anything flatter, or down     "scroll": left to the shelf (its Flickable takes it)
//   not far yet                   "": still a click
// A pull is decided after only PULL px up, earlier than the shelf's Flickable takes a press
// for itself (it starts a flick at about 10 px sideways): from a slot at the far end of the
// shelf, the way to the card is up AND across, and that has to come out as a pull.

// How far (design pixels) the pointer moves before the press is a drag and not a click.
var THRESHOLD = 10
// How far up a pull is recognised, and how steep it must be (up per sideways: 0.6 is about 31 degrees).
var PULL = 5
var PULL_SLOPE = 0.6

function gesture(dx, dy, threshold) {
    var t = typeof threshold === "number" ? threshold : THRESHOLD
    var ax = Math.abs(dx)
    var ay = Math.abs(dy)
    if (dy < 0 && ay >= Math.min(PULL, t) && ay >= ax * PULL_SLOPE)
        return "pull"
    if (ax < t && ay < t)
        return ""
    return "scroll"
}

// Where a point of the screen (real pixels, from the screen's top-left) lands on the desktop
// while Edit Desktop has shrunk it into its card. `rect` is EditMode.cardRect(w, h, ui):
// the card's top-left and its scale, at progress 1. The answer is in design pixels of the
// desktop (what widgets' spots are kept in), and `inside` says whether the point is on the
// card at all.
function toDesktop(px, py, w, h, ui, rect) {
    var s = rect.s > 0 ? rect.s : 1
    var k = ui > 0 ? ui : 1
    var rx = (px - rect.x) / s
    var ry = (py - rect.y) / s
    return {
        inside: rx >= 0 && ry >= 0 && rx <= w && ry <= h,
        x: rx / k,
        y: ry / k
    }
}

// The top-left spot that puts a widget of `ww` x `wh` (design pixels) centred on (cx, cy),
// kept wholly on a desktop of `roomW` x `roomH`. A widget bigger than the room sits at 0.
function spotFor(cx, cy, ww, wh, roomW, roomH) {
    var x = cx - ww / 2
    var y = cy - wh / 2
    x = Math.max(0, Math.min(x, roomW - ww))
    y = Math.max(0, Math.min(y, roomH - wh))
    return { x: Math.round(x), y: Math.round(y) }
}

// The ghost's size on screen (real pixels): the widget as big as it will be on the card, so
// what you drop is what you get. No picture yet (a widget that has never been drawn, the
// Image tile): a square of `fallback` design pixels.
function ghostSize(ww, wh, ui, cardScale, fallback) {
    var f = typeof fallback === "number" ? fallback : 96
    var w = ww > 1 ? ww : f
    var h = wh > 1 ? wh : f
    var k = (ui > 0 ? ui : 1) * (cardScale > 0 ? cardScale : 1)
    return { w: w * k, h: h * k }
}
