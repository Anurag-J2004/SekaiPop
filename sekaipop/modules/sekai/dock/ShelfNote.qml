import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A text (or a web link) on the dock's Shelf: a sticky note in one of the five card colours,
// leaning on the wall, with the first lines of the text on it and a folded corner. The buttons
// come up over the foot of the note when you point at it. Drawn by DockShelfCard.qml, which
// sets the size.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    required property var item
    required property color tint
    required property bool lifted

    // hard shadow
    Rectangle {
        x: 3
        y: 3
        width: parent.width
        height: parent.height
        radius: 3
        color: mt.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: paper
        anchors.fill: parent
        radius: 3
        color: root.tint
        border.width: mt.borderWidth
        border.color: mt.line
        antialiasing: true

        // the glue strip along the top
        Rectangle {
            x: mt.borderWidth + 2
            y: mt.borderWidth + 1
            width: paper.width - 2 * (mt.borderWidth + 2)
            height: 6
            radius: 2
            color: "white"
            opacity: 0.4
        }

        // the text: its first lines
        Text {
            x: 8
            y: 16
            width: paper.width - 16
            height: paper.height - 16 - 22
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 4
            lineHeight: 0.95
            text: String(root.item.value).trim()
            color: "#2B2D42"
            font.family: mt.fontFamily
            font.pixelSize: 9
            font.weight: Font.Bold
            opacity: root.lifted ? 0.35 : 1

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        // the folded corner
        Rectangle {
            x: paper.width - width - mt.borderWidth
            y: paper.height - height - mt.borderWidth
            width: 11
            height: 11
            radius: 2
            color: Qt.darker(root.tint, 1.18)
            border.width: 1.5
            border.color: mt.line
            antialiasing: true
        }
    }
}
