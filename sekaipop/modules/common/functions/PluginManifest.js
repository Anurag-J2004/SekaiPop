.pragma library

// Desktop widget plugins (services/PluginService.qml, docs/PLUGINS.md): reading a plugin's
// plugin.json and its saved state. Pure functions on plain objects, so they are unit-tested
// with node: tests/plugin-test/manifest_unit.js.
//
// A plugin is a folder, ${XDG_CONFIG_HOME:-~/.config}/sekaipop/plugins/<id>/, holding
// plugin.json and Widget.qml. The manifest is the half of the plugin interface that is
// data; the `host` object the widget is handed is the other half. Both are promises:
// change them only by raising API_VERSION, and keep reading the older one where it
// costs little.

// The plugin interface this shell speaks. A plugin names the one it was written for in
// `api`; one this shell does not speak is skipped with a message, never loaded half-broken.
var API_VERSION = 1
var SUPPORTED = [1]

// The folder name is the id, so the id can be trusted as a file name and in an ipc call.
var ID_RE = /^[a-z0-9][a-z0-9-]{0,39}$/
// A secret's name, and a setting's key: something that reads well as `host.secrets.token`.
var KEY_RE = /^[A-Za-z_][A-Za-z0-9_]{0,39}$/

function isObj(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v)
}

// A settings value a plugin may declare: what JSON and an ipc call can carry plainly.
function plainValue(v) {
    return typeof v === "string" || typeof v === "boolean" || (typeof v === "number" && isFinite(v))
}

// parse(text, folder) -> { ok: true, plugin } or { ok: false, id, error }
// `plugin` is the manifest with every optional field filled in, so nothing downstream has
// to guess:
//   { id, name, version, api, description, icon, frame, cloneable, settings, secrets }
function parse(text, folder) {
    var bad = function (msg) {
        return { ok: false, id: folder, error: msg }
    }
    if (!ID_RE.test(folder))
        return bad("the folder name must be lower case letters, digits and dashes (it is the plugin's id)")
    var m
    try {
        m = JSON.parse(text)
    } catch (e) {
        return bad("plugin.json is not valid JSON")
    }
    if (!isObj(m))
        return bad("plugin.json must be an object")
    if (m.id !== folder)
        return bad("plugin.json says id \"" + m.id + "\" but its folder is \"" + folder + "\"; they must match")
    if (typeof m.name !== "string" || m.name.trim() === "")
        return bad("plugin.json needs a name")
    if (typeof m.version !== "string" || m.version === "")
        return bad("plugin.json needs a version (a string)")
    if (typeof m.api !== "number" || Math.floor(m.api) !== m.api)
        return bad("plugin.json needs `api`: the plugin interface version it was written for (this shell speaks " + API_VERSION + ")")
    if (SUPPORTED.indexOf(m.api) < 0)
        return bad("written for plugin api " + m.api + ", this shell speaks " + SUPPORTED.join(", ")
            + (m.api > API_VERSION ? " (update SekaiPop)" : " (update the plugin)"))

    var settings = {}
    if (m.settings !== undefined) {
        if (!isObj(m.settings))
            return bad("`settings` must be an object of name: default value")
        for (var k in m.settings) {
            if (!KEY_RE.test(k))
                return bad("setting \"" + k + "\": names are letters, digits and _")
            if (!plainValue(m.settings[k]))
                return bad("setting \"" + k + "\": a default is a string, a number or true / false")
            settings[k] = m.settings[k]
        }
    }

    var secrets = {}
    if (m.secrets !== undefined) {
        if (!isObj(m.secrets))
            return bad("`secrets` must be an object of name: { env, file }")
        for (var s in m.secrets) {
            var d = m.secrets[s]
            if (!KEY_RE.test(s))
                return bad("secret \"" + s + "\": names are letters, digits and _")
            if (!isObj(d) || (typeof d.env !== "string" && typeof d.file !== "string"))
                return bad("secret \"" + s + "\": say where it is read from, `env` and / or `file`")
            secrets[s] = {
                env: typeof d.env === "string" ? d.env : "",
                file: typeof d.file === "string" ? d.file : ""
            }
        }
    }

    return {
        ok: true,
        plugin: {
            id: m.id,
            name: m.name.trim(),
            version: m.version,
            api: m.api,
            description: typeof m.description === "string" ? m.description : "",
            // A Material Symbols name, for its tile on the Edit Desktop shelf.
            icon: typeof m.icon === "string" && m.icon !== "" ? m.icon : "extension",
            // The shell's card around the widget (outline, ring, surface, shadow), so a plugin
            // looks like the built-in cards without drawing one. false = the widget draws all.
            frame: m.frame !== false,
            // A copy on more than one monitor (EditMode's "one widget, several monitors").
            cloneable: m.cloneable !== false,
            settings: settings,
            secrets: secrets
        }
    }
}

