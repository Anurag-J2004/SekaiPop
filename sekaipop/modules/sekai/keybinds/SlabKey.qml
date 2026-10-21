import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// One key of the keybinds slab, built like a workspace badge (KeyboardKey.qml): the shared
// Pill (navy outline, white ring, flat colour, hard shadow straight down), a real push into
// the shadow on press, and a soft OutBack bounce. On top of that:
//
//   label / sub   the big legend and the little action name under it
//   active        a modifier that is on: it grows in place
//   selected      the key of the chosen action: it rises and wears a cyan ring
//   dim           a key nothing can be bound to: faded, takes no click
//
//   SlabKey { width: 70; label: "N"; sub: "Quick"; fill: "#FF9ECB"; onClicked: ... }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string label: ""
    property string sub: ""
    property color fill: "#ffffff"
    property color ink: mt.colBorder
    property bool active: false
    property bool selected: false
    property bool dim: false
    property real labelSize: 22
    property real keyHeight: 62
    property real ringWidth: 8

    readonly property bool down: area.pressed

    signal clicked()

    height: root.keyHeight + mt.shadowOffset
    opacity: root.dim ? 0.5 : 1

    // The chosen key rises a little, with a springy settle.
    property real lift: root.selected ? -8 : 0
    Behavior on lift {
        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    transform: Translate { y: root.lift }

    // The ring around the cap (not the shadow).
    Rectangle {
        visible: root.selected
        anchors.fill: parent
        anchors.margins: -5
        anchors.bottomMargin: mt.shadowOffset - 5
        radius: mt.radiusBadge + 5
        color: "transparent"
        border.width: 4
        border.color: mt.accentCyan
        antialiasing: true
    }

    Pill {
        anchors.fill: parent

        cornerRadius: mt.radiusBadge
        ringWidth: root.ringWidth
        fillColor: root.fill
        pressed: area.pressed && !root.dim

        scale: root.active ? 1.06 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -mt.shadowOffset / 2 + 1
            spacing: 1

            Text {
                visible: root.label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width - 16)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.label
                color: root.ink
                font.family: mt.fontFamily
                font.pixelSize: root.labelSize
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }

            Text {
                visible: root.sub !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width - 16)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.sub
                color: root.ink
                font.family: mt.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
            }
        }
    }

    // A sibling of the Pill, not inside it (see the note in KeyboardKey.qml).
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !root.dim
        cursorShape: root.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
