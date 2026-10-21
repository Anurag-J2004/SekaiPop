// node tests/keybinds-test/keybinds_layout_unit.js   (run from the sekaipop folder)
// The keyboard slab's board maths: every row is 60 columns long, what a layer shows, and the list.
const fs = require("fs")
const path = require("path")
const read = f => fs.readFileSync(path.join(__dirname, "../../modules", f), "utf8")
const kbSrc = read("common/functions/KeyBinds.js").replace(".pragma library", "")
const KB = new Function(kbSrc + "; return { rows, comboOf, sentence, isHardware, modNames, matches, IGNORED, SHIFT, CTRL, ALT, SUPER }")()
const klSrc = read("sekai/keybinds/KeybindsLayout.js").replace(".pragma library", "").replace(/^\.import.*$/m, "")
const KL = new Function("KB", klSrc + "; return { ROWS, COLS, MOUSE, layerMap, hit, colorOf, groupOf, shortOf, listRows, layerName }")(KB)

let fails = 0
const eq = (a, b, msg) => { const x = JSON.stringify(a), y = JSON.stringify(b); if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) } }

KL.ROWS.forEach((r, i) => {
    eq(r.reduce((n, k) => n + k.w, 0), KL.COLS, "row " + i + " is " + KL.COLS + " columns")
    eq(r[r.length - 1].x + r[r.length - 1].w, KL.COLS, "row " + i + " ends on the edge")
})
eq(KL.ROWS[1][1].x, 6, "Q starts after Tab")

const lua = (key, modmask, description) => ({ dispatcher: "__lua", arg: "1", key, modmask, keycode: 0,
    has_description: true, description, submap: "", mouse: false, locked: false })
const binds = [
    lua("N", KB.SUPER, "Shell: Toggle quick panel"),
    lua("Q", KB.SUPER, "Windows: Close window"),
    lua("A", KB.SUPER | KB.SHIFT, "Shell: Toggle apps"),
    lua("XF86AudioMute", 0, "Media: Toggle mute"),
    Object.assign(lua("mouse:272", KB.SUPER, "Windows: Move window"), { mouse: true })
]
const rows = KB.rows(binds, {})
const map = KL.layerMap(binds, rows, KB.SUPER)
eq(map.n.kind, "action", "N is an action")
eq(map.n.id, "quickpanel", "N is the quick panel")
eq(map.n.short, "Quick", "N's short label")
eq(map.q.kind, "hyprland", "Q is a Hyprland bind")
eq(map.q.group, "Windows", "Q's group")
eq(map.q.short, "Close", "Q's short label")
eq(map.a, undefined, "SUPER+SHIFT+A is on another layer")
eq(map["xf86audiomute"], undefined, "hardware keys are left out")
eq(KL.hit(map, KL.MOUSE[0]).name, "Move window", "the mouse key reads its bind")
eq(KL.hit(map, { id: "N" }).id, "quickpanel", "hit is case-insensitive")
eq(KL.layerMap(binds, rows, KB.SUPER | KB.SHIFT).a.id, "launcherphone", "the SUPER+SHIFT layer")
eq(KL.layerMap(binds, rows, 0).n, undefined, "the empty layer")
eq(KL.listRows(rows, "Shell", "").every(r => r.group === "Shell"), true, "the Shell group")
eq(KL.listRows(rows, "Shell", "lock").map(r => r.id), ["clock", "lock"], "a search crosses groups (\"clock\" has \"lock\" in it too)")
eq(KL.layerName(KB.SUPER | KB.CTRL), "CTRL + SUPER", "layer name")
eq(KL.groupOf("Windows (more): Focus"), "Windows", "group of a description")
console.log(fails === 0 ? "ok" : fails + " failed")
process.exit(fails === 0 ? 0 : 1)
