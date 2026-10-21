.pragma library
.import "../../common/functions/KeyBinds.js" as KB

// The keyboard slab's data, as plain numbers and strings (no Quickshell imports; tests/keybinds-test
// runs it in node). Everything here is the board's maths; KeybindsPanel.qml has the state.
//
//   ROWS           the five rows of the board; a key is { id, label, w, x, mod, bindable }
//                  `id` is the key as Hyprland names it ("A", "Tab", "slash"), `w` and `x` are in
//                  columns of COLS (so every row is exactly COLS long and the edges line up),
//                  `mod` is the modifier bit a Super / Ctrl / Alt / Shift key stands for.
//   layerMap(...)  what is on every key while a set of modifiers is held:
//                  { "<key lower-cased>": { kind: "action" | "hyprland", id, name, group, short } }
//   hit(map, key)  the entry a board key shows, or undefined
//   colorOf(...)   the key colour of a group
//   listRows(...)  the rows the List view shows

var COLS = 60

// ===== the board =====
function K(id, label, w) { return { id: id, label: label, w: w, x: 0, mod: 0, bindable: true } }
function M(mod, label, w) { return { id: "", label: label, w: w, x: 0, mod: mod, bindable: false } }
function X(label, w) { return { id: "", label: label, w: w, x: 0, mod: 0, bindable: false } }

function run(chars, upper) {
    var out = []
    for (var i = 0; i < chars.length; i++) {
        var c = chars.charAt(i)
        out.push(K(upper ? c.toUpperCase() : c, c.toUpperCase(), 4))
    }
    return out
}

var ROWS = [
    [X("Esc", 4)].concat(run("1234567890", false), [K("minus", "-", 4), K("equal", "=", 4), K("BackSpace", "Bksp", 8)]),
    [K("Tab", "Tab", 6)].concat(run("qwertyuiop", true), [K("bracketleft", "[", 4), K("bracketright", "]", 4), K("backslash", "\\", 6)]),
    [X("Caps", 7)].concat(run("asdfghjkl", true), [K("semicolon", ";", 4), K("apostrophe", "'", 4), K("Return", "Enter", 9)]),
    [M(KB.SHIFT, "Shift", 9)].concat(run("zxcvbnm", true), [K("comma", ",", 4), K("period", ".", 4), K("slash", "/", 4), M(KB.SHIFT, "Shift", 11)]),
    [M(KB.CTRL, "Ctrl", 5), M(KB.SUPER, "Super", 5), M(KB.ALT, "Alt", 5), K("space", "", 23),
     M(KB.ALT, "Alt", 5), M(KB.CTRL, "Ctrl", 5), K("Left", "\u2190", 4), K("Down", "\u2193", 4), K("Right", "\u2192", 4)]
]

;(function () {
    for (var r = 0; r < ROWS.length; r++) {
        var at = 0
        for (var i = 0; i < ROWS[r].length; i++) {
            ROWS[r][i].x = at
            at += ROWS[r][i].w
        }
    }
})()

// The mouse keys under the board (each is one or two Hyprland key names) and the hardware
// keys beside them, which no layer changes and nothing here rebinds.
var MOUSE = [
    { label: "LMB", ids: ["mouse:272"] },
    { label: "RMB", ids: ["mouse:273"] },
    { label: "MMB", ids: ["mouse:274"] },
    { label: "Wheel", ids: ["mouse_down", "mouse_up"] }
]
var MEDIA = [{ label: "Vol" }, { label: "Play" }, { label: "Bright" }]

// ===== names and colours =====
var SHORT = {
    launcherphone: "Apps", quickpanel: "Quick", overview: "Overview", settings: "Settings",
    cheatsheet: "Cheat", keyboard: "Kbd", eq: "EQ", gamemode: "Game", desktopedit: "Desktop",
    focus: "Focus", wallpaperpicker: "Wall", theme: "Theme", darkmode: "Dark", restart: "Restart",
    welcome: "Tour", wallpaperrandom: "Random", clock: "Clock", visualizer: "Viz",
    weathercard: "Weather", discord: "Discord", presets: "Presets", snip: "Snip", snipfile: "To file",
    ocr: "OCR", lens: "Lens", record: "Rec", recordsound: "Rec +", clipboard: "Clip", emoji: "Emoji",
    mute: "Mute", mic: "Mic", lock: "Lock", keybinds: "Keys"
}

// The five workspace colours of the shell, then neutral for anything else.
var COLORS = {
    Shell: "#FF9ECB", Utilities: "#FFB27A", Media: "#9FE3FF", Session: "#FF9A9A",
    Windows: "#FFE066", Workspaces: "#B39DDB", Apps: "#A5E6A5", Screen: "#D6EC9A"
}
var OTHER = "#DADCEB"

function colorOf(group) {
    return COLORS[group] !== undefined ? COLORS[group] : OTHER
}

// "Windows (more): Close window" -> "Windows"; no group -> "".
function groupOf(description) {
    var m = /^\s*([A-Za-z]+)(?:\s*\(more\))?\s*:/.exec(String(description || ""))
    return m ? m[1] : ""
}

function shortOf(name) {
    var w = String(name || "").trim().split(/\s+/)[0] || ""
    return w.length > 9 ? w.slice(0, 8) + "\u2026" : w
}

// ===== what is on the keys =====
function lower(s) { return String(s).toLowerCase() }

// Hardware keys, submaps and keys with no name are left out, as everywhere in the editor.
function layerMap(binds, rowList, mods) {
    var out = {}
    var m = mods & ~KB.IGNORED
    var rl = rowList || []
    for (var i = 0; i < rl.length; i++) {
        var r = rl[i]
        for (var j = 0; j < r.combos.length; j++) {
            var c = r.combos[j]
            if ((c.mods & ~KB.IGNORED) !== m || c.key === "") continue
            out[lower(c.key)] = { kind: "action", id: r.id, name: r.name, group: r.group,
                                  short: SHORT[r.id] !== undefined ? SHORT[r.id] : shortOf(r.name) }
        }
    }
    var bl = binds || []
    for (var k = 0; k < bl.length; k++) {
        var b = bl[k]
        if (b.submap) continue
        var cc = KB.comboOf(b)
        if (cc.key === "" || KB.isHardware(cc) || cc.mods !== m) continue
        var key = lower(cc.key)
        if (out[key] !== undefined) continue
        var name = KB.sentence(b.description)
        if (name === "") name = b.has_description ? String(b.description)
                              : (String(b.dispatcher) + " " + String(b.arg)).trim()
        out[key] = { kind: "hyprland", id: "", name: name, group: groupOf(b.description), short: shortOf(name) }
    }
    return out
}

// The entry a board key (or mouse key, with its `ids`) shows, or undefined.
function hit(map, key) {
    var ids = key.ids !== undefined ? key.ids : [key.id]
    for (var i = 0; i < ids.length; i++) {
        var e = map[lower(ids[i])]
        if (e !== undefined) return e
    }
    return undefined
}

// ===== the list =====
// The rows of one group, or every group's when something is searched for. KB.matches
// is the same search the old Keys page had ("super v", "lock", "clip").
function listRows(rowList, group, query) {
    var q = String(query || "").trim()
    var out = []
    for (var i = 0; i < rowList.length; i++) {
        var r = rowList[i]
        if (q === "" ? r.group !== group : !KB.matches(r, q)) continue
        out.push(r)
    }
    return out
}

// What a held set of modifiers is called in the strip.
function layerName(mods) {
    var names = KB.modNames(mods)
    return names.length === 0 ? "No modifier" : names.join(" + ")
}
