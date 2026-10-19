import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The 44 px round buttons of a Keys row (reset, set by hand): outlined, with a hard
// shadow straight down, a tooltip plate under them on hover. `flat` draws just the
// icon (the fixed row's padlock).
Item {
    id: root

    property string icon: ""
    property string tip: ""
    property bool flat: false
    property bool lit: false
    readonly property bool hovered: area.containsMouse

    signal clicked()

    width: 44
    height: 47

    Behavior on opacity {
        NumberAnimation { duration: 90 }
    }

    Rectangle {
        visible: !root.flat
        y: area.pressed ? 0 : 3
        width: 44
        height: 44
        radius: 22
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: face
        y: area.pressed ? 2 : 0
        width: 44
        height: 44
        radius: 22
        color: root.flat ? "transparent" : Theme.pSurface
        border.width: root.flat ? 0 : 3
        border.color: Theme.pLine
        antialiasing: true

        Rectangle {
            visible: !root.flat && (root.lit || root.hovered)
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentCyan }
                GradientStop { position: 1; color: Theme.accentMint }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: root.icon
            size: 20
            color: root.flat ? Theme.pInkSub : (root.lit || root.hovered) ? Theme.colBorder : Theme.pInk
        }
    }

    MouseArea {
        id: area
        anchors.fill: face
        enabled: !root.flat
        hoverEnabled: true
        cursorShape: root.flat ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // The tooltip plate, above the button: each line of rows is drawn over the one
    // before it, so a plate hanging below would end up under the next line's keys.
    Rectangle {
        visible: root.tip !== "" && root.hovered
        z: 10
        anchors.bottom: face.top
        anchors.bottomMargin: 10
        anchors.right: face.right
        anchors.rightMargin: -10
        width: tipText.implicitWidth + 28
        height: 36
        radius: 12
        color: Theme.chipFill
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tip
            color: Theme.chipInk
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Black
        }
    }
}
