.pragma library

// One theme per monitor (setting theme.perMonitor; ThemeService.qml, Theme.of()): which
// monitor wears which theme. Pure functions on plain values, unit-tested with node:
// tests/screen-theme-test/screen_themes_unit.js.
//
// The choices live in the setting theme.screens, a JSON object { monitor name: theme id }.
// The MAIN monitor (WallpaperService.themeScreen, the first one) never has an entry: its
// theme is the shell's own (ThemeService.current), which is also what apps, Settings and
// the popups wear. Every other monitor follows it until it gets one of its own.

// The setting's text as a map: only string ids, only names that could be a monitor's.
function parse(text) {
    var out = {}
    var j = null
    try {
        j = JSON.parse(String(text || ""))
    } catch (e) {
        return out
    }
    if (!j || typeof j !== "object" || Array.isArray(j))
        return out
    for (var k in j) {
        if (validName(k) && typeof j[k] === "string" && j[k] !== "")
            out[k] = j[k]
    }
    return out
}

// Monitor names are things like "DP-2", "HDMI-A-1", "HEADLESS-1" or a name of your own.
// Also used as part of a file name (the monitor's own matugen colours), so nothing else.
function validName(name) {
    return typeof name === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(name) && name.charAt(0) !== "."
}

// Where a pick made on monitor `name` goes: "main" (the shell's theme) or "screen" (that
// monitor's own). With the setting off, or on the main monitor, it is always "main".
function target(perMonitor, name, mainName) {
    return perMonitor === true && validName(name) && name !== mainName ? "screen" : "main"
}

// The map after monitor `name` picks `id`. Picking the theme the main monitor wears
// (`mainId`), or an id that isn't a theme, clears its entry: it follows the main one again.
// The main monitor itself never gets an entry. A new object; `map` is not touched.
function pick(map, name, id, mainName, mainId, validIds) {
    var out = {}
    for (var k in map)
        out[k] = map[k]
    if (!validName(name) || name === mainName)
        return out
    if (id === mainId || validIds.indexOf(id) < 0)
        delete out[name]
    else
        out[name] = id
    return out
}

// The theme monitor `name` wears.
function themeFor(map, perMonitor, name, mainName, mainId, validIds) {
    if (target(perMonitor, name, mainName) !== "screen")
        return mainId
    var id = map[name]
    return typeof id === "string" && validIds.indexOf(id) >= 0 ? id : mainId
}

// The monitors other than the main one that wear the Matugen theme, by their own choice or
// by following the main monitor. With the setting on, each takes its colours from its OWN
// wallpaper (ThemeService runs matugen on it; one showing the main monitor's wallpaper just
// uses the main colours). With it off: none.
function matugenScreens(map, perMonitor, names, mainName, mainId, validIds) {
    var out = []
    if (perMonitor !== true)
        return out
    for (var i = 0; i < names.length; i++) {
        var n = names[i]
        if (n !== mainName && validName(n) && themeFor(map, perMonitor, n, mainName, mainId, validIds) === "matugen")
            out.push(n)
    }
    return out
}
