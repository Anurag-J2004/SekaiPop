import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A plugin's icon on the Plugins card: its Material Symbols name in a white diamond, like
// the badges on the Settings tiles. 46 for a plugin's row, 28 and 34 for the smaller ones.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string icon: "extension"
    property real size: 46

    // The square's own size, as in the design: the turned corners reach past it, so a row
    // gives the diamond a little room on each side (4px for the 46).
    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        rotation: 45
        radius: root.size >= 46 ? 13 : root.size >= 34 ? 10 : 8
        color: "#ffffff"
        border.width: root.size >= 46 ? 3 : 2.5
        border.color: mt.pLine
        antialiasing: true
    }

    MaterialIcon {
        anchors.centerIn: parent
        size: root.size >= 46 ? 24 : root.size >= 34 ? 20 : 18
        name: root.icon
        weight: mt.settingsIconWeight
        color: mt.colBorder
    }
}
