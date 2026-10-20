import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// The small labels of the Plugins card (SettingsPluginsCard.qml), one look per `kind`:
//   on      "On the desktop", "Found": the accent gradient, outlined
//   warn    "token not found", "Not found": the happy (yellow) attribute colour
//   mute    "Not on the desktop": a dashed outline, no fill
//   cap     a monitor's name, as a little keycap with a hard shadow
//   ver     a version number
//   tag     SKIPPED: ink on the surface colour, the other way round
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string kind: "on"
    property string text: ""
    property string icon: ""
    // The header of an open plugin sits on the accent gradient: the version goes see-through.
    property bool onAccent: false

    readonly property real boxH: kind === "cap" ? 28 : kind === "ver" || kind === "tag" ? 24 : 30
    readonly property real padX: kind === "on" || kind === "warn" || kind === "mute" ? 11 : 9

    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: boxH + (kind === "cap" ? 3 : 0)

    // the cap's hard shadow
    Rectangle {
        visible: root.kind === "cap"
        y: 3
        width: parent.width
        height: root.boxH
        radius: 8
        color: mt.pLineShadow
    }

    Rectangle {
        id: box
        visible: root.kind !== "mute"
        width: parent.width
        height: root.boxH
        radius: root.kind === "on" || root.kind === "warn" ? 10 : 8
        border.width: root.kind === "tag" ? 0 : root.kind === "ver" ? 2 : 2.5
        border.color: root.onAccent ? mt.colBorder : mt.pLine
        color: root.kind === "warn" ? mt.attributeColors[2]
            : root.kind === "tag" ? mt.pInk
            : root.kind === "ver" ? (root.onAccent ? Qt.rgba(1, 1, 1, 0.6) : mt.pSurfaceHover)
            : mt.pSurface
        gradient: root.kind === "on" ? accent : null

        Gradient {
            id: accent
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: mt.accentCyan }
            GradientStop { position: 1; color: mt.accentMint }
        }
    }

    // "Not on the desktop": a dashed outline, which a Rectangle can't draw.
    Canvas {
        id: dashes
        visible: root.kind === "mute"
        width: parent.width
        height: root.boxH
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = mt.pLine
            c.lineWidth = 2.5
            c.setLineDash([3, 2])
            c.beginPath()
            c.roundedRect(1.25, 1.25, width - 2.5, height - 2.5, 10, 10)
            c.stroke()
        }
        onWidthChanged: requestPaint()
        Connections {
            target: root.mt
            function onPLineChanged() { dashes.requestPaint() }
        }
    }

    Row {
        id: row
        x: root.padX
        height: root.boxH
        spacing: 6

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            size: 15
            name: root.icon
            weight: mt.settingsIconWeight
            color: label.color
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.kind === "tag" ? mt.pSurface
                : root.kind === "mute" ? mt.pInkSub
                : root.kind === "on" || root.kind === "warn" || root.onAccent ? mt.colBorder
                : mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: root.kind === "tag" ? 11 : root.kind === "cap" || root.kind === "ver" ? 12 : 13
            font.weight: root.kind === "mute" ? Font.ExtraBold : Font.Black
            font.letterSpacing: root.kind === "tag" ? 1.1 : root.kind === "cap" ? 0.4 : 0
        }
    }
}