// The manifest's defaults with the user's saved values on top. A saved value only counts
// for a setting the manifest still declares and only with the default's type, so a plugin
// update that drops or retypes a setting never hands the widget something it did not ask for.
function mergeSettings(defaults, saved) {
    var out = {}
    for (var k in defaults) {
        var v = isObj(saved) ? saved[k] : undefined
        out[k] = (v !== undefined && typeof v === typeof defaults[k] && plainValue(v)) ? v : defaults[k]
    }
    return out
}

// One value from an ipc call (always a string) turned into the setting's type, or
// undefined when it cannot be one.
function coerce(defaultValue, text) {
    if (typeof defaultValue === "string")
        return String(text)
    if (typeof defaultValue === "boolean") {
        if (text === true || text === "true" || text === "1" || text === "on")
            return true
        if (text === false || text === "false" || text === "0" || text === "off")
            return false
        return undefined
    }
    if (typeof defaultValue === "number") {
        var n = typeof text === "number" ? text : parseFloat(text)
        return isFinite(n) ? n : undefined
    }
    return undefined
}

// The scan script's output (scripts/state/plugin-state.sh scan): for every plugin folder,
// a line "\x1e<folder>" followed by its plugin.json (or nothing when it has none).
// -> [{ folder, text }]
function splitScan(out) {
    var recs = []
    var parts = String(out || "").split("\x1e")
    for (var i = 1; i < parts.length; i++) {
        var nl = parts[i].indexOf("\n")
        var folder = nl < 0 ? parts[i] : parts[i].slice(0, nl)
        var text = nl < 0 ? "" : parts[i].slice(nl + 1)
        if (folder !== "")
            recs.push({ folder: folder, text: text })
    }
    return recs
}

// scan(out) -> { plugins: [plugin], skipped: [{ id, error }] }, sorted by id so the shelf
// keeps one order.
function scan(out) {
    var plugins = []
    var skipped = []
    var recs = splitScan(out)
    recs.sort(function (a, b) { return a.folder < b.folder ? -1 : a.folder > b.folder ? 1 : 0 })
    for (var i = 0; i < recs.length; i++) {
        var r = recs[i]
        if (r.text.trim() === "") {
            skipped.push({ id: r.folder, error: "no plugin.json" })
            continue
        }
        var p = parse(r.text, r.folder)
        if (p.ok)
            plugins.push(p.plugin)
        else
            skipped.push({ id: p.id, error: p.error })
    }
    return { plugins: plugins, skipped: skipped }
}

// A plugin's saved state (spot, on / off, settings) read back; anything unreadable is the
// default: never placed, off, the manifest's settings.
function readState(text, defaults) {
    var s = {}
    try {
        s = JSON.parse(text)
    } catch (e) {
        s = {}
    }
    if (!isObj(s))
        s = {}
    return {
        x: typeof s.x === "number" ? s.x : -1,
        y: typeof s.y === "number" ? s.y : -1,
        scale: typeof s.scale === "number" && s.scale > 0 ? s.scale : 0,
        screen: typeof s.screen === "string" ? s.screen : "",
        shown: s.shown === true,
        settings: mergeSettings(defaults || {}, s.settings)
    }
}

// "~/x" and "x" (relative to the plugin's folder) as an absolute path.
function expandPath(path, home, dir) {
    if (typeof path !== "string" || path === "")
        return ""
    if (path === "~")
        return home
    if (path.indexOf("~/") === 0)
        return home + path.slice(1)
    if (path.charAt(0) === "/")
        return path
    return dir + "/" + path
}
