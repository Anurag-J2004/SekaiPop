// Every setting the code reads or writes by name has a default in SettingsService.qml.
// SettingsService.set() ignores a key it has no default for, so a missing one fails
// silently: the choice is thrown away and the getter falls back (how Wallhaven's sort and
// filters stopped being kept, after a merge dropped their defaults).
//   node tests/settings-test/keys_have_defaults_test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const top = path.join(__dirname, "..", "..")
const settings = fs.readFileSync(path.join(top, "services", "SettingsService.qml"), "utf8")
const block = settings.slice(settings.indexOf("property var defaults"), settings.indexOf("\n    })", settings.indexOf("property var defaults")))
const defaults = new Set([...block.matchAll(/^\s*"([A-Za-z0-9_.]+)"\s*:/gm)].map(m => m[1]))
assert.ok(defaults.size > 50, "found the defaults (" + defaults.size + ")")

function walk(dir, out) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name === "tests" || e.name.startsWith(".")) continue
        const p = path.join(dir, e.name)
        if (e.isDirectory()) walk(p, out)
        else if (/\.(qml|js)$/.test(e.name)) out.push(p)
    }
    return out
}

const missing = []
for (const f of walk(top, [])) {
    const src = fs.readFileSync(f, "utf8")
    for (const m of src.matchAll(/SettingsService\.(get|flag|set|toggle)\(\s*"([A-Za-z0-9_.]+)"\s*[,)]/g)) {
        if (!defaults.has(m[2]))
            missing.push(path.relative(top, f) + ": " + m[1] + "(\"" + m[2] + "\")")
    }
}
assert.deepStrictEqual(missing, [], "settings used without a default:\n  " + missing.join("\n  "))
console.log("keys_have_defaults: all passed (" + defaults.size + " defaults)")
