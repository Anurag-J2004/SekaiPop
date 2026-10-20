// One theme per monitor: the rules (ScreenThemes.js) one at a time, Theme.of() as text, and
// the wiring (Quickshell can't run here). Run: node screen_themes_unit.js
const fs = require("fs"), assert = require("assert")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")
const src = read("modules/common/functions/ScreenThemes.js").replace(".pragma library", "")
const S = {}
new Function("S", src + ";Object.assign(S,{parse,validName,target,pick,themeFor,matugenScreens})")(S)

const ids = ["vs", "leoneed", "mmj", "nightcord", "matugen"]

// ---------- the setting's text ----------
assert.deepStrictEqual(S.parse('{"DP-2":"mmj","remote":"nightcord"}'), { "DP-2": "mmj", remote: "nightcord" })
assert.deepStrictEqual(S.parse(""), {}, "no setting yet")
assert.deepStrictEqual(S.parse("not json"), {})
assert.deepStrictEqual(S.parse('["vs"]'), {}, "an array is not a map")
assert.deepStrictEqual(S.parse('{"../x":"vs","ok":5,"HDMI-A-1":"vs"}'), { "HDMI-A-1": "vs" }, "bad names and non-string ids dropped")
assert.ok(S.validName("HEADLESS-1") && S.validName("remote") && !S.validName(".hidden") && !S.validName("a/b") && !S.validName(""))

// ---------- where a pick goes ----------
assert.strictEqual(S.target(false, "remote", "DP-2"), "main", "setting off: every pick is the shell's theme")
assert.strictEqual(S.target(true, "DP-2", "DP-2"), "main", "the main monitor sets the shell's theme")
assert.strictEqual(S.target(true, "remote", "DP-2"), "screen")
assert.strictEqual(S.target(true, "", "DP-2"), "main", "a picker that doesn't know its monitor")

// ---------- picking ----------
let m = {}
m = S.pick(m, "remote", "mmj", "DP-2", "vs", ids)
assert.deepStrictEqual(m, { remote: "mmj" })
const before = m
m = S.pick(m, "remote", "nightcord", "DP-2", "vs", ids)
assert.deepStrictEqual(m, { remote: "nightcord" }); assert.deepStrictEqual(before, { remote: "mmj" }, "the old map is not touched")
assert.deepStrictEqual(S.pick(m, "remote", "vs", "DP-2", "vs", ids), {}, "picking the main monitor's theme: follow it again")
assert.deepStrictEqual(S.pick(m, "remote", "gone", "DP-2", "vs", ids), {}, "an id that isn't a theme clears it")
assert.deepStrictEqual(S.pick(m, "DP-2", "mmj", "DP-2", "vs", ids), m, "the main monitor never gets an entry")
assert.deepStrictEqual(S.pick(m, "a/b", "mmj", "DP-2", "vs", ids), m)

// ---------- what a monitor wears ----------
const map = { remote: "mmj", "HDMI-A-1": "deleted-theme" }
assert.strictEqual(S.themeFor(map, true, "remote", "DP-2", "vs", ids), "mmj")
assert.strictEqual(S.themeFor(map, false, "remote", "DP-2", "vs", ids), "vs", "setting off: everyone wears the shell's theme")
assert.strictEqual(S.themeFor(map, true, "DP-2", "DP-2", "vs", ids), "vs")
assert.strictEqual(S.themeFor(map, true, "HDMI-A-1", "DP-2", "vs", ids), "vs", "a theme that no longer exists: follow the main one")
assert.strictEqual(S.themeFor(map, true, "DP-3", "DP-2", "vs", ids), "vs", "a monitor with no entry follows")

// ---------- who needs their own matugen run ----------
const names = ["DP-2", "remote", "HDMI-A-1"]
assert.deepStrictEqual(S.matugenScreens({ remote: "matugen" }, true, names, "DP-2", "vs", ids), ["remote"])
assert.deepStrictEqual(S.matugenScreens({}, true, names, "DP-2", "matugen", ids), ["remote", "HDMI-A-1"], "following a Matugen main: each from its own wallpaper")
assert.deepStrictEqual(S.matugenScreens({ remote: "mmj" }, true, names, "DP-2", "matugen", ids), ["HDMI-A-1"])
assert.deepStrictEqual(S.matugenScreens({ remote: "matugen" }, false, names, "DP-2", "vs", ids), [], "setting off: none")

// ---------- the wiring ----------
const theme = read("modules/common/Theme.qml")
assert.ok(/function of\(w\)/.test(theme) && /ThemeService\.hasScreenTheme\(name\)/.test(theme) && /ThemeService\.paletteFor\(name\)/.test(theme), "Theme.of asks ThemeService")
assert.ok(/property var pal: ThemeService\.palette/.test(read("modules/common/ThemeSet.qml")), "a ThemeSet's palette can be set")
const svc = read("services/ThemeService.qml")
assert.ok(/readonly property var screenGroups: ST\.parse\(SettingsService\.get\("theme\.screens"\)\)/.test(svc), "the choices are the setting")
assert.ok(/function pickTheme\(name, id\)/.test(svc) && /ST\.target\(/.test(svc), "pickers go through pickTheme")
const settings = read("services/SettingsService.qml")
assert.ok(settings.includes('"theme.perMonitor": false') && settings.includes('"theme.screens": ""'), "the two settings")
assert.ok(/ThemeService\.pickTheme\(/.test(read("modules/sekai/editMode/EditThemeBoard.qml")), "Edit Desktop's tiles pick for their monitor")
assert.ok(/ThemeService\.pickTheme\(/.test(read("modules/sekai/settings/SettingsPageQuick.qml")), "Settings' Colours picks for its monitor")
assert.ok(/theme\.perMonitor/.test(read("modules/sekai/settings/SettingsPageDesktop.qml")), "the switch is in Settings")
console.log("screen_themes_unit: all checks passed")
