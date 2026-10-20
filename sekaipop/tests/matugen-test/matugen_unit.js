// The Matugen theme's knobs (MatugenMath.js), one rule at a time, plus the script's
// `apply` / `sources` arguments run for real against a fake matugen, and the wiring
// as text (Quickshell can't run here). Run: node matugen_unit.js
const fs = require("fs"), os = require("os"), path = require("path"), assert = require("assert")
const { spawnSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")
const src = read("modules/common/functions/MatugenMath.js").replace(".pragma library", "")
const M = {}
new Function("M", src + ";Object.assign(M,{SCHEMES,DEFAULT_SCHEME,CONTRASTS,cleanScheme,cleanContrast,cleanSeed,cleanHex,parseSources,applyPins,applyArgs})")(M)

// ---------- the knobs ----------
assert.strictEqual(M.SCHEMES.length, 9, "the nine schemes the controls show")
assert.deepStrictEqual(M.SCHEMES.map(s => s.label), ["Tonal", "Vibrant", "Expressive", "Fidelity", "Content", "Neutral", "Mono", "Rainbow", "Fruit salad"], "in the design's order")
assert.strictEqual(M.SCHEMES[0].id, M.DEFAULT_SCHEME, "the default first")
assert.strictEqual(M.cleanScheme("scheme-vibrant"), "scheme-vibrant")
assert.strictEqual(M.cleanScheme("scheme-smart"), M.DEFAULT_SCHEME, "a matugen type the controls don't offer falls back")
assert.strictEqual(M.cleanScheme(undefined), M.DEFAULT_SCHEME)

assert.deepStrictEqual(M.CONTRASTS.map(c => c.value), [-1, -0.5, 0, 0.5, 1])
assert.strictEqual(M.cleanContrast(0.4), 0.5, "snaps to the nearest step")
assert.strictEqual(M.cleanContrast(-7), -1)
assert.strictEqual(M.cleanContrast("x"), 0)
assert.strictEqual(M.cleanContrast(0.2), 0)

assert.strictEqual(M.cleanSeed(-1, 4), -1, "Auto")
assert.strictEqual(M.cleanSeed(2, 4), 2)
assert.strictEqual(M.cleanSeed(3, 3), -1, "a seed this wallpaper has no colour for leads with Auto")
assert.strictEqual(M.cleanSeed(1.7, 3), 1)
assert.strictEqual(M.cleanSeed("nope", 3), -1)

assert.strictEqual(M.cleanHex("FFB68E"), "#ffb68e")
assert.strictEqual(M.cleanHex(" #4fd8ff "), "#4fd8ff")
assert.strictEqual(M.cleanHex("#fb8"), "#ffbb88", "short form")
assert.strictEqual(M.cleanHex("#12345"), "")
assert.strictEqual(M.cleanHex("red"), "")
assert.strictEqual(M.cleanHex(null), "")

// matugen's --show-source-colors, with and without decoration
assert.deepStrictEqual(M.parseSources("#83bed3\n#c3d4e2\n#c3dadd\n"), ["#83bed3", "#c3d4e2", "#c3dadd"])
assert.deepStrictEqual(M.parseSources("\u001b[38;2;1;2;3m██\u001b[0m 0: #E8287A (score 0.9)\n1: #ff8a1f\n#e8287a\nnoise"), ["#e8287a", "#ff8a1f"], "colour codes stripped, repeats dropped")
assert.deepStrictEqual(M.parseSources(""), [])

const pal = { A: "#111111", B: "#222222", border: "#333333" }
assert.strictEqual(M.applyPins(pal, "", ""), pal, "nothing pinned: the same palette")
const pinned = M.applyPins(pal, "4FD8FF", "")
assert.deepStrictEqual(pinned, { A: "#4fd8ff", B: "#222222", border: "#333333" }, "only the pinned accent changes")
assert.strictEqual(pal.A, "#111111", "the palette itself is not touched")
assert.deepStrictEqual(M.applyPins(pal, "", "#ffb68e").B, "#ffb68e")
assert.strictEqual(M.applyPins(pal, "bogus", "").A, "#111111", "a bad pin is no pin")
assert.strictEqual(M.applyPins(null, "#fff", ""), null)

assert.deepStrictEqual(M.applyArgs(-1, 0), ["0", "0"], "Auto is matugen's first pick")
assert.deepStrictEqual(M.applyArgs(2, -0.5), ["2", "-0.5"])

// ---------- the script, against a fake matugen ----------
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "matugen-"))
try {
    const bin = path.join(tmp, "bin"); fs.mkdirSync(bin)
    const log = path.join(tmp, "calls.log")
    // Writes the template's output (so `apply` finds a colors.json), or prints source colours.
    fs.writeFileSync(path.join(bin, "matugen"), `#!/bin/sh
echo "$*" >> "${log}"
case "$*" in *--show-source-colors*) printf '#e8287a\\n#ff8a1f\\n'; exit 0;; esac
cfg=""; prev=""; for a in "$@"; do [ "$prev" = "--config" ] && cfg="$a"; prev="$a"; done
out=$(sed -n "s/^output_path = '\\(.*\\)'$/\\1/p" "$cfg")
printf '{"dark":{"primary":"#000000"}}\\n' > "$out"
`, { mode: 0o755 })
    const img = path.join(tmp, "wall.png"); fs.writeFileSync(img, "x")
    const env = Object.assign({}, process.env, { PATH: bin + ":" + process.env.PATH, XDG_CACHE_HOME: path.join(tmp, "cache") })
    const sh = (...a) => spawnSync("sh", [path.join(top, "scripts", "theming", "matugen-state.sh"), ...a], { env, encoding: "utf8" })
    const calls = () => fs.readFileSync(log, "utf8").trim().split("\n")

    let r = sh("apply", img, "scheme-vibrant")
    assert.strictEqual(r.status, 0, r.stderr)
    assert.ok(/--type scheme-vibrant --source-color-index 0 /.test(calls()[0]) && !/--contrast/.test(calls()[0]), "the old call is unchanged: seed 0, no contrast")
    r = sh("apply", img, "scheme-content", "colors", "2", "-0.5")
    assert.strictEqual(r.status, 0, r.stderr)
    assert.ok(/--source-color-index 2 /.test(calls()[1]) && /--contrast -0.5/.test(calls()[1]), "seed and contrast passed on")
    r = sh("apply", img, "scheme-content", "colors", "x", "9")
    assert.ok(/--source-color-index 0 /.test(calls()[2]) && !/--contrast/.test(calls()[2]), "junk seed / contrast ignored, not passed to matugen")
    assert.ok(fs.existsSync(path.join(tmp, "cache", "sekaipop", "matugen", "colors.json")))
    r = sh("sources", img)
    assert.strictEqual(r.status, 0, r.stderr)
    assert.deepStrictEqual(M.parseSources(r.stdout), ["#e8287a", "#ff8a1f"])
    assert.ok(/--show-source-colors/.test(calls()[3]) && /--dry-run/.test(calls()[3]), "sources writes nothing")
    assert.strictEqual(sh("sources", path.join(tmp, "nope.png")).status, 2)
    assert.strictEqual(sh("installed").status, 0, "installed: 0 when matugen is on the PATH")
    assert.strictEqual(spawnSync("/bin/sh", [path.join(top, "scripts", "theming", "matugen-state.sh"), "installed"],
        { env: Object.assign({}, env, { PATH: "/nonexistent" }), encoding: "utf8" }).status, 127, "127 when it isn't")
} finally {
    fs.rmSync(tmp, { recursive: true, force: true })
}

// ---------- the wiring ----------
const svc = read("services/ThemeService.qml")
const settings = read("services/SettingsService.qml")
for (const k of ['"matugen.scheme": "scheme-tonal-spot"', '"matugen.seed": -1', '"matugen.contrast": 0', '"matugen.pinA": ""', '"matugen.pinB": ""'])
    assert.ok(settings.includes(k), "setting " + k)
assert.ok(/MG\.applyPins\(root\.buildMatugenPalette\(root\.matugenColors\)/.test(svc), "the pins go on the matugen palette")
assert.ok(/MG\.applyArgs\(root\.matugenSeed, root\.matugenContrast\)/.test(svc), "matugen runs with the seed and contrast")
assert.ok(/readonly property string matugenType: MG\.cleanScheme\(SettingsService\.get\("matugen\.scheme"\)\)/.test(svc), "the scheme is the setting")
const board = read("modules/sekai/editMode/EditThemeBoard.qml")
assert.ok(board.includes("EditMatugenControls") && /property bool tuning/.test(board), "the board swaps to the controls")
const tray = read("modules/sekai/editMode/EditTray.qml")
assert.ok(/themeBoard\.tuning/.test(tray), "Esc and the hints know about the controls")
console.log("matugen_unit: all checks passed")
