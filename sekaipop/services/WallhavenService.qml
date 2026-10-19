pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/WallhavenMath.js" as WH

// Wallhaven (wallhaven.cc) as a second source for the Wallpapers picker: search it, page
// through the results, and download one into the wallpaper folder's Wallhaven/ subfolder
// before it is set, so from then on it is an ordinary wallpaper (per monitor, lockscreen,
// presets and the Matugen colours just work). The rules are WallhavenMath.js; the requests
// scripts/wallpapers/wallhaven.sh. docs/WALLHAVEN.md has the whole picture.
//
//   search(query, opts)   a new search (opts: sort, topRange, categories, minWidth,
//                         minHeight, landscape, colour; see WallhavenMath.searchUrl)
//   more()                the next page, added to `items` (the picker calls it near the end)
//   retry()               the last request again, after `error`
//   fetch(item, then)     download `item` (one of `items`) and call then(path)
//
// SFW only, no account. Requests stay under Wallhaven's 45 a minute by themselves.
Singleton {
    id: root

    readonly property string script: Directories.script("wallpapers/wallhaven.sh")
    // Where downloads go: a subfolder of the picker's folder, so they show up in it.
    readonly property string folder: WallpaperService.directory + "/Wallhaven"

    // ===== the results =====
    property var items: []
    property int page: 0
    property int lastPage: 0
    property int total: 0
    property bool loading: false
    // "" | "offline" | "limited" (too many requests) | "failed"
    property string error: ""
    readonly property bool hasMore: root.page > 0 && root.page < root.lastPage

    // What the current results are for (a new search replaces them, more() adds to them).
    property string query: ""
    property var opts: ({})
    property string seed: ""

    // Wallhaven ids already in the folder (the "downloaded" mark).
    property var have: ({})

    function search(query, opts) {
        root.query = String(query || "")
        root.opts = opts || {}
        root.seed = ""
        root.items = []
        root.page = 0
        root.lastPage = 0
        root.total = 0
        root.request(1)
        root.readHave()
    }

    function more() {
        if (root.loading || root.error !== "" || !root.hasMore)
            return
        root.request(root.page + 1)
    }

    function retry() {
        root.error = ""
        root.request(root.page + 1)
    }

    // ===== requests, under the rate limit =====
    property var sent: []
    property int wantPage: 0

    function request(page) {
        root.wantPage = page
        root.loading = true
        const wait = WH.waitFor(root.sent, Date.now())
        if (wait > 0) {
            limitTimer.interval = wait
            limitTimer.restart()
            return
        }
        root.go()
    }

    Timer {
        id: limitTimer
        onTriggered: root.go()
    }

    function go() {
        if (searcher.running) {
            // A newer search waits for the one in flight; its answer is dropped (`for`).
            limitTimer.interval = 150
            limitTimer.restart()
            return
        }
        const o = Object.assign({}, root.opts, { query: root.query, page: root.wantPage, seed: root.seed })
        root.sent = root.sent.filter(t => Date.now() - t < 60000).concat([Date.now()])
        searcher.forPage = root.wantPage
        searcher.forQuery = root.query
        searcher.exec(["sh", root.script, "search", WH.searchUrl(o)])
    }

    Process {
        id: searcher
        property int forPage: 0
        property string forQuery: ""
        property string out: ""

        stdout: StdioCollector {
            onStreamFinished: searcher.out = text
        }

        onExited: (exitCode, exitStatus) => {
            // A search that was replaced while this one ran: not ours any more.
            if (searcher.forQuery !== root.query || searcher.forPage !== root.wantPage)
                return
            root.loading = false
            if (exitCode !== 0) {
                root.error = exitCode === 3 ? "limited" : (exitCode === 5 ? "offline" : "failed")
                return
            }
            const r = WH.parseSearch(searcher.out)
            if (r.error) {
                root.error = "failed"
                return
            }
            root.error = ""
            root.items = searcher.forPage <= 1 ? r.items : root.items.concat(r.items)
            root.page = r.page
            root.lastPage = r.lastPage
            root.total = r.total
            if (r.seed !== "")
                root.seed = r.seed
        }
    }

    // ===== what is already downloaded =====
    function readHave() {
        if (!haver.running)
            haver.exec(["sh", root.script, "have", root.folder])
    }

    function downloaded(item) {
        return !!item && root.have[item.id] === true
    }

    Process {
        id: haver
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {}
                for (const line of text.split("\n")) {
                    if (line !== "")
                        h[line] = true
                }
                root.have = h
            }
        }
    }

    // ===== downloading =====
    // One at a time: the id being fetched ("" = none). A second fetch while one runs
    // replaces what happens when it is done, not the download.
    property string fetching: ""
    property var fetchThen: null

    function fetch(item, then) {
        if (!item || typeof item.full !== "string")
            return
        root.fetchThen = then || null
        if (root.fetching === item.id)
            return
        root.fetching = item.id
        root.error = ""
        fetcher.exec(["sh", root.script, "download", item.full, root.folder, WH.fileName(item)])
    }

    Process {
        id: fetcher
        property string out: ""

        stdout: StdioCollector {
            onStreamFinished: fetcher.out = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            const id = root.fetching
            root.fetching = ""
            if (exitCode !== 0 || fetcher.out === "") {
                root.error = exitCode === 3 ? "limited" : (exitCode === 5 ? "offline" : "failed")
                return
            }
            const h = Object.assign({}, root.have)
            h[id] = true
            root.have = h
            const then = root.fetchThen
            root.fetchThen = null
            if (then)
                then(fetcher.out)
        }
    }
}
