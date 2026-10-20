// Dragging a widget off Edit Desktop's shelf onto the desktop: the maths in
// modules/common/functions/ShelfDragMath.js, run in node, and the shell's files read as text
// to check the pieces are wired together (the slot starts it, EditMode drops it, the ghost
// draws it, Esc and closing the mode cancel it).
// Run: node shelf_drag_unit.js
const fs = require("fs"), assert = require("assert")
const locate = require("../lib/locate")
const D = require("../lib/shelfdragmath")
const read = f => fs.readFileSync(locate(f), "utf8")

// ---------- 1. click, pull or scroll ----------
const t = D.THRESHOLD
assert.strictEqual(D.gesture(0, 0), "", "no movement: still a click")
assert.strictEqual(D.gesture(3, -(D.PULL - 1)), "", "a little up, under PULL: still a click")
assert.strictEqual(D.gesture(t - 1, 0), "", "a little sideways, under the threshold: still a click")
assert.strictEqual(D.gesture(0, -D.PULL), "pull", "straight up, PULL px: the widget comes off the shelf")
assert.ok(D.PULL < t, "a pull is decided before the shelf's Flickable takes a sideways press (~10 px)")
assert.strictEqual(D.gesture(-9, -6), "pull", "up and across (from the far end of the shelf to the card): a pull")
assert.strictEqual(D.gesture(-t, -t), "pull", "exactly diagonal: a pull")
assert.strictEqual(D.gesture(t, -2), "scroll", "sideways: the shelf scrolls")
assert.strictEqual(D.gesture(-t * 2, -t), "scroll", "flatter than the slope: the shelf's")
assert.strictEqual(D.gesture(-20, -11), "scroll", "just under the slope: still a scroll")
assert.strictEqual(D.gesture(0, t), "scroll", "down is never a pull (there is nothing below the shelf)")
assert.strictEqual(D.gesture(0, -4, 3), "pull", "a smaller threshold is a smaller pull too")
// a real pointer arrives a few pixels at a time: a 30-degree-plus drag up-left is a pull before it
// has gone 10 px sideways, which is when the shelf would have taken it
for (const [sx, sy] of [[-2, -1.4], [-3, -2], [-1, -1]]) {
    let x = 0, y = 0, g = ""
    while (g === "") { x += sx; y += sy; g = D.gesture(x, y) }
    assert.strictEqual(g, "pull", "step " + sx + "," + sy + " pulls")
    assert.ok(Math.abs(x) < 10, "...before 10 px sideways (got " + x + ")")
}

// ---------- 2. a point on the shrunken card, in desktop design pixels ----------
// a 2560 x 1440 screen at shell scale 1.25, shrunk to a card at (200, 100), scale 0.5
const rect = { x: 200, y: 100, s: 0.5 }
let p = D.toDesktop(200, 100, 2560, 1440, 1.25, rect)
assert.deepStrictEqual(p, { inside: true, x: 0, y: 0 }, "the card's top-left is the desktop's")
p = D.toDesktop(200 + 1280 * 0.5, 100 + 720 * 0.5, 2560, 1440, 1.25, rect)
assert.deepStrictEqual(p, { inside: true, x: 1280 / 1.25, y: 720 / 1.25 }, "the card's middle is the desktop's middle, in design pixels")
p = D.toDesktop(200 + 2560 * 0.5, 100 + 1440 * 0.5, 2560, 1440, 1.25, rect)
assert.strictEqual(p.inside, true, "the far corner is still on it")
assert.strictEqual(D.toDesktop(199, 300, 2560, 1440, 1.25, rect).inside, false, "left of the card")
assert.strictEqual(D.toDesktop(500, 100 + 1440 * 0.5 + 1, 2560, 1440, 1.25, rect).inside, false, "below the card (the shelf)")
assert.deepStrictEqual(D.toDesktop(10, 20, 100, 100, 0, { x: 0, y: 0, s: 0 }), { inside: true, x: 10, y: 20 }, "a zero scale is taken as 1, never a division by zero")

// ---------- 3. the spot: centred on the pointer, kept on the desktop ----------
assert.deepStrictEqual(D.spotFor(500, 400, 200, 100, 2048, 1152), { x: 400, y: 350 })
assert.deepStrictEqual(D.spotFor(20, 10, 200, 100, 2048, 1152), { x: 0, y: 0 }, "near the top-left: kept on it")
assert.deepStrictEqual(D.spotFor(2040, 1150, 200, 100, 2048, 1152), { x: 1848, y: 1052 }, "near the bottom-right: kept on it")
assert.deepStrictEqual(D.spotFor(100, 100, 3000, 100, 2048, 1152), { x: 0, y: 50 }, "wider than the desktop: at its left edge")
assert.deepStrictEqual(D.spotFor(300.4, 200.6, 0, 0, 2048, 1152), { x: 300, y: 201 }, "no size known: the pointer itself, rounded")

// ---------- 4. the ghost is as big as the widget will be on the card ----------
assert.deepStrictEqual(D.ghostSize(320, 276, 1.25, 0.5), { w: 200, h: 172.5 })
assert.deepStrictEqual(D.ghostSize(0, 0, 1, 0.5, 96), { w: 48, h: 48 }, "no picture: the fallback square")
assert.deepStrictEqual(D.ghostSize(100, 100, 0, 0), { w: 100, h: 100 }, "bad scales are taken as 1")

// ---------- 5. the pieces are wired together ----------
const slot = read("modules/sekai/editMode/EditTraySlot.qml")
assert.ok(/SDM\.gesture\(/.test(slot), "the slot decides click / pull / scroll with SDM.gesture")
assert.ok(/EditMode\.beginDrag\(root\.widgetId\)/.test(slot) && /EditMode\.endDrag\(true\)/.test(slot), "the slot starts and drops the drag")
assert.ok(/preventStealing: area\.gesture === "pull"/.test(slot), "a pull can't be taken by the shelf's Flickable")
assert.ok(/if \(area\.gesture !== ""\)[\s\S]{0,80}return/.test(slot), "a drag is not also a click")
const edit = read("services/EditMode.qml")
for (const fn of ["beginDrag", "moveDrag", "endDrag", "dropWidget"])
    assert.ok(new RegExp("function " + fn + "\\(").test(edit), "EditMode." + fn + "()")
const close = edit.slice(edit.indexOf("function close()"))
assert.ok(close.slice(0, close.indexOf("\n    }\n")).includes("root.endDrag(false)"), "closing Edit Desktop cancels a drag")
const drop = edit.slice(edit.indexOf("function dropWidget("))
const dropBody = drop.slice(0, drop.indexOf("\n    }\n"))
assert.ok(dropBody.includes("root.addWidget(id)"), "a drop adds through addWidget, so every widget's own rules still apply")
for (const what of ["WidgetClones.setSpot", "TodoService.setPosition", "VisualizerService.setPosition", "ImageService.addEmpty", "PluginService.stateFor"])
    assert.ok(dropBody.includes(what), "dropWidget places with " + what)
const tray = read("modules/sekai/editMode/EditTray.qml")
const esc = tray.slice(tray.indexOf("Keys.onEscapePressed"))
assert.ok(esc.slice(0, 300).includes("EditMode.endDrag(false)"), "Esc cancels a drag first")
assert.ok(/EditDragGhost \{\}/.test(read("shell.qml")), "shell.qml has the ghost window")
const ghost = read("modules/sekai/editMode/EditDragGhost.qml")
assert.ok(/mask: Region \{\}/.test(ghost), "the ghost takes no input")

console.log("shelf_drag_unit: all checks passed")
