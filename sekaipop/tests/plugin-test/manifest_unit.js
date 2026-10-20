// Desktop widget plugins (services/PluginService.qml, docs/PLUGINS.md): the manifest rules
// in modules/common/functions/PluginManifest.js, run in node, plus the shell's own files
// read as text to check that a plugin is wired through everywhere a widget is, and that the
// example plugin keeps to the interface it is the example of.
// Run: node manifest_unit.js
const fs = require("fs"), path = require("path"), assert = require("assert")
const locate = require("../lib/locate")
const PM = require("../lib/pluginmanifest")
const read = f => fs.readFileSync(locate(f), "utf8")

const good = { id: "hello", name: "Hello", version: "1.0.0", api: 1 }
const parse = (m, folder) => PM.parse(typeof m === "string" ? m : JSON.stringify(m), folder || "hello")
const err = (m, folder) => { const r = parse(m, folder); assert.strictEqual(r.ok, false, JSON.stringify(m)); return r.error }

// ---------- 1. a minimal manifest, filled in ----------
let r = parse(good)
assert.strictEqual(r.ok, true)
assert.deepStrictEqual(r.plugin, {
    id: "hello", name: "Hello", version: "1.0.0", api: 1, description: "", icon: "extension",
    frame: true, cloneable: true, settings: {}, secrets: {}
})
r = parse(Object.assign({}, good, { icon: "waving_hand", frame: false, cloneable: false, description: "d", name: "  Hi  " }))
assert.deepStrictEqual([r.plugin.icon, r.plugin.frame, r.plugin.cloneable, r.plugin.description, r.plugin.name],
    ["waving_hand", false, false, "d", "Hi"])

// ---------- 2. what is refused, and that it says why ----------
assert.match(err(good, "Hello"), /folder name/)
assert.match(err(good, "../x"), /folder name/)
assert.match(err(good, "-x"), /folder name/)
assert.match(err("{nope"), /not valid JSON/)
assert.match(err("[1]"), /must be an object/)
assert.match(err(Object.assign({}, good, { id: "other" })), /folder is "hello"/)
assert.match(err(Object.assign({}, good, { name: " " })), /needs a name/)
assert.match(err(Object.assign({}, good, { version: 1 })), /needs a version/)
assert.match(err(Object.assign({}, good, { api: undefined })), /needs `api`/)
assert.match(err(Object.assign({}, good, { api: 1.5 })), /needs `api`/)
assert.match(err(Object.assign({}, good, { api: PM.API_VERSION + 1 })), /update SekaiPop/, "a plugin from the future says the shell is old")
assert.match(err(Object.assign({}, good, { api: 0 })), /update the plugin/, "a plugin from the past says the plugin is old")
assert.match(err(Object.assign({}, good, { settings: [] })), /`settings` must be an object/)
assert.match(err(Object.assign({}, good, { settings: { "bad key": 1 } })), /names are letters/)
assert.match(err(Object.assign({}, good, { settings: { list: [1] } })), /a default is/)
assert.match(err(Object.assign({}, good, { settings: { n: null } })), /a default is/)
assert.match(err(Object.assign({}, good, { secrets: { token: "MY_TOKEN" } })), /`env` and \/ or `file`/)
assert.match(err(Object.assign({}, good, { secrets: { token: {} } })), /`env` and \/ or `file`/)
assert.deepStrictEqual(PM.SUPPORTED.indexOf(PM.API_VERSION) >= 0, true, "the shell speaks its own api")

// settings and secrets that are fine
r = parse(Object.assign({}, good, { settings: { greeting: "Hi", n: 3, on: false }, secrets: { token: { env: "T" }, key: { file: "~/k" } } }))
assert.deepStrictEqual(r.plugin.settings, { greeting: "Hi", n: 3, on: false })
assert.deepStrictEqual(r.plugin.secrets, { token: { env: "T", file: "" }, key: { env: "", file: "~/k" } })

// ---------- 3. saved settings never hand the widget what it did not ask for ----------
const defs = { greeting: "Hi", n: 3, on: false }
assert.deepStrictEqual(PM.mergeSettings(defs, null), defs)
assert.deepStrictEqual(PM.mergeSettings(defs, { greeting: "Yo", n: 7, on: true }), { greeting: "Yo", n: 7, on: true })
assert.deepStrictEqual(PM.mergeSettings(defs, { greeting: 5, n: "7", on: "yes", gone: 1 }), defs, "a retyped or dropped setting falls back to the default")
assert.deepStrictEqual(PM.mergeSettings(defs, { n: Infinity }), defs)
// an ipc value is a string; it takes the setting's type or is refused
assert.strictEqual(PM.coerce("x", "hello"), "hello")
assert.strictEqual(PM.coerce(1, "2.5"), 2.5)
assert.strictEqual(PM.coerce(1, "abc"), undefined)
assert.strictEqual(PM.coerce(true, "false"), false)
assert.strictEqual(PM.coerce(true, "on"), true)
assert.strictEqual(PM.coerce(true, "maybe"), undefined)
assert.strictEqual(PM.coerce(false, true), true, "the widget's own setSetting passes real booleans")

// ---------- 4. saved state ----------
assert.deepStrictEqual(PM.readState("", defs), { x: -1, y: -1, scale: 0, screen: "", shown: false, settings: defs }, "nothing saved: never placed, off")
assert.deepStrictEqual(PM.readState("garbage", defs).shown, false)
assert.deepStrictEqual(PM.readState(JSON.stringify({ x: 10, y: 20, scale: 1.25, screen: "DP-1", shown: true, settings: { n: 9 } }), defs),
    { x: 10, y: 20, scale: 1.25, screen: "DP-1", shown: true, settings: { greeting: "Hi", n: 9, on: false } })
