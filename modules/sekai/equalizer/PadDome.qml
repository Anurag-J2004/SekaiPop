import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// One of the four dome keys. A real button: it stands `lift` design pixels off
// the shell, with a wall you can see, and sinks to `pressedLift` while held (or
// while `latched`). Drawn in layers (shadow, socket, wall, cap) at the depth
// vector's slope, so it moves with the rest of the body when the pointer does.
Item {
    id: key

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property real renderScale: 1
    property real dd: 56                  // diameter, design pixels
    property color capColor: "#8EE3EF"
    property color wallColor: "#2c9fb8"
    property string glyph: ""
    property bool lit: false              // glowing (SAVE with something to save, AUTO on)
    property bool latched: false
    property real standing: 22
    property real pressedLift: 5
    property bool enabledKey: true

    signal clicked()

    readonly property bool down: area.pressed
    property real lift: (key.down || key.latched) ? key.pressedLift : key.standing
    Behavior on lift {
        NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
    }

    width: dd * u
    height: dd * u
    opacity: key.enabledKey ? 1 : 0.55

    // soft shadow on the shell, further away the higher the cap stands
    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: (3 + key.lift * 0.18 - index * 2) * key.u
            y: (8 + key.lift * 0.4 - index * 2) * key.u
            width: (key.dd + 4 + index * 4) * key.u
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0.12, 0.24, 0.10)
        }
    }

    // the socket it sits in
    Rectangle {
        x: -6 * key.u
        y: -6 * key.u
        width: (key.dd + 12) * key.u
        height: width
        radius: width / 2
        border.width: Math.max(1, key.u)
        border.color: "#64d6e6"
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0c6074" }
            GradientStop { position: 1.0; color: "#1f9bb3" }
        }
    }

    // glow
    Repeater {
        model: key.lit ? 3 : 0
        Rectangle {
            required property int index
            readonly property real r: (key.dd / 2 + 3 + index * 4) * key.u
            x: key.width / 2 - r - key.lift * key.kx * key.u
            y: key.height / 2 - r - key.lift * key.ky * key.u
            width: 2 * r
            height: 2 * r
            radius: r
            color: Qt.rgba(key.capColor.r, key.capColor.g, key.capColor.b, 0.13)
        }
    }

    // the wall: from the shell up to the cap
    Repeater {
        model: 14
        Rectangle {
            required property int index
            readonly property real hgt: (index + 1) * 2
            visible: hgt <= key.lift
            x: -hgt * key.kx * key.u
            y: -hgt * key.ky * key.u
            width: key.width
            height: key.height
            radius: width / 2
            color: PM.mix(Qt.darker(key.wallColor, 2.1), key.wallColor, Math.min(1, hgt / Math.max(1, key.standing)))
        }
    }

    // the cap
    Item {
        id: cap
        x: -key.lift * key.kx * key.u
        y: -key.lift * key.ky * key.u
        width: key.width
        height: key.height

        Canvas {
            anchors.fill: parent
            canvasSize: Qt.size(Math.ceil(width * key.renderScale), Math.ceil(height * key.renderScale))
            property color c1: key.capColor
            property color c2: key.wallColor
            onC1Changed: requestPaint()
            onC2Changed: requestPaint()
            onCanvasSizeChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var k = canvasSize.width / key.dd
                ctx.scale(k, k)
                var d = key.dd, r = d / 2
                var rg = ctx.createRadialGradient(r, r * 1.4, 1, r, r * 1.4, r * 1.3)
                rg.addColorStop(0, String(key.capColor))
                rg.addColorStop(1, String(key.wallColor))
                ctx.beginPath()
                ctx.arc(r, r, r - 0.5, 0, Math.PI * 2)
                ctx.fillStyle = rg
                ctx.fill()
                // underside shade
                var us = ctx.createLinearGradient(0, d * 0.55, 0, d)
                us.addColorStop(0, "rgba(0,0,0,0)")
                us.addColorStop(1, "rgba(0,0,0,0.30)")
                ctx.fillStyle = us
                ctx.fill()
                // specular
                var sp = ctx.createRadialGradient(d * 0.36, d * 0.24, 0.5, d * 0.36, d * 0.24, d * 0.42)
                sp.addColorStop(0, "rgba(255,255,255,0.92)")
                sp.addColorStop(1, "rgba(255,255,255,0)")
                ctx.fillStyle = sp
                ctx.fill()
                // rim
                ctx.beginPath()
                ctx.arc(r, r, r - 1.2, Math.PI * 1.05, Math.PI * 1.8)
                ctx.lineWidth = 1.6
                ctx.strokeStyle = "rgba(255,255,255,0.75)"
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(r, r, r - 0.5, 0, Math.PI * 2)
                ctx.lineWidth = 1
                ctx.strokeStyle = "rgba(0,0,0,0.28)"
                ctx.stroke()
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -key.u
            text: key.glyph
            color: Qt.rgba(0.08, 0.10, 0.27, 0.72)
            font.family: Theme.fontFamily
            font.pixelSize: 22 * key.u
            font.weight: Font.Bold
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#ffffff"
            opacity: area.containsMouse && !key.down ? 0.14 : 0
            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }
        }
    }

    MouseArea {
        id: area
        x: -key.lift * key.kx * key.u
        y: -key.lift * key.ky * key.u
        width: key.width
        height: key.height
        enabled: key.enabledKey
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
