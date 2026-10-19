// node tests/keys-test/keys_script_test.js   (run from the sekaipop folder)
// scripts/hyprland/keybinds.sh against a throwaway config folder: which format is in
// use, whether the override file is linked (through nested `source` lines too), and
// that writing the block keeps every line that isn't ours.
const fs = require("fs"), os = require("os"), path = require("path")
const { execFileSync } = require("child_process")
const locate = require("../lib/locate.js")
const script = locate("scripts/hyprland/keybinds.sh")

let fails = 0
function eq(a, b, msg) {
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}

function setup(files) {
    const cfg = fs.mkdtempSync(path.join(os.tmpdir(), "sekaipop-keys-"))
    fs.mkdirSync(path.join(cfg, "hypr"))
    for (const [name, text] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(cfg, "hypr", name)), { recursive: true })
        fs.writeFileSync(path.join(cfg, "hypr", name), text)
    }
    return cfg
}
// PATH without hyprctl, so `call` and `reload` never reach a running Hyprland.
const run = (cfg, ...args) => execFileSync("sh", [script, ...args],
    { env: { HOME: cfg, XDG_CONFIG_HOME: cfg, PATH: "/usr/bin:/bin" }, encoding: "utf8" })
const read = (cfg, name) => fs.readFileSync(path.join(cfg, "hypr", name), "utf8")

const dirs = []
try {
    // hyprland.conf, linked two levels down through a relative and a ~ path
    let c = setup({
        "hyprland.conf": "source = parts/main.conf\n",
        "parts/main.conf": "bind = SUPER, Q, killactive\nsource = ~/hypr/parts/last.conf # the end\n",
        "parts/last.conf": "source = $HOME/hypr/sekaipop_overrides.conf\n"
    })
    dirs.push(c)
    eq(run(c, "check"), `mode=conf\nlinked=yes\nfile=${c}/hypr/sekaipop_overrides.conf\n`, "conf, linked through nested sources")

    c = setup({ "hyprland.conf": "bind = SUPER, Q, killactive\n" })
    dirs.push(c)
    eq(run(c, "check").split("\n")[1], "linked=no", "conf without the source line")

    c = setup({ "hyprland.lua": 'pcall(require, "sekaipop_overrides")\n' })
    dirs.push(c)
    eq(run(c, "check").split("\n").slice(0, 2), ["mode=lua", "linked=yes"], "Lua, linked")

    // Writing: other lines stay, the block is replaced in place, "" removes it.
    fs.writeFileSync(path.join(c, "hypr", "sekaipop_overrides.lua"),
        "hl.config({ general = { gaps_in = 5 } }) -- sekaipop:hypr:general.gaps_in\n")
    const b1 = "-- sekaipop:keys:begin\n-- sekaipop:keys {}\npcall(hl.unbind, [==[SUPER + A]==])\n-- sekaipop:keys:end\n"
    run(c, "write", b1)
    eq(read(c, "sekaipop_overrides.lua"),
        "hl.config({ general = { gaps_in = 5 } }) -- sekaipop:hypr:general.gaps_in\n" + b1, "the block is added after the other lines")
    fs.appendFileSync(path.join(c, "hypr", "sekaipop_overrides.lua"), "hl.config({}) -- sekaipop:hypr:later\n")
    const b2 = "-- sekaipop:keys:begin\n-- sekaipop:keys {\"x\":1}\n-- sekaipop:keys:end\n"
    run(c, "write", b2)
    eq(read(c, "sekaipop_overrides.lua"),
        "hl.config({ general = { gaps_in = 5 } }) -- sekaipop:hypr:general.gaps_in\n" + b2 + "hl.config({}) -- sekaipop:hypr:later\n",
        "a new block replaces the old one where it was")
    run(c, "write", "")
    eq(read(c, "sekaipop_overrides.lua"),
        "hl.config({ general = { gaps_in = 5 } }) -- sekaipop:hypr:general.gaps_in\nhl.config({}) -- sekaipop:hypr:later\n",
        "an empty block removes ours and nothing else")
    eq(run(c, "read"), read(c, "sekaipop_overrides.lua"), "read prints the file")

    // A missing override file is created by the first write.
    c = setup({ "hyprland.conf": "" })
    dirs.push(c)
    run(c, "write", "# sekaipop:keys:begin\n# sekaipop:keys:end\n")
    eq(read(c, "sekaipop_overrides.conf"), "# sekaipop:keys:begin\n# sekaipop:keys:end\n", "the first write creates the file")

    // `call` splits each call on \037 and nothing else (a field keeps its commas,
    // spaces and quotes). A fake hyprctl records what it was given.
    const bin = path.join(c, "bin")
    fs.mkdirSync(bin)
    fs.writeFileSync(path.join(bin, "hyprctl"),
        `#!/bin/sh\nfor a in "$@"; do printf '[%s]' "$a"; done >> "${c}/calls"\necho >> "${c}/calls"\necho ok\n`, { mode: 0o755 })
    execFileSync("sh", [script, "call", "keyword\x1funbind\x1fSUPER SHIFT, E",
        "eval\x1fpcall(hl.bind, [==[SUPER + O]==], hl.dsp.exec_cmd([==[a \"b\"; c]==]))"],
        { env: { HOME: c, XDG_CONFIG_HOME: c, PATH: bin + ":/usr/bin:/bin" }, encoding: "utf8" })
    eq(fs.readFileSync(path.join(c, "calls"), "utf8"),
        "[keyword][unbind][SUPER SHIFT, E]\n[eval][pcall(hl.bind, [==[SUPER + O]==], hl.dsp.exec_cmd([==[a \"b\"; c]==]))]\n",
        "each call reaches hyprctl as its own fields")
} finally {
    for (const d of dirs) fs.rmSync(d, { recursive: true, force: true })
}

if (fails) { console.log(fails + " failed"); process.exit(1) }
console.log("keys script: all passed")
