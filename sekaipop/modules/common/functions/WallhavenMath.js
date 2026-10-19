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
var CATEGORY_LABELS = { general: "General", anime: "Anime", people: "People" }

// The Filters card's choices. `ratios` is what Wallhaven gets ("" = no filter).
var SHAPES = [
    { id: "landscape", label: "Landscape", ratios: "landscape" },
    { id: "16x9", label: "16:9", ratios: "16x9" },
    { id: "16x10", label: "16:10", ratios: "16x10" },
    { id: "21x9", label: "21:9", ratios: "21x9" },
    { id: "32x9", label: "32:9", ratios: "32x9" },
    { id: "any", label: "Any", ratios: "" }
]
// "screen" = the monitor the picker is on.
var AT_LEAST = [
    { id: "screen", label: "This screen" },
    { id: "1920x1080", label: "1920\u00d71080" },
    { id: "3840x2160", label: "3840\u00d72160" },
    { id: "any", label: "Any size" }
]
// Wallhaven's colour filter only takes these.
var COLOURS = ["#660000", "#990000", "#cc0000", "#cc3333", "#ea4c88", "#993399", "#663399", "#333399",
    "#0066cc", "#0099cc", "#66cccc", "#77cc33", "#669900", "#336600", "#666600", "#999900", "#cccc33",
    "#ffff00", "#ffcc33", "#ff9900", "#ff6600", "#cc6633", "#996633", "#663300", "#000000", "#999999",
    "#cccccc", "#ffffff", "#424153"]

// The filters as nothing has been changed: what Reset puts back, and what the badge counts
// against.
var DEFAULT_FILTERS = { categories: ["general", "anime", "people"], shape: "landscape", atLeast: "screen", colour: "" }

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

// The search URL. `o`: { query, sort, topRange, categories: ["general", ...], shape (a
// SHAPES id), atLeast (an AT_LEAST id, "screen" = minWidth x minHeight), minWidth,
// minHeight, colour: one of COLOURS or "", page, seed }. Anything missing or invalid falls
// back to the default filter (DEFAULT_FILTERS) or Wallhaven's own default.
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
    var size = atLeastSize(o)
    if (size !== "")
        add("atleast", size)
    var shape = shapeOf(o.shape)
    if (shape.ratios !== "")
        add("ratios", shape.ratios)
    var c = String(o.colour || "").toLowerCase()
    if (COLOURS.indexOf(c) >= 0)
        add("colors", c.slice(1))
    var page = Math.floor(Number(o.page))
    if (page > 1)
        add("page", String(page))
    if (sort === "random" && /^[A-Za-z0-9]{6}$/.test(String(o.seed || "")))
        add("seed", o.seed)
    return API + "?" + p.join("&")
}

function shapeOf(id) {
    for (var i = 0; i < SHAPES.length; i++) {
        if (SHAPES[i].id === id)
            return SHAPES[i]
    }
    return SHAPES[0]
}

// "2560x1440" for Wallhaven's atleast, or "" for none.
function atLeastSize(o) {
    var a = o && typeof o.atLeast === "string" ? o.atLeast : "screen"
    if (a === "any")
        return ""
    if (/^[0-9]+x[0-9]+$/.test(a))
        return a
    var w = Math.floor(Number(o && o.minWidth)), h = Math.floor(Number(o && o.minHeight))
    return w > 0 && h > 0 ? w + "x" + h : ""
}

// How many filters differ from DEFAULT_FILTERS (the Filters key's badge).
function filterCount(f) {
    f = f || {}
    var n = 0
    var cats = Array.isArray(f.categories) ? f.categories : DEFAULT_FILTERS.categories
    if (cats.length > 0 && cats.length < CATEGORIES.length)
        n++
    if (shapeOf(f.shape).id !== DEFAULT_FILTERS.shape)
        n++
    if ((f.atLeast || "screen") !== DEFAULT_FILTERS.atLeast)
        n++
    if (COLOURS.indexOf(String(f.colour || "").toLowerCase()) >= 0)
        n++
    return n
}

