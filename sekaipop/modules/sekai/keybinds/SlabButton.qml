import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A pill button for the slab's strip and footer (Press keys, Reset, Take them, Cancel...): the
// same Pill as the keys, wide enough for its label.
//
//   SlabButton { label: "Press keys"; fill: mt.accentCyan; onClicked: ... }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string label: ""
    property color fill: mt.pSurface
    property color ink: mt.colBorder
    property real btnHeight: 38
    property real labelSize: 14

    signal clicked()

    implicitWidth: Math.ceil(txt.implicitWidth) + 40
    width: implicitWidth
    height: root.btnHeight + mt.shadowOffset

    Pill {
        anchors.fill: parent
        cornerRadius: root.btnHeight / 2
        ringWidth: 5
        fillColor: root.fill
        pressed: area.pressed

        Text {
            id: txt
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -mt.shadowOffset / 2 + 1
            text: root.label
            color: root.ink
            font.family: mt.fontFamily
            font.pixelSize: root.labelSize
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
