import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A wide keycap for the Discord panel (DiscordPopup.qml): icon + word on the
// shell's own Pill, pressing into its hard shadow like every other key. While
// it is "on" (you are muted / deafened) it lights up red, the way the pill's
// badge does.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: ""
    property string label: ""
    // On = the state it controls is active (muted, deafened).
    property bool active: false
    property color activeColor: "#ed4245"

    signal clicked()

    implicitWidth: 154
    implicitHeight: 44 + mt.shadowOffset

    Pill {
        anchors.fill: parent
        cornerRadius: 15
        ringWidth: 5
        fillColor: root.active ? root.activeColor
                               : (area.containsMouse ? mt.surfaceHover : mt.surface)
        pressed: area.pressed

        Row {
            anchors.centerIn: parent
            spacing: 7

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                fill: 0
                size: 20
                color: root.active ? mt.textWhite : mt.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: root.active ? mt.textWhite : mt.ink
                font.family: mt.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
