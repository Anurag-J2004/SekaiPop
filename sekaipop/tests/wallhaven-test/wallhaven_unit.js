// Wallhaven as a picker source: the rules (WallhavenMath.js) one at a time, then
// wallhaven.sh run for real against a fake curl (no network), then the wiring as text.
// Run: node wallhaven_unit.js
const fs = require("fs"), os = require("os"), path = require("path"), assert = require("assert")
const { spawnSync } = require("child_process")
const top = path.join(__dirname, "..", "..")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")
const src = read("modules/common/functions/WallhavenMath.js").replace(".pragma library", "")
const W = {}
new Function("W", src + ";Object.assign(W,{API,SORTS,TOP_RANGES,CATEGORIES,defaultSort,searchUrl,parseSearch,extOf,fileName,idOf,humanSize,waitFor})")(W)
const params = url => Object.fromEntries(new URL(url).searchParams)

// ---------- the search URL ----------
let p = params(W.searchUrl({}))
assert.deepStrictEqual(p, { categories: "111", purity: "100", sorting: "toplist", order: "desc", topRange: "1M", ratios: "landscape" }, "no search: the month's top, landscape, SFW")
p = params(W.searchUrl({ query: " hatsune miku ", minWidth: 2560, minHeight: 1080 }))
assert.strictEqual(p.q, "hatsune miku"); assert.strictEqual(p.sorting, "relevance", "a search sorts by relevance"); assert.strictEqual(p.atleast, "2560x1080"); assert.ok(!("topRange" in p))
p = params(W.searchUrl({ categories: ["anime"], sort: "toplist", topRange: "1w", landscape: false, colour: "#660000", page: 3 }))
assert.strictEqual(p.categories, "010"); assert.strictEqual(p.topRange, "1w"); assert.ok(!("ratios" in p)); assert.strictEqual(p.colors, "660000"); assert.strictEqual(p.page, "3")
assert.strictEqual(params(W.searchUrl({ categories: [] })).categories, "111", "no category at all means all of them")
assert.strictEqual(params(W.searchUrl({ purity: "111" })).purity, "100", "always SFW")
assert.strictEqual(params(W.searchUrl({ sort: "nonsense", query: "x" })).sorting, "relevance")
assert.strictEqual(params(W.searchUrl({ sort: "toplist", topRange: "5y" })).topRange, "1M")
assert.strictEqual(params(W.searchUrl({ sort: "random", seed: "abc123" })).seed, "abc123", "random keeps its seed across pages")
assert.ok(!("seed" in params(W.searchUrl({ sort: "relevance", seed: "abc123", query: "x" }))))
assert.ok(!("colors" in params(W.searchUrl({ colour: "red" }))))
assert.ok(W.searchUrl({}).indexOf(W.API + "?") === 0)

// ---------- the answer ----------
const answer = {
    data: [
        { id: "95kx28", url: "https://wallhaven.cc/w/95kx28", path: "https://w.wallhaven.cc/full/95/wallhaven-95kx28.jpg",
          thumbs: { large: "https://th.wallhaven.cc/lg/95/95kx28.jpg", original: "o", small: "s" },
          dimension_x: 2560, dimension_y: 1440, resolution: "2560x1440", file_size: 1430892, category: "anime", colors: ["#ffffff", "bogus"] },
        { id: "zz", path: "https://w.wallhaven.cc/full/zz/wallhaven-zz.png", thumbs: { small: "s2" } },
        { id: 5, path: "x" }, null
    ],
    meta: { current_page: 2, last_page: 24, per_page: 24, total: 575, seed: null }
}
let r = W.parseSearch(JSON.stringify(answer))
assert.strictEqual(r.items.length, 2, "broken entries skipped")
assert.deepStrictEqual(r.items[0], { id: "95kx28", page: "https://wallhaven.cc/w/95kx28", full: "https://w.wallhaven.cc/full/95/wallhaven-95kx28.jpg",
    thumb: "https://th.wallhaven.cc/lg/95/95kx28.jpg", small: "s", width: 2560, height: 1440, resolution: "2560x1440", size: 1430892,
    type: "jpg", category: "anime", colours: ["#ffffff"] })
assert.strictEqual(r.items[1].thumb, "s2", "falls back to the small thumbnail"); assert.strictEqual(r.items[1].type, "png"); assert.strictEqual(r.items[1].page, "https://wallhaven.cc/w/zz")
assert.deepStrictEqual([r.page, r.lastPage, r.total, r.seed], [2, 24, 575, ""])
assert.deepStrictEqual(W.parseSearch("<html>"), { error: "unreadable" })
assert.deepStrictEqual(W.parseSearch('{"error":"x"}'), { error: "unreadable" })

// ---------- files ----------
assert.strictEqual(W.fileName(r.items[0]), "wallhaven-95kx28.jpg")
assert.strictEqual(W.idOf("/home/a/Pictures/Wallpapers/Wallhaven/wallhaven-95kx28.jpg"), "95kx28")
assert.strictEqual(W.idOf("wallhaven-95kx28.png"), "95kx28")
assert.strictEqual(W.idOf("my-wallhaven-thing.jpg"), "", "only our own names")
assert.strictEqual(W.extOf("https://x/y.JPEG"), "jpg")
assert.strictEqual(W.humanSize(1430892), "1.4 MB"); assert.strictEqual(W.humanSize(2048), "2 KB"); assert.strictEqual(W.humanSize(12), "12 B")

