// Settings › Desktop › Plugins (docs/PLUGIN-SETTINGS.md): what the card shows, from
// modules/common/functions/PluginForm.js, run in node on manifests parsed by the real
// PluginManifest.parse, so the two can't drift apart.
// Run: node form_unit.js
const assert = require("assert")
const PM = require("../lib/pluginmanifest")
const PF = require("../lib/pluginform")

const plugin = m => {
    const r = PM.parse(JSON.stringify(Object.assign({ id: "p", name: "P", version: "1.0.0", api: 1 }, m)), "p")
    assert.strictEqual(r.ok, true, r.error)
    return r.plugin
}

// ---------- 1. labels from keys ----------
assert.strictEqual(PF.humanize("refreshMinutes"), "Refresh minutes")
assert.strictEqual(PF.humanize("url"), "Url")
assert.strictEqual(PF.humanize("use24h"), "Use 24h")
assert.strictEqual(PF.humanize("api_key"), "Api key")
assert.strictEqual(PF.humanize("serverURL"), "Server URL", "an acronym keeps its capitals")
assert.strictEqual(PF.humanize("URLPath"), "URL path")

// ---------- 2. the plain manifest: every setting still gets a control ----------
const plain = plugin({ settings: { url: "https://status.home.lan", refreshMinutes: 5, style: "cards", compact: false } })
let f = PF.form(plain, { url: "https://status.home.lan", refreshMinutes: 15, style: "list", compact: false })
assert.strictEqual(f.length, 1)
assert.strictEqual(f[0].title, "", "no groups: one list under no heading")
assert.deepStrictEqual(f[0].rows.map(r => [r.key, r.kind, r.label, r.hasLabel]), [
    ["url", "text", "Url", false],
    ["refreshMinutes", "stepper", "Refresh minutes", false],
    ["style", "text", "Style", false],
    ["compact", "toggle", "Compact", false]
], "manifest order, the key as its label, the fallback controls")
const byKey = (form, k) => [].concat(...form.map(g => g.rows)).find(r => r.key === k)
assert.deepStrictEqual([byKey(f, "refreshMinutes").changed, byKey(f, "refreshMinutes").defText], [true, "Default: 5"])
assert.deepStrictEqual([byKey(f, "style").changed, byKey(f, "style").defText], [true, "Default: cards"])
assert.strictEqual(byKey(f, "url").changed, false)
assert.deepStrictEqual(PF.changedKeys(plain, { url: "https://status.home.lan", refreshMinutes: 15, style: "list", compact: false }), ["refreshMinutes", "style"])
assert.strictEqual(byKey(PF.form(plain, {}), "refreshMinutes").value, 5, "a missing value is the default")

// ---------- 3. the richer manifest ----------
const rich = plugin({
    settings: { url: "https://status.home.lan", refreshMinutes: 5, style: "cards", compact: false, title: "Homelab", notes: "", stray: 1 },
    settingsInfo: {
        url: { label: "Server address", description: "Where your status page lives.", group: "Connection" },
        refreshMinutes: { label: "Check every", min: 1, max: 60, step: 1, unit: "minutes", group: "Connection" },
        style: { label: "Style", choices: [{ value: "cards", label: "Cards" }, { value: "list", label: "List" }, "dots"], group: "Look" },
        compact: { label: "Compact", group: "Look" },
        title: { label: "Title", group: "Look" },
        notes: { multiline: true, group: "Extra" }
    },
    groups: ["Look", "Connection"]
})
f = PF.form(rich, { url: "https://status.home.lan", refreshMinutes: 15, style: "list", compact: false, title: "Homelab", notes: "", stray: 1 })
assert.deepStrictEqual(f.map(g => g.title), ["Look", "Connection", "Extra", ""], "`groups` first, then groups only a setting names, ungrouped last")
assert.deepStrictEqual(f.map(g => g.rows.map(r => r.key)), [["style", "compact", "title"], ["url", "refreshMinutes"], ["notes"], ["stray"]])
const every = byKey(f, "refreshMinutes")
assert.deepStrictEqual([every.kind, every.shown, every.defText, every.min, every.max, every.outside], ["slider", "15 minutes", "Default: 5 minutes", 1, 60, false])
const style = byKey(f, "style")
assert.deepStrictEqual([style.kind, style.shown, style.defText], ["choice", "List", "Default: Cards"])
assert.deepStrictEqual(style.choices.map(c => c.label), ["Cards", "List", "dots"], "a plain string choice is its own label")
assert.strictEqual(byKey(f, "notes").kind, "multiline")
assert.deepStrictEqual([byKey(f, "url").description, byKey(f, "url").hasLabel], ["Where your status page lives.", true])
// a value the range or choices don't allow is shown as it is, and marked
f = PF.form(rich, { refreshMinutes: 90, style: "grid" })
assert.deepStrictEqual([byKey(f, "refreshMinutes").outside, byKey(f, "refreshMinutes").value, byKey(f, "refreshMinutes").shown], [true, 90, "90 minutes"])
assert.deepStrictEqual([byKey(f, "style").outside, byKey(f, "style").shown, byKey(f, "style").changed], [true, "grid", true])