var RANGE_WORDS = { "1d": "today", "3d": "over 3 days", "1w": "this week", "1M": "this month",
    "3M": "over 3 months", "6M": "over 6 months", "1y": "this year" }

// The sort key's text: "Top \u00b7 Month", "Relevance", ...
function sortLabel(sort, topRange) {
    for (var i = 0; i < SORTS.length; i++) {
        if (SORTS[i].id !== sort)
            continue
        if (sort !== "toplist")
            return SORTS[i].label
        for (var j = 0; j < TOP_RANGES.length; j++) {
            if (TOP_RANGES[j].id === topRange)
                return "Top \u00b7 " + TOP_RANGES[j].label
        }
        return "Top \u00b7 Month"
    }
    return "Relevance"
}

// The line under the toolbar: what is being shown. "Top this month on Wallhaven \u00b7
// 2560\u00d71440 and up \u00b7 landscape".
function describe(o) {
    o = o || {}
    var q = String(o.query || "").trim()
    var sort = has(SORTS, o.sort) ? o.sort : defaultSort(q)
    var what
    if (q !== "")
        what = "\u201c" + q + "\u201d on Wallhaven"
    else if (sort === "toplist")
        what = "Top " + (RANGE_WORDS[o.topRange] || RANGE_WORDS["1M"]) + " on Wallhaven"
    else if (sort === "date_added")
        what = "Latest on Wallhaven"
    else if (sort === "views")
        what = "Most viewed on Wallhaven"
    else if (sort === "favorites")
        what = "Most favourited on Wallhaven"
    else if (sort === "random")
        what = "Random on Wallhaven"
    else
        what = "Wallhaven"
    var parts = [what]
    var size = atLeastSize(o)
    if (size !== "")
        parts.push(size.replace("x", "\u00d7") + " and up")
    var shape = shapeOf(o.shape)
    if (shape.id !== "any")
        parts.push(shape.id === "landscape" ? "landscape" : shape.label)
    var cats = Array.isArray(o.categories) ? o.categories : CATEGORIES
    if (cats.length > 0 && cats.length < CATEGORIES.length)
        parts.push(cats.map(function (c) { return CATEGORY_LABELS[c] }).join(" + "))
    return parts.join(" \u00b7 ")
}

// The filters that are on, as a sentence for "nothing found": "With 2 filters on: People
// only, and at least 3840\u00d72160." "" when none are.
function filtersSentence(f) {
    f = f || {}
    var bits = []
    var cats = Array.isArray(f.categories) ? f.categories : CATEGORIES
    if (cats.length > 0 && cats.length < CATEGORIES.length)
        bits.push(cats.map(function (c) { return CATEGORY_LABELS[c] }).join(" and ") + " only")
    var shape = shapeOf(f.shape)
    if (shape.id !== DEFAULT_FILTERS.shape)
        bits.push(shape.id === "any" ? "any shape" : shape.label + " only")
    if ((f.atLeast || "screen") !== DEFAULT_FILTERS.atLeast)
        bits.push(f.atLeast === "any" ? "any size" : "at least " + String(f.atLeast).replace("x", "\u00d7"))
    if (COLOURS.indexOf(String(f.colour || "").toLowerCase()) >= 0)
        bits.push("mostly " + String(f.colour).toLowerCase())
    if (bits.length === 0)
        return ""
    var list = bits.length === 1 ? bits[0] : bits.slice(0, -1).join(", ") + ", and " + bits[bits.length - 1]
    return "With " + bits.length + (bits.length === 1 ? " filter" : " filters") + " on: " + list + "."
}

// 0..1 of a download (`have` bytes of `total`); 0 when the size isn't known.
function progress(have, total) {
    var h = Number(have) || 0, t = Number(total) || 0
    return t > 0 ? Math.max(0, Math.min(1, h / t)) : 0
}

// 22000 -> "0:22"
function countdown(ms) {
    var s = Math.max(0, Math.ceil((Number(ms) || 0) / 1000))
    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
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
            views: Number(d.views) || 0,
            favourites: Number(d.favorites) || 0,
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

// The file a download is saved as, in the wallpaper folder: the id keeps it findable
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
