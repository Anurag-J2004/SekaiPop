import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One choice in the Wallhaven sort menu (the Top ranges) and the Filters card (categories,
// shape, minimum size): a small key, lit with the accent gradient when it is on.
//
// It is as wide as its own text and icon need, plus 12 px each side, so a label is never
// cut whatever the font (the design drew some of these too narrow for their words).
Item {
    id: root

    property string text: ""
    property string icon: ""
    property bool on: false
    property bool available: true

    signal clicked()

    readonly property real keyH: 30

    width: Math.ceil(row.implicitWidth) + 24
    height: root.keyH + 3
    opacity: root.available ? 1 : 0.45

    Gradient {
        id: lit
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.accentCyan }
        GradientStop { position: 1.0; color: Theme.accentMint }
    }

    Pill {
        anchors.fill: parent
        cornerRadius: 10
        borderWidth: 2.5
        ringWidth: root.on ? 3.5 : 2.5
        shadowDx: 0
        shadowDy: 3
        pressed: area.pressed
        fillColor: area.containsMouse && !root.on ? Theme.pSurfaceHover : Theme.pSurface
        fillGradient: root.on ? lit : null
    }

    Row {
        id: row
        x: 12
        y: (root.keyH - height) / 2
        spacing: 5

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 15
            weight: 700
            color: root.on ? Theme.colBorder : Theme.pInk
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.on ? Theme.colBorder : Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: root.on ? Font.Black : Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
