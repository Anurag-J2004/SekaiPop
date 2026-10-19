.pragma library

// The Matugen theme's knobs (Edit Desktop > THEME, the Matugen tile's controls:
// EditMatugenControls.qml; ThemeService.qml runs matugen with them). Pure functions on
// plain values, so they can be unit-tested with node: tests/matugen-test/matugen_unit.js.
//
// The settings (SettingsService.qml), each cleaned by the function next to it:
//   matugen.scheme    a matugen --type, "scheme-tonal-spot" by default     cleanScheme()
//   matugen.seed      which of the wallpaper's colours leads: -1 = matugen's
//                     own choice (Auto), else an index into its list       cleanSeed()
//   matugen.contrast  matugen's --contrast, one of CONTRASTS               cleanContrast()
//   matugen.pinA/B    "" or "#rrggbb": that accent stays this colour
//                     whatever the wallpaper says                          cleanHex()

// In the order the controls show them; `label` is the key's text.
var SCHEMES = [
    { id: "scheme-tonal-spot", label: "Tonal" },
    { id: "scheme-vibrant", label: "Vibrant" },
    { id: "scheme-expressive", label: "Expressive" },
    { id: "scheme-fidelity", label: "Fidelity" },
    { id: "scheme-content", label: "Content" },
    { id: "scheme-neutral", label: "Neutral" },
    { id: "scheme-monochrome", label: "Mono" },
    { id: "scheme-rainbow", label: "Rainbow" },
    { id: "scheme-fruit-salad", label: "Fruit salad" }
]
var DEFAULT_SCHEME = "scheme-tonal-spot"

// matugen takes any number from -1 to 1; the controls offer five steps.
var CONTRASTS = [
    { value: -1, label: "−1" },
    { value: -0.5, label: "−½" },
    { value: 0, label: "0" },
    { value: 0.5, label: "+½" },
    { value: 1, label: "+1" }
]

function cleanScheme(id) {
    for (var i = 0; i < SCHEMES.length; i++) {
        if (SCHEMES[i].id === id)
            return id
    }
    return DEFAULT_SCHEME
}

// The nearest of the five steps (a hand-edited 0.4 becomes 0.5).
function cleanContrast(v) {
    var n = Number(v)
    if (!isFinite(n))
        return 0
    var best = CONTRASTS[0].value
    for (var i = 1; i < CONTRASTS.length; i++) {
        if (Math.abs(CONTRASTS[i].value - n) < Math.abs(best - n))
            best = CONTRASTS[i].value
    }
    return best
}

// -1 (Auto) unless it names one of the `count` colours this wallpaper has. A seed
// picked on another wallpaper keeps its number but only applies while there is a
// colour with that number; otherwise the wallpaper leads with its own choice.
function cleanSeed(index, count) {
    var i = Math.floor(Number(index))
    if (!isFinite(i) || i < 0 || i >= count)
        return -1
    return i
}

// "#rrggbb" (lower case), or "" for anything that isn't a colour. Takes "ffb68e",
// "#FFB68E" and the short "#fb8".
function cleanHex(s) {
    var t = String(s === undefined || s === null ? "" : s).trim().toLowerCase()
    if (t.charAt(0) === "#")
        t = t.slice(1)
    if (/^[0-9a-f]{3}$/.test(t))
        t = t.charAt(0) + t.charAt(0) + t.charAt(1) + t.charAt(1) + t.charAt(2) + t.charAt(2)
    return /^[0-9a-f]{6}$/.test(t) ? "#" + t : ""
}

// The wallpaper's candidate colours out of `matugen image --show-source-colors`
// (matugen-state.sh sources): one "#rrggbb" per line, maybe with other text or
// terminal colour codes around it. In order, without repeats.
function parseSources(text) {
    var out = []
    var lines = String(text || "").replace(/\u001b\[[0-9;]*m/g, "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/#[0-9a-fA-F]{6}\b/)
        if (!m)
            continue
        var hex = m[0].toLowerCase()
        if (out.indexOf(hex) < 0)
            out.push(hex)
    }
    return out
}

// The shell palette with the pinned accents in place of matugen's. Only A and B
// change: the rest (borders, surfaces, the phone's plastics) still come from the
// wallpaper. A new object; `palette` is not touched. null stays null.
function applyPins(palette, pinA, pinB) {
    if (!palette)
        return palette
    var a = cleanHex(pinA)
    var b = cleanHex(pinB)
    if (a === "" && b === "")
        return palette
    var out = {}
    for (var k in palette)
        out[k] = palette[k]
    if (a !== "")
        out.A = a
    if (b !== "")
        out.B = b
    return out
}

// The extra arguments matugen-state.sh `apply` takes after the scheme and the output
// name: the seed index ("0" for Auto, matugen's own first pick) and the contrast.
function applyArgs(seed, contrast) {
    return [String(seed >= 0 ? seed : 0), String(cleanContrast(contrast))]
}
