// Clicking beside the Quick Panel's phone closes it, even in the empty corners of the
// box around the tilted phone (issue #47). The outline math (PhoneMath.js silhouette /
// insideConvex) runs here for the real 2.5D and 2D poses; the wiring is checked as text.
// Run: node tests/phone-test/click_away_test.js
const fs = require("fs"), assert = require("assert")
const locate = require("../lib/locate")
const read = f => fs.readFileSync(locate(f), "utf8")
const PM = new Function(read("modules/common/functions/PhoneMath.js").replace(".pragma library", "")
    + "; return { build, silhouette, hull, insideConvex, apply }")()

// The Quick phone's design (PhoneBody defaults the panel keeps: 654 x 1214 face) and its
// two poses: 2.5D (yaw 33, pitch 18) and 2D (facing straight on).
const body = read("modules/sekai/phone/PhoneBody.qml")
const num = name => Number(body.match(new RegExp("property real " + name + ": ([0-9.]+)"))[1])
const W = num("faceWidth"), H = num("faceHeight"), T = num("thickness"), R = num("cornerRadius"), D = num("perspective")

// ---------- hull and inside ----------
const square = PM.hull([[0, 0], [10, 0], [10, 10], [0, 10], [5, 5], [2, 8]])
assert.strictEqual(square.length, 4, "the hull drops the points inside")
assert.ok(PM.insideConvex(square, 5, 5) && PM.insideConvex(square, 0.5, 9.5), "inside")
assert.ok(!PM.insideConvex(square, 11, 5) && !PM.insideConvex(square, -1, -1), "outside")
assert.ok(PM.insideConvex(square, 11, 5, 2) && !PM.insideConvex(square, 13, 5, 2), "slack reaches that far past the edge, no further")
assert.ok(!PM.insideConvex([[0, 0], [1, 1]], 0, 0), "no polygon, nothing is inside")

// ---------- the tilted phone ----------
const tilted = PM.build(W, H, T, R, 33, 18, 0, D, 4)
const poly = PM.silhouette(W, H, T, R, tilted.base, [])
const at = (x, y, z) => { const p = PM.apply(tilted.base, x, y, z || 0); return [p.x, p.y] }
// Everything on the phone is in it: the screen's middle and corners, the back's corners.
for (const [x, y, z] of [[W / 2, H / 2, 0], [R, R, 0], [W - R, H - R, 0], [W - R, R, -T], [R, H - R, -T]])
    assert.ok(PM.insideConvex(poly, ...at(x, y, z), 0.5), "on the phone: " + [x, y, z])
// The box's corners are not (the issue's screenshot: the empty upper left and lower right).
const box = { x0: tilted.pad, y0: tilted.pad, x1: tilted.w - tilted.pad, y1: tilted.h - tilted.pad }
const corners = [[box.x0 + 2, box.y0 + 2], [box.x1 - 2, box.y0 + 2], [box.x0 + 2, box.y1 - 2], [box.x1 - 2, box.y1 - 2]]
const outside = corners.filter(c => !PM.insideConvex(poly, c[0], c[1], 3))
assert.ok(outside.length >= 3, "most of the box's corners are beside the phone, not on it (" + outside.length + " of 4)")
// A real share of the box is empty: that is what used to swallow the click.
let empty = 0, n = 0
for (let x = box.x0; x < box.x1; x += 8)
    for (let y = box.y0; y < box.y1; y += 8, n++)
        if (!PM.insideConvex(poly, x, y, 3)) empty++
assert.ok(empty / n > 0.12, "the box around the tilted phone is more than an eighth empty (" + Math.round(100 * empty / n) + "%)")
// Side buttons stand out of the wall: with them in, a point on the button is in.
const stick = 14
const withButtons = PM.silhouette(W, H, T, R, tilted.base, [[W, 704, -T * 0.68, W + stick, 872, -T * 0.24]])
const btn = at(W + stick, 790, -T * 0.46)
assert.ok(PM.insideConvex(withButtons, btn[0], btn[1], 0.5), "the side button's face is on the phone")

// ---------- the flat (2D) phone ----------
const flat = PM.build(W, H, T, R, 0, 0, 0, D, 4)
const fpoly = PM.silhouette(W, H, 0, R, flat.base, [[W - 4, 338, 0, W + 18, 488, 0]])
const fat = (x, y) => { const p = PM.apply(flat.base, x, y, 0); return [p.x, p.y] }
assert.ok(PM.insideConvex(fpoly, ...fat(W / 2, 1), 0.5) && PM.insideConvex(fpoly, ...fat(W + 17, 400), 0.5),
          "2D: the top edge and the Power button are on the phone")
assert.ok(!PM.insideConvex(fpoly, ...fat(4, 4), 0.5), "2D: the rounded corner's outside is not")

// ---------- the wiring ----------
assert.ok(/readonly property var outlinePoly:[\s\S]{0,1400}PM\.silhouette\(/.test(body), "PhoneBody gives its outline")
assert.ok(/root\.frontMatrix/.test(body.slice(body.indexOf("property var outlinePoly"))), "with the matrix the front is really drawn with (2D draws direct)")
const qp = read("modules/sekai/quickPanel/QuickPanel.qml")
const area = qp.slice(qp.indexOf("id: besidePhone"), qp.indexOf("id: besidePhone") + 1200)
assert.ok(/x: hitRect\.x[\s\S]*height: hitRect\.height/.test(area) && /z: -100/.test(area), "it covers the box that takes the mouse, under the phone")
assert.ok(/enabled: root\.open\b/.test(area), "only while the panel is open (not for an alert's card)")
assert.ok(/mapToItem\(phone,[\s\S]{0,80}PM\.insideConvex\(phone\.outlinePoly/.test(area), "the press is tested against the phone's outline")
assert.ok(/mouse\.accepted = false\s*return[\s\S]{0,140}root\.close\(\)/.test(area), "on the phone it lets go; beside it, it closes")
console.log("click_away_test: all checks passed")
