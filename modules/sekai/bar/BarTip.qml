import QtQuick
import qs.modules.common

// A small hover tag for a bar module: dark rounded label that opens towards
// the inside of the screen, whichever edge the bar is on.
//
//   BarTip { shown: area.containsMouse; text: "12 updates"; barPosition: "top" }
//
// Declare it as a child of the module (the module's own box is what it hangs
// off). The bar's window is as big as the screen, so it is drawn even though
// it sits outside the strip that takes clicks; it never needs any itself.
Rectangle {
    id: root

    property bool shown: false
    property string text: ""
    property string barPosition: "top"

    readonly property Item host: parent

    visible: opacity > 0.01
    opacity: shown && text !== "" ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    z: 50
    radius: 8
    color: Theme.colBorder
    width: label.implicitWidth + 16
    height: label.implicitHeight + 10

    x: host ? (root.barPosition === "left" ? host.width + 6
               : (root.barPosition === "right" ? -width - 6 : (host.width - width) / 2)) : 0
    y: host ? (root.barPosition === "bottom" ? -height - 6
               : (root.barPosition === "top" ? host.height + 6 : (host.height - height) / 2)) : 0

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.textWhite
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
