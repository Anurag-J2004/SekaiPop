pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import "../modules/common/functions/WallhavenMath.js" as WH

// Wallhaven (wallhaven.cc) as a second source for the Wallpapers picker: search it, page
// through the results, and download one into the wallpaper folder's Wallhaven/ subfolder
// before it is set, so from then on it is an ordinary wallpaper (per monitor, lockscreen,
// presets and the Matugen colours just work). The rules are WallhavenMath.js; the requests
// scripts/wallpapers/wallhaven.sh. docs/WALLHAVEN.md has the whole picture.
//
//   search(query, w, h)   a new search, with the remembered sort and filters; w x h is the
//                         monitor the picker is on (the "This screen" minimum size)
//   more()                the next page, added to `items` (the picker calls it near the end)
//   retry()               the last request again, after `error` (after `retryIn` for "limited")
//   fetch(item, then)     download `item` (one of `items`) and call then(path); `progress`
//                         follows it, cancelFetch() stops it (Esc in the viewer)
//   setSort / setFilter / resetFilters   the sort menu and the Filters card: remembered
//                         (settings wallhaven.*) and searched again at once
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
    property int screenW: 0
    property int screenH: 0
    property string seed: ""

    // ===== the sort and the filters (remembered: settings wallhaven.*) =====
    readonly property string sort: String(SettingsService.get("wallhaven.sort") || "")
    readonly property string topRange: String(SettingsService.get("wallhaven.topRange") || "1M")
    readonly property var filters: ({
        categories: String(SettingsService.get("wallhaven.categories") || "").split(",").filter(c => WH.CATEGORIES.indexOf(c) >= 0),
        shape: String(SettingsService.get("wallhaven.shape") || "landscape"),
        atLeast: String(SettingsService.get("wallhaven.atLeast") || "screen"),
        colour: String(SettingsService.get("wallhaven.colour") || "")
    })
    readonly property int filterCount: WH.filterCount(root.filters)
    // The sort actually in use ("" means it depends on whether there is text).
    readonly property string sortInUse: root.sort !== "" ? root.sort : WH.defaultSort(root.query)
    readonly property string sortLabel: WH.sortLabel(root.sortInUse, root.topRange)
    readonly property var opts: Object.assign({ sort: root.sortInUse, topRange: root.topRange,
        minWidth: root.screenW, minHeight: root.screenH }, root.filters)
    // The line under the toolbar.
    readonly property string description: WH.describe(Object.assign({ query: root.query }, root.opts))

    function setSort(sort, range) {
        SettingsService.set("wallhaven.sort", sort === "relevance" && root.query.trim() === "" ? "" : sort)
        if (range)
            SettingsService.set("wallhaven.topRange", range)
        root.again()
    }

    // key: "categories" (an array), "shape", "atLeast", "colour".
    function setFilter(key, value) {
        SettingsService.set("wallhaven." + key, Array.isArray(value) ? value.join(",") : String(value))
        root.again()
    }

    function resetFilters() {
        SettingsService.set("wallhaven.categories", WH.DEFAULT_FILTERS.categories.join(","))
        SettingsService.set("wallhaven.shape", WH.DEFAULT_FILTERS.shape)
        SettingsService.set("wallhaven.atLeast", WH.DEFAULT_FILTERS.atLeast)
        SettingsService.set("wallhaven.colour", WH.DEFAULT_FILTERS.colour)
        root.again()
    }

    // The same search with the new sort / filters, from page 1. Bindings settle first.
    function again() {
        Qt.callLater(() => root.search(root.query, root.screenW, root.screenH))
    }

    // Wallhaven ids already in the folder (the "downloaded" mark).
    property var have: ({})

    function search(query, w, h) {
        root.query = String(query || "")
        root.screenW = Math.floor(Number(w)) || 0
        root.screenH = Math.floor(Number(h)) || 0
        root.seed = ""
        root.error = ""
        root.retryAt = 0
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
        if (root.error === "limited" && root.retryIn > 0)
            return
        root.error = ""
        root.request(root.page + 1)
    }

    // "Too many requests": when trying again makes sense (ms since the epoch; 0 = now), and
    // the time left, ticking (the "Try again in 0:22" key).
    property real retryAt: 0
    property real now: Date.now()
    readonly property real retryIn: Math.max(0, root.retryAt - root.now)
    Timer {
        running: root.retryAt > root.now
        interval: 250
        repeat: true
        onTriggered: root.now = Date.now()
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
                if (exitCode === 3) {
                    // Wallhaven doesn't say how long: our own window, at least half a minute.
                    root.retryAt = Date.now() + Math.max(30000, WH.waitFor(root.sent, Date.now()))
                    root.now = Date.now()
                }
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
    property var fetchItem: null
    // Bytes so far and 0..1 (from the .part file's size against the size Wallhaven gave).
    property real fetched: 0
    readonly property real progress: root.fetchItem ? WH.progress(root.fetched, root.fetchItem.size) : 0
    property bool cancelled: false

    function fetch(item, then) {
        if (!item || typeof item.full !== "string")
            return
        root.fetchThen = then || null
        if (root.fetching === item.id || fetcher.running)
            return
        root.fetching = item.id
        root.fetchItem = item
        root.fetched = 0
        root.cancelled = false
        root.error = ""
        fetcher.exec(["sh", root.script, "download", item.full, root.folder, WH.fileName(item)])
    }

    // Esc while downloading: stop, and set nothing (the script's .part is removed below).
    function cancelFetch() {
        if (!fetcher.running)
            return
        root.cancelled = true
        root.fetchThen = null
        fetcher.signal(15)
    }

    // How far the download is: the size of its .part file, a few times a second.
    Timer {
        running: fetcher.running
        interval: 300
        repeat: true
        onTriggered: {
            if (!sizer.running && root.fetchItem)
                sizer.exec(["sh", "-c", 'stat -c %s "$0" 2>/dev/null || echo 0', root.folder + "/" + WH.fileName(root.fetchItem) + ".part"])
        }
    }

    Process {
        id: sizer
        stdout: StdioCollector {
            onStreamFinished: {
                const n = Number(text.trim())
                if (fetcher.running && n > root.fetched)
                    root.fetched = n
            }
        }
    }

    Process {
        id: fetcher
        property string out: ""

        stdout: StdioCollector {
            onStreamFinished: fetcher.out = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            const id = root.fetching
            const item = root.fetchItem
            root.fetching = ""
            root.fetchItem = null
            if (root.cancelled) {
                // Stopped: the script killed its curl and removed the .part itself.
                root.cancelled = false
                return
            }
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