// ---------- the rate limit ----------
const now = 1000000
assert.strictEqual(W.waitFor([], now), 0)
assert.strictEqual(W.waitFor(Array.from({ length: 39 }, (_, i) => now - i * 100), now), 0, "39 in a minute: fine")
const forty = Array.from({ length: 40 }, (_, i) => now - 50000 + i)
assert.strictEqual(W.waitFor(forty, now), 10050, "the 41st waits until the oldest is a minute old")
assert.strictEqual(W.waitFor(forty.map(t => t - 20000), now), 0, "older than a minute doesn't count")

// ---------- the script, against a fake curl ----------
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "wallhaven-"))
try {
    const bin = path.join(tmp, "bin"); fs.mkdirSync(bin)
    // FAKE_CODE: the HTTP status to answer; FAKE_FAIL=1: can't connect.
    fs.writeFileSync(path.join(bin, "curl"), `#!/bin/sh
[ "$FAKE_FAIL" = 1 ] && exit 6
out=""; prev=""; for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; prev="$a"; done
body="$FAKE_BODY"; [ -n "$body" ] || body='{"data":[]}'
printf '%s' "$body" > "$out"
printf '%s' "\${FAKE_CODE:-200}"
`, { mode: 0o755 })
    const run = (env, ...a) => spawnSync("/bin/sh", [path.join(top, "scripts", "wallpapers", "wallhaven.sh"), ...a],
        { env: Object.assign({}, process.env, { PATH: bin + ":/usr/bin:/bin" }, env), encoding: "utf8" })
    const S = "https://wallhaven.cc/api/v1/search?q=x"
    let o = run({ FAKE_BODY: '{"data":[1]}' }, "search", S)
    assert.strictEqual(o.status, 0, o.stderr); assert.strictEqual(o.stdout, '{"data":[1]}')
    assert.strictEqual(run({ FAKE_CODE: "429" }, "search", S).status, 3, "too many requests")
    assert.strictEqual(run({ FAKE_CODE: "500" }, "search", S).status, 4)
    assert.strictEqual(run({ FAKE_FAIL: "1" }, "search", S).status, 5, "offline")
    assert.strictEqual(run({}, "search", "https://example.com/api").status, 2, "only Wallhaven's API")

    const dir = path.join(tmp, "Wallpapers", "Wallhaven")
    const IMG = "https://w.wallhaven.cc/full/95/wallhaven-95kx28.jpg"
    o = run({ FAKE_BODY: "JPEGDATA" }, "download", IMG, dir, "wallhaven-95kx28.jpg")
    assert.strictEqual(o.status, 0, o.stderr)
    assert.strictEqual(o.stdout.trim(), path.join(dir, "wallhaven-95kx28.jpg"))
    assert.strictEqual(fs.readFileSync(path.join(dir, "wallhaven-95kx28.jpg"), "utf8"), "JPEGDATA")
    assert.ok(!fs.readdirSync(dir).some(f => f.endsWith(".part")), "no .part left")
    o = run({ FAKE_FAIL: "1" }, "download", IMG, dir, "wallhaven-95kx28.jpg")
    assert.strictEqual(o.status, 0, "already there: no network needed"); assert.strictEqual(o.stdout.trim(), path.join(dir, "wallhaven-95kx28.jpg"))
    o = run({ FAKE_CODE: "404" }, "download", "https://w.wallhaven.cc/full/aa/wallhaven-aa.png", dir, "wallhaven-aa.png")
    assert.strictEqual(o.status, 4); assert.ok(!fs.existsSync(path.join(dir, "wallhaven-aa.png")) && !fs.existsSync(path.join(dir, "wallhaven-aa.png.part")), "a failed download leaves nothing")
    assert.strictEqual(run({}, "download", "https://evil.example/x.jpg", dir, "wallhaven-x.jpg").status, 2, "only Wallhaven's images")
    assert.strictEqual(run({}, "download", IMG, dir, "../../.bashrc").status, 2, "only our own file names")
    assert.strictEqual(run({}, "download", IMG, dir, "wallhaven-a/../b.jpg").status, 2)
    o = run({}, "have", dir)
    assert.deepStrictEqual(o.stdout.trim().split("\n"), ["95kx28"])
    assert.strictEqual(run({}, "have", path.join(tmp, "nope")).stdout, "", "no folder yet: nothing")
} finally {
    fs.rmSync(tmp, { recursive: true, force: true })
}

// ---------- the wiring ----------
const svc = read("services/WallhavenService.qml")
assert.ok(/WH\.searchUrl\(o\)/.test(svc) && /WH\.parseSearch\(searcher\.out\)/.test(svc), "the service builds and reads through WallhavenMath")
assert.ok(/WH\.waitFor\(root\.sent, Date\.now\(\)\)/.test(svc), "it keeps under the rate limit")
assert.ok(/WallpaperService\.directory \+ "\/Wallhaven"/.test(svc), "downloads go into the picker's folder")
console.log("wallhaven_unit: all checks passed")
