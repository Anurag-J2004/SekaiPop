import QtQuick
import "PadMath.js" as PM

// The console's shell, drawn from its own pixels (design size 920 x 400; `u` is
// how big one pixel is here). Two layers:
//   - the wall: the shell's thickness, as `depth` thin copies of its outline, each
//     one a step further along the depth vector (kx, ky), shaded from the lit rim
//     down to the dark back. The vector is what the popup moves with the mouse, so
//     the body seems to turn a little under the pointer;
//   - the face: satin teal plastic painted once (lit from the top left), with its
//     rim light, the sheen, the cartridge slot, screws, the speaker grille and the
//     pearl line along the bottom.
// There is no 3D here, only offsets: the same trick as the phone.
Item {
    id: body

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    readonly property real bw: 920
    readonly property real bh: 400
    readonly property real depth: 68
    readonly property int steps: 34

    width: bw * u
    height: bh * u

    // Soft shadow on the desk: the footprint of the wall's far end (the body moved
    // along the whole depth vector), then `shadowLayers` translucent copies of it,
    // each one growing by an even step on every side, so it fades out evenly all
    // the way round. It never grows past `shadowSpread` design pixels beyond the
    // wall: the popup's window ends a little past the body (about 25 px on the
    // right and 17 px at the bottom beyond the wall), and what was drawn past that
    // was cut off in a straight line. (The old stack all started from the same
    // corner and only grew down and to the right, so it ended in a hard rectangle
    // edge there, and was lopsided.) Raise `shadowSpread` only together with the
    // popup's `marginR` / `marginB` in EqualizerPopup.qml.
    readonly property int shadowLayers: 12
    readonly property real shadowSpread: 9
    Repeater {
        model: body.shadowLayers
        Rectangle {
            required property int index
            // 0 = the biggest and faintest, shadowLayers - 1 = the one hugging the wall
            readonly property real grow: body.shadowSpread * (body.shadowLayers - index) / body.shadowLayers
            x: (body.depth * body.kx - grow) * body.u
            y: (body.depth * body.ky - grow) * body.u
            width: (body.bw + grow * 2) * body.u
            height: (body.bh + grow * 2) * body.u
            radius: (64 + grow) * body.u
            color: Qt.rgba(0.02, 0.10, 0.20, 0.045)
            antialiasing: true
        }
    }

    // The wall, back to front.
    Repeater {
        model: body.steps
        Rectangle {
            required property int index
            readonly property int j: body.steps - index        // 34 (back) .. 1 (front)
            readonly property real hgt: j * body.depth / body.steps
            x: hgt * body.kx * body.u
            y: hgt * body.ky * body.u
            width: body.bw * body.u
            height: body.bh * body.u
            radius: 64 * body.u
            color: j === 1 ? "#c7fff8" : PM.mix(Qt.color("#2fbac8"), Qt.color("#082f46"), (j - 1) / (body.steps - 1))
        }
    }

    // The face.
    Canvas {
        id: face
        width: body.width
        height: body.height
        canvasSize: Qt.size(Math.ceil(width * body.renderScale), Math.ceil(height * body.renderScale))
        onCanvasSizeChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var k = canvasSize.width / body.bw
            ctx.scale(k, k)
            var W = body.bw, H = body.bh

            // the plastic
            var g = ctx.createLinearGradient(W * 0.08, 0, W * 0.92, H)
            g.addColorStop(0, "#79ece2")
            g.addColorStop(0.36, "#3ccbd2")
            g.addColorStop(1, "#20a5ba")
            ctx.beginPath()
            PM.rr(ctx, 0, 0, W, H, 64)
            ctx.fillStyle = g
            ctx.fill()

            ctx.save()
            ctx.beginPath()
            PM.rr(ctx, 0, 0, W, H, 64)
            ctx.clip()

            // the sheen, top left
            var sh = ctx.createLinearGradient(0, 0, 0, 170)
            sh.addColorStop(0, "rgba(255,255,255,0.42)")
            sh.addColorStop(1, "rgba(255,255,255,0)")
            ctx.save()
            ctx.translate(180, 70)
            ctx.rotate(-0.31)
            ctx.beginPath()
            ctx.ellipse(-300, -100, 600, 200)
            ctx.fillStyle = sh
            ctx.fill()
            ctx.restore()

            // shade along the bottom, light on the top rim
            var bs = ctx.createLinearGradient(0, H - 26, 0, H)
            bs.addColorStop(0, "rgba(0,60,90,0)")
            bs.addColorStop(1, "rgba(0,60,90,0.42)")
            ctx.fillStyle = bs
            ctx.fillRect(0, H - 26, W, 26)
            var tr = ctx.createLinearGradient(0, 0, 0, 14)
            tr.addColorStop(0, "rgba(255,255,255,0.85)")
            tr.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = tr
            ctx.fillRect(0, 0, W, 14)
            ctx.restore()

            ctx.beginPath()
            PM.rr(ctx, 0.5, 0.5, W - 1, H - 1, 64)
            ctx.lineWidth = 1
            ctx.strokeStyle = "rgba(255,255,255,0.3)"
            ctx.stroke()
            ctx.beginPath()
            PM.rr(ctx, -0.5, -0.5, W + 1, H + 1, 64)
            ctx.strokeStyle = "rgba(10,60,90,0.45)"
            ctx.stroke()

            // the cartridge slot
            var sl = ctx.createLinearGradient(0, 6, 0, 16)
            sl.addColorStop(0, "#05061a")
            sl.addColorStop(1, "#14183a")
            ctx.beginPath()
            PM.rr(ctx, W / 2 - 70, 6, 140, 10, 5)
            ctx.fillStyle = sl
            ctx.fill()
            ctx.fillStyle = "rgba(255,255,255,0.5)"
            ctx.fillRect(W / 2 - 66, 16, 132, 1)

            // the pearl line
            var ln = ctx.createLinearGradient(90, 0, W - 90, 0)
            ln.addColorStop(0, "#ff9ecb")
            ln.addColorStop(0.5, "#ffe9a8")
            ln.addColorStop(1, "#7ff5df")
            ctx.beginPath()
            PM.rr(ctx, 90, 386, W - 180, 4, 2)
            ctx.fillStyle = ln
            ctx.fill()

            // speaker grille (right; the left one is the MEDIA key)
            var gx = W - 126, gy = 334
            ctx.beginPath()
            PM.rr(ctx, gx, gy, 80, 30, 12)
            ctx.fillStyle = "rgba(0,50,80,0.18)"
            ctx.fill()
            ctx.fillStyle = "rgba(0,40,70,0.75)"
            for (var ix = 0; ix < 10; ix++) {
                for (var iy = 0; iy < 4; iy++) {
                    ctx.beginPath()
                    ctx.arc(gx + 4 + ix * 8, gy + 4 + iy * 8, 1.7, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            // screws
            var sc = [[30, 32], [W - 30, 32], [36, 366], [W - 36, 366]]
            for (var s = 0; s < sc.length; s++) {
                var rg = ctx.createRadialGradient(sc[s][0] - 2, sc[s][1] - 2, 0.5, sc[s][0], sc[s][1], 7)
                rg.addColorStop(0, "#ffffff")
                rg.addColorStop(0.6, "#9fb2c8")
                rg.addColorStop(1, "#6e8399")
                ctx.beginPath()
                ctx.arc(sc[s][0], sc[s][1], 6, 0, Math.PI * 2)
                ctx.fillStyle = rg
                ctx.fill()
                ctx.strokeStyle = "rgba(60,80,100,0.75)"
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.moveTo(sc[s][0] - 3.5, sc[s][1])
                ctx.lineTo(sc[s][0] + 3.5, sc[s][1])
                ctx.moveTo(sc[s][0], sc[s][1] - 3.5)
                ctx.lineTo(sc[s][0], sc[s][1] + 3.5)
                ctx.stroke()
            }
        }
    }
}
