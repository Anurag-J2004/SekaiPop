import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// The preset cartridge in the slot on top (160 x 92 design pixels, mostly
// hidden by the shell): its label is the preset's name and a small picture of
// its curve, which is the live curve. Click it to eject: the screen then shows
// the shelf of presets to pick another from.
Item {
    id: cart

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    property string name: "Flat"
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool ejected: false
    signal clicked()

    width: 160 * u
    height: 92 * u

    onGainsChanged: curve.requestPaint()

    Item {
        id: slide
        y: (cart.ejected ? -14 : 0) * cart.u
        width: cart.width
        height: cart.height
        Behavior on y {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        // The wall: 5 steps along the fixed depth vector, one canvas painted once
        // (it was 5 rectangles).
        Canvas {
            id: wallArt
            width: ((160 + 4) * cart.u) * cart.renderScale
            height: ((92 + 4) * cart.u) * cart.renderScale
            // painted at renderScale times its logical size, then shrunk back (smooth edges)
            scale: 1 / cart.renderScale
            transformOrigin: Item.TopLeft
            onCanvasSizeChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var k = canvasSize.width / (160 + 4)
                ctx.scale(k, k)
                var cA = Qt.color("#aeb7d2"), cB = Qt.color("#6f7a9c")
                for (var i = 0; i < 5; i++) {
                    var hgt = (5 - i) * 2
                    ctx.beginPath()
                    PM.rr(ctx, hgt * cart.kx, hgt * cart.ky, 160, 92, 12)
                    ctx.fillStyle = PM.mixCss(cA, cB, 1 - hgt / 10)
                    ctx.fill()
                }
            }
        }

        Rectangle {
            width: cart.width
            height: cart.height
            radius: 12 * cart.u
            antialiasing: true
            border.width: Math.max(1, cart.u)
            border.color: Qt.rgba(0.16, 0.2, 0.35, 0.35)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#c9d0e4" }
                GradientStop { position: 0.35; color: "#f6f8fd" }
                GradientStop { position: 0.7; color: "#e3e8f6" }
                GradientStop { position: 1.0; color: "#b9c1da" }
            }

            // grip ridges
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 18 * cart.u
                    y: (6 + index * 4) * cart.u
                    width: 124 * cart.u
                    height: 2 * cart.u
                    radius: height / 2
                    antialiasing: true
                    color: "#8e98b8"
                    opacity: 0.6
                }
            }

            // the label
            Rectangle {
                x: 14 * cart.u
                y: 24 * cart.u
                width: 132 * cart.u
                height: 58 * cart.u
                radius: 7 * cart.u
                antialiasing: true
                color: "#f4fafb"
                border.width: Math.max(1, cart.u)
                border.color: Qt.rgba(0.16, 0.24, 0.4, 0.35)

                Rectangle {
                    width: parent.width - 2 * cart.u
                    x: cart.u
                    y: cart.u
                    height: 19 * cart.u
                    radius: 6 * cart.u
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00ffcb" }
                        GradientStop { position: 1.0; color: "#4dd0e1" }
                    }
                }
                Text {
                    x: 8 * cart.u
                    y: 3 * cart.u
                    text: cart.name.toUpperCase()
                    color: "#0a2a3a"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12 * cart.u
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.7 * cart.u
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * cart.u
                    y: 6 * cart.u
                    text: "10-BAND"
                    color: "#0a2a3a"
                    opacity: 0.7
                    font.family: Theme.fontFamily
                    font.pixelSize: 7 * cart.u
                    font.weight: Font.Bold
                }

                Canvas {
                    id: curve
                    x: 8 * cart.u
                    y: 24 * cart.u
                    width: (116 * cart.u) * cart.renderScale
                    height: (28 * cart.u) * cart.renderScale
                    // painted at renderScale times its logical size, then shrunk back (smooth edges)
                    scale: 1 / cart.renderScale
                    transformOrigin: Item.TopLeft
                    onCanvasSizeChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var k = canvasSize.width / 116
                        ctx.scale(k, k)
                        var pts = []
                        for (var i = 0; i < 10; i++)
                            pts.push({ x: 4 + i * 12, y: 14 - (cart.gains[i] || 0) * 1.0 })
                        ctx.strokeStyle = "rgba(29,42,90,0.18)"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(0, 14)
                        ctx.lineTo(116, 14)
                        ctx.stroke()
                        ctx.beginPath()
                        PM.smooth(ctx, pts)
                        ctx.lineWidth = 2.2
                        ctx.lineCap = "round"
                        ctx.strokeStyle = "#1d2a5a"
                        ctx.stroke()
                    }
                }
            }
        }
    }

    MouseArea {
        x: 0
        y: 0
        width: cart.width
        height: 70 * cart.u
        cursorShape: Qt.PointingHandCursor
        onClicked: cart.clicked()
    }
}