assert.strictEqual(PM.readState(JSON.stringify({ shown: "yes" }), defs).shown, false, "only a real true switches it on")

// ---------- 5. the scan script's output ----------
const out = "\x1ezeta\n" + JSON.stringify(Object.assign({}, good, { id: "zeta" })) +
    "\x1eempty\n" +
    "\x1ealpha\n" + JSON.stringify(Object.assign({}, good, { id: "alpha" })) +
    "\x1eBad Name\n{}" +
    "\x1efuture\n" + JSON.stringify(Object.assign({}, good, { id: "future", api: 99 }))
const s = PM.scan(out)
assert.deepStrictEqual(s.plugins.map(p => p.id), ["alpha", "zeta"], "sorted by id, the good ones only")
assert.deepStrictEqual(s.skipped.map(x => x.id), ["Bad Name", "empty", "future"])
assert.match(s.skipped.find(x => x.id === "empty").error, /no plugin.json/)
assert.deepStrictEqual(PM.scan(""), { plugins: [], skipped: [] })
assert.deepStrictEqual(PM.splitScan("\x1ea\nline1\nline2\n"), [{ folder: "a", text: "line1\nline2\n" }], "a manifest keeps its own newlines")

// ---------- 6. paths ----------
assert.strictEqual(PM.expandPath("~/x/y", "/home/u", "/p"), "/home/u/x/y")
assert.strictEqual(PM.expandPath("/abs", "/home/u", "/p"), "/abs")
assert.strictEqual(PM.expandPath("token.txt", "/home/u", "/p"), "/p/token.txt", "relative to the plugin's folder")
assert.strictEqual(PM.expandPath("", "/home/u", "/p"), "")

// ---------- 7. the example plugin is a good one ----------
const ex = path.join(__dirname, "..", "..", "..", "examples", "plugins", "hello-clock")
r = PM.parse(fs.readFileSync(path.join(ex, "plugin.json"), "utf8"), "hello-clock")
assert.strictEqual(r.ok, true, "examples/plugins/hello-clock/plugin.json: " + r.error)
assert.strictEqual(r.plugin.api, PM.API_VERSION, "the example is written for the api this shell speaks")
const widget = fs.readFileSync(path.join(ex, "Widget.qml"), "utf8")
assert.ok(/required property var host/.test(widget), "the example declares `required property var host`")
assert.ok(!/^import\s+qs\./m.test(widget), "the example imports nothing of the shell's own (a plugin can't)")
for (const k of Object.keys(r.plugin.settings))
    assert.ok(widget.includes("settings." + k) || widget.includes('"' + k + '"'), "the example uses its setting " + k)

// ---------- 8. a plugin goes everywhere a widget goes ----------
const edit = read("services/EditMode.qml")
assert.ok(/readonly property var shelfList:\s*root\.widgetList\.concat\(PluginService\.shelfEntries\)/.test(edit), "the shelf lists the plugins")
for (const fn of ["cloneable", "svcOf", "widgetShown", "widgetOn", "addWidget", "removeWidget"]) {
    const body = edit.slice(edit.indexOf("function " + fn + "("))
    const end = body.indexOf("\n    }\n")
    assert.ok(body.slice(0, end).includes("PluginService"), "EditMode." + fn + "() knows about plugins")
}
const tray = read("modules/sekai/editMode/EditTray.qml")
assert.ok(tray.includes("model: EditMode.shelfList"), "the shelf is built from shelfList")
assert.ok(!/EditMode\.widgetList/.test(tray.replace(/\/\/.*$/gm, "")), "EditTray reads shelfList, not widgetList")
const shell = read("shell.qml")
assert.ok(/model: PluginService\.ids/.test(shell) && /PluginWidgetHost \{ pluginId: plg\.modelData \}/.test(shell), "shell.qml builds a window per plugin")
assert.ok(/PluginWidgetHost \{ pluginId: plg\.modelData; clone: true/.test(shell), "...and its copies on other monitors")
const host = read("modules/sekai/desktopWidgets/PluginWidgetHost.qml")
assert.ok(/setSource\(slot\.url, \{ host: hostApi \}\)/.test(host), "the widget is handed `host` as it is made")
// the names docs/PLUGINS.md promises are on the host object
const doc = fs.readFileSync(path.join(__dirname, "..", "..", "..", "docs", "PLUGINS.md"), "utf8")
const hostBlock = host.slice(host.indexOf("id: hostApi"), host.indexOf("// ===== placement"))
for (const name of ["apiVersion", "id", "name", "version", "dir", "theme", "settings", "secrets", "screenName", "scale", "clone", "working", "editing", "selected", "path", "setSetting"]) {
    assert.ok(new RegExp("(property \\w+ " + name + ":|function " + name + "\\()").test(hostBlock), "host." + name + " is on the host object")
    assert.ok(doc.includes("`" + name + "`") || doc.includes("`" + name + "("), "docs/PLUGINS.md documents host." + name)
}
// every theme name the doc promises exists in the theme
const themeSet = read("modules/common/ThemeSet.qml")
const promised = (doc.match(/<!-- theme-names -->([\s\S]*?)<!-- \/theme-names -->/) || [, ""])[1].match(/`(\w+)`/g) || []
assert.ok(promised.length >= 8, "docs/PLUGINS.md lists the promised theme names between <!-- theme-names --> markers")
for (const q of promised) {
    const n = q.slice(1, -1)
    assert.ok(new RegExp("property \\w+ " + n + "\\b").test(themeSet), "theme name " + n + " (promised in docs/PLUGINS.md) is not in ThemeSet.qml")
}

console.log("manifest_unit: all checks passed")