// numbers keep the decimals their step or default has
const dec = plugin({ settings: { opacity: 0.85, n: 3 }, settingsInfo: { opacity: { min: 0, max: 1, step: 0.05 } } })
f = PF.form(dec, { opacity: 0.5, n: 3 })
assert.deepStrictEqual([byKey(f, "opacity").decimals, byKey(f, "opacity").shown, byKey(f, "opacity").defText], [2, "0.50", "Default: 0.85"])
assert.deepStrictEqual([byKey(f, "n").decimals, byKey(f, "n").step], [0, 1])
assert.strictEqual(PF.row(plugin({ settings: { on: true } }), { on: false }, "on").defText, "Default: On")
assert.strictEqual(PF.row(plugin({ settings: { s: "" } }), { s: "x" }, "s").defText, "Default: empty")

// ---------- 4. the list row ----------
assert.strictEqual(PF.countText(rich), "7 settings")
assert.strictEqual(PF.countText(plugin({ settings: { a: 1 }, secrets: { t: { env: "T" }, u: { env: "U" }, c: { file: "c" } } })), "1 setting · 3 secrets")
assert.strictEqual(PF.countText(plugin({})), "No settings")
assert.strictEqual(PF.hasForm(plugin({})), false)
assert.strictEqual(PF.hasForm(plugin({ secrets: { t: { env: "T" } } })), true, "secrets alone are worth opening")
const sec = plugin({ secrets: { token: { env: "T" }, user: { env: "U" } } })
assert.strictEqual(PF.warnText(sec, { token: "", user: "env" }), "token not found")
assert.strictEqual(PF.warnText(sec, {}), "2 secrets not found")
assert.strictEqual(PF.warnText(sec, { token: "file", user: "env" }), "")
assert.deepStrictEqual(PF.secretInfo("token", { env: "T", file: "~/t" }, ""), { name: "token", found: false, source: "", env: "T", file: "~/t" })
assert.strictEqual(PF.secretInfo("token", { env: "T", file: "" }, "env").found, true)

// ---------- 5. skipped folders, in plain words, for every code the manifest gives ----------
const out = "\x1eempty\n" +
    "\x1eBad\n{}" +
    "\x1ebroken\n{nope" +
    "\x1earr\n[1]" +
    "\x1enew\n" + JSON.stringify({ id: "new", name: "N", version: "1", api: 99 }) +
    "\x1eold\n" + JSON.stringify({ id: "old", name: "N", version: "1", api: 0 }) +
    "\x1ewrong\n" + JSON.stringify({ id: "right", name: "N", version: "1", api: 1 }) +
    "\x1enover\n" + JSON.stringify({ id: "nover", name: "N", api: 1 })
const sk = PM.scan(out).skipped
const info = id => PF.skipInfo(sk.find(s => s.id === id))
assert.match(info("empty").reason, /no plugin\.json/)
assert.match(info("Bad").reason, /folder's name/)
assert.match(info("broken").reason, /mistake/)
assert.match(info("arr").reason, /mistake/)
assert.deepStrictEqual([info("new").reason, info("new").action], ["Made for a newer SekaiPop than this one.", "update"])
assert.match(info("old").fix, /update the plugin/)
assert.match(info("wrong").reason, /named differently/)
assert.strictEqual(info("nover").reason, "Its plugin.json is missing or misspells: version.")
for (const s of sk)
    assert.notStrictEqual(PF.skipInfo(s).reason, "It could not be loaded.", s.id + " has a plain-words reason")

console.log("form_unit: all checks passed")
