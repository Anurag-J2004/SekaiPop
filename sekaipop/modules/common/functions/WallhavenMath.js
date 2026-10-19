.pragma library

// Wallhaven (wallhaven.cc) as a source for the Wallpapers picker: the search URL, the
// answer read into the picker's items, and the file names a download gets. Pure functions,
// unit-tested with node: tests/wallhaven-test/wallhaven_unit.js. WallhavenService.qml runs
// the requests (scripts/wallpapers/wallhaven.sh). API: https://wallhaven.cc/help/api
//
// SFW only: purity is always 100 and there is no API key (it is only needed for NSFW).

var API = "https://wallhaven.cc/api/v1/search"

// `id` is Wallhaven's `sorting`; `label` what a control would say.
var SORTS = [
    { id: "relevance", label: "Relevance" },
    { id: "toplist", label: "Top" },
    { id: "date_added", label: "Latest" },
    { id: "views", label: "Views" },
    { id: "favorites", label: "Favourites" },
    { id: "random", label: "Random" }
]

// Only for "toplist".
var TOP_RANGES = [
    { id: "1d", label: "Day" },
    { id: "3d", label: "3 days" },
    { id: "1w", label: "Week" },
    { id: "1M", label: "Month" },
    { id: "3M", label: "3 months" },
    { id: "6M", label: "6 months" },
    { id: "1y", label: "Year" }
]

var CATEGORIES = ["general", "anime", "people"]

function has(list, id) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === id)
            return true
    }
    return false
}

// What to sort by when nothing was chosen: relevance for a search, the month's top
// otherwise (an empty search sorted by relevance is just noise).
function defaultSort(query) {
    return String(query || "").trim() !== "" ? "relevance" : "toplist"
}

// The search URL. `o`: { query, sort, topRange, categories: ["general", ...], minWidth,
// minHeight, landscape, colour: "#rrggbb" or "", page, seed }. Anything missing or invalid
// falls back to Wallhaven's own default for it.
function searchUrl(o) {
    o = o || {}
    var p = []
    var add = function (k, v) { p.push(k + "=" + encodeURIComponent(v)) }
    var q = String(o.query || "").trim()
    if (q !== "")
        add("q", q)
    var cats = Array.isArray(o.categories) ? o.categories : CATEGORIES
    var bits = ""
    for (var i = 0; i < CATEGORIES.length; i++)
        bits += cats.indexOf(CATEGORIES[i]) >= 0 ? "1" : "0"
    add("categories", bits === "000" ? "111" : bits)
    add("purity", "100")
    var sort = has(SORTS, o.sort) ? o.sort : defaultSort(q)
    add("sorting", sort)
    add("order", "desc")
    if (sort === "toplist")
        add("topRange", has(TOP_RANGES, o.topRange) ? o.topRange : "1M")
    var w = Math.floor(Number(o.minWidth)), h = Math.floor(Number(o.minHeight))
    if (w > 0 && h > 0)
        add("atleast", w + "x" + h)
    if (o.landscape !== false)
        add("ratios", "landscape")
    var c = String(o.colour || "").replace("#", "").toLowerCase()
    if (/^[0-9a-f]{6}$/.test(c))
        add("colors", c)
    var page = Math.floor(Number(o.page))
    if (page > 1)
        add("page", String(page))
    if (sort === "random" && /^[A-Za-z0-9]{6}$/.test(String(o.seed || "")))
        add("seed", o.seed)
    return API + "?" + p.join("&")
}

// Wallhaven's answer as { items, page, lastPage, total, seed }, or { error } when it is not
// one. Each item: { id, page (wallhaven.cc page), full (the image), thumb (large), small,
// width, height, resolution, size (bytes), type ("jpg" / "png"), category, colours }.
function parseSearch(text) {
    var j = null
    try {
        j = JSON.parse(String(text || ""))
    } catch (e) {
        return { error: "unreadable" }
    }
    if (!j || !Array.isArray(j.data))
        return { error: "unreadable" }
    var items = []
    for (var i = 0; i < j.data.length; i++) {
        var d = j.data[i]
        if (!d || typeof d.id !== "string" || typeof d.path !== "string" || !d.thumbs)
            continue
        items.push({
            id: d.id,
            page: typeof d.url === "string" ? d.url : "https://wallhaven.cc/w/" + d.id,
            full: d.path,
            thumb: d.thumbs.large || d.thumbs.original || d.thumbs.small || "",
            small: d.thumbs.small || d.thumbs.large || "",
            width: Number(d.dimension_x) || 0,
            height: Number(d.dimension_y) || 0,
            resolution: typeof d.resolution === "string" ? d.resolution : "",
            size: Number(d.file_size) || 0,
            type: extOf(d.path),
            category: typeof d.category === "string" ? d.category : "",
            colours: Array.isArray(d.colors) ? d.colors.filter(function (c) { return /^#[0-9a-fA-F]{6}$/.test(c) }) : []
        })
    }
    var m = j.meta || {}
    return {
        items: items,
        page: Number(m.current_page) || 1,
        lastPage: Number(m.last_page) || 1,
        total: Number(m.total) || items.length,
        seed: typeof m.seed === "string" ? m.seed : ""
    }
}

// "jpg" / "png" from an image URL ("jpg" if it can't tell).
function extOf(url) {
    var m = String(url || "").match(/\.([A-Za-z0-9]+)(?:\?.*)?$/)
    var e = m ? m[1].toLowerCase() : "jpg"
    return e === "jpeg" ? "jpg" : (e === "png" || e === "jpg" || e === "webp" ? e : "jpg")
}

// The file a download is saved as, in the Wallhaven/ subfolder: the id keeps it findable
// ("already downloaded") and keeps two downloads of one picture from piling up.
function fileName(item) {
    return "wallhaven-" + item.id + "." + (item.type || extOf(item.full))
}

// The Wallhaven id of a file name (fileName()'s), or "".
function idOf(name) {
    var m = String(name || "").match(/(?:^|\/)wallhaven-([a-z0-9]+)\.[a-z0-9]+$/)
    return m ? m[1] : ""
}

// 1430892 -> "1.4 MB"
function humanSize(bytes) {
    var b = Number(bytes) || 0
    if (b >= 1048576)
        return (Math.round(b / 104857.6) / 10) + " MB"
    if (b >= 1024)
        return Math.round(b / 1024) + " KB"
    return b + " B"
}

// May a request go now? `times`: when the last ones went (ms). Wallhaven allows 45 a minute;
// this keeps under 40, so a burst of scrolling never earns the "too many requests" pause.
// Returns 0 to go now, else how many ms to wait.
function waitFor(times, now) {
    var recent = times.filter(function (t) { return now - t < 60000 })
    if (recent.length < 40)
        return 0
    return 60000 - (now - Math.min.apply(null, recent)) + 50
}
