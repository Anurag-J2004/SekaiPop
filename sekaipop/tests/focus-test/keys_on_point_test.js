// The desktop widgets that can take the keyboard ask for it only under the pointer or
// while typing (KeysOnPoint), never just because Focus Mode mapped them again: an
// always-OnDemand window took the keyboard from a launcher opened right after an empty
// workspace came up (issue #72).
//   node tests/focus-test/keys_on_point_test.js
const assert = require("assert")
const fs = require("fs")
const path = require("path")

const dir = path.join(__dirname, "..", "..", "modules", "sekai", "desktopWidgets")
const read = f => fs.readFileSync(path.join(dir, f), "utf8")

const helper = read("KeysOnPoint.qml")
assert.ok(/readonly property bool wanted: hover\.hovered \|\| root\.Window\.active/.test(helper), "KeysOnPoint wants the keyboard under the pointer or while active")
assert.ok(/HoverHandler/.test(helper), "KeysOnPoint watches the pointer with a HoverHandler")

let n = 0
for (const f of fs.readdirSync(dir).filter(f => f.endsWith(".qml"))) {
    const src = read(f)
    const m = /WlrLayershell\.keyboardFocus:([^\n]*(?:\n\s+[?:][^\n]*)?)/.exec(src)
    if (!m || !/OnDemand/.test(m[1]))
        continue
    if (f === "LyricsSources.qml" || f === "KeysOnPoint.qml")
        continue // its picker opens on request; KeysOnPoint is the helper (its doc shows the use)
    assert.ok(/!keys\.wanted/.test(m[1]), f + ": OnDemand only while KeysOnPoint wants it")
    assert.ok(/KeysOnPoint \{\s*id: keys/.test(src), f + " has a KeysOnPoint named keys")
    n++
}
assert.strictEqual(n, 4, "the four widgets that take the keyboard (to-do, calendar, palette, notes)")
console.log("keys_on_point: all passed (" + n + " widgets)")
