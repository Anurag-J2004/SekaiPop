import QtQuick
import Quickshell
import qs.modules.common

// The red count bubble on a dock key (Dock.qml): how many notifications from
// that app are waiting in the Quick Panel. Same red, outline and white ring as
// the bell on the bar (NotificationBadge.qml). It springs in when the first one
// arrives and out when the last is gone; over 9 it reads "9+".
Rectangle {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property int count: 0

    readonly property bool on: root.count > 0
    property real shown: root.on ? 1 : 0
    Behavior on shown {
        NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    visible: root.shown > 0.01
    scale: Math.max(0.01, root.shown)
    transformOrigin: Item.Center

    implicitWidth: Math.max(18, label.implicitWidth + 9)
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: "#e0575b"
    border.width: 2
    border.color: mt.ringWhite
    antialiasing: true

    // Keeps the last number while it springs out.
    property int shownCount: 0
    onCountChanged: {
        if (root.count > 0)
            root.shownCount = root.count
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.shownCount > 9 ? "9+" : root.shownCount
        color: "#ffffff"
        font.family: mt.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
    }
}
