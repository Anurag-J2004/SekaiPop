.pragma library

// Shared numbers for the equalizer card (EqualizerPopup.qml and its Pad*.qml
// parts). Everything is in the screen's own design pixels: the chart is
// 460 x 270, ten lanes of 46 at the bottom edge, narrowing toward the top like a
// rhythm game's highway.

var TOP = 34        // top of the lanes
var BOT = 234       // the judgement line (the lowest edge of the lanes)
var ZERO = 134      // where 0 dB sits
var PER_DB = 8      // pixels for one dB
var LW = 46         // a lane's width at the bottom
var CX = 230        // the middle of the screen

var GROUPS = ["#FF9ECB", "#8EE3EF", "#B39DDB"]       // bass, mids, treble
var LIGHT = ["#ffc2de", "#bdf1fa", "#d3c6fb"]
var DARK = ["#ff7fb6", "#36c2dd", "#8a6fd8"]
var HZ = ["32 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]
var LABELS = ["32", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

function group(i) {
    return i < 2 ? 0 : (i < 7 ? 1 : 2)
}

function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
}

// How much narrower the highway is at height y (1 at the bottom).
function s(y) {
    return 0.74 + 0.26 * (y - TOP) / (BOT - TOP)
}

function laneX(i, y) {
    return CX + (23 + i * LW - CX) * s(y)
}

function laneEdge(i, y) {
    return CX + (i * LW - CX) * s(y)
}

function gainToY(g) {
    return ZERO - g * PER_DB
}

function yToGain(y, range) {
    var g = (ZERO - y) / PER_DB
    return Math.max(-range, Math.min(range, g))
}

// Which lane a point is over (-1: none).
function laneAt(x, y) {
    var yy = Math.max(TOP, Math.min(BOT, y))
    var i = Math.floor((x - CX) / (LW * s(yy)) + 5)
    return (i < 0 || i > 9) ? -1 : i
}

// A smooth line through points (Catmull-Rom as bezier), drawn onto a canvas context.
function smooth(ctx, pts) {
    ctx.moveTo(pts[0].x, pts[0].y)
    for (var i = 0; i < pts.length - 1; i++) {
        var p0 = pts[Math.max(i - 1, 0)]
        var p1 = pts[i]
        var p2 = pts[i + 1]
        var p3 = pts[Math.min(i + 2, pts.length - 1)]
        ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                          p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
                          p2.x, p2.y)
    }
}

function rr(ctx, x, y, w, h, r) {
    ctx.roundedRect(x, y, w, h, r, r)
}

// "#rrggbb" + alpha -> "rgba(r,g,b,a)" for canvas styles.
function rgba(hex, a) {
    var n = parseInt(hex.slice(1), 16)
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")"
}
