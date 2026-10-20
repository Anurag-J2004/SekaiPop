import QtQuick
import Quickshell

// The example desktop widget plugin (docs/PLUGINS.md). Copy this folder to
// ~/.config/sekaipop/plugins/hello-clock/ and add "Hello Clock" from Edit Desktop.
//
// It uses everything a plugin gets, and nothing else:
//   host.theme      colours and font, so it follows the theme like the built-in cards
//   host.settings   "greeting" and "use24h" from plugin.json, changed by a click here
//                   (host.setSetting) or by `qs -c sekaipop ipc call plugins set ...`
//   host.secrets    "name", read from $HELLO_CLOCK_NAME or ~/.config/hello-clock/name;
//                   a real plugin keeps its API token there
//   host.working    the clock ticks only while the widget is on screen
//
// The shell draws the card around it, places it and moves it. The widget only says how
// big it is (implicitWidth / implicitHeight, in design pixels) and draws.
Item {
    id: root

    // Handed over by the shell before anything else here runs.
    required property var host

    readonly property var t: root.host.theme
    readonly property bool use24h: root.host.settings.use24h
    readonly property string who: root.host.secrets.name || ""

    implicitWidth: 220
    implicitHeight: 92

    SystemClock {
        id: clock
        enabled: root.host.working || root.host.editing
        precision: SystemClock.Minutes
    }

    readonly property string time: {
        const d = clock.date
        const m = String(d.getMinutes()).padStart(2, "0")
        if (root.use24h)
            return String(d.getHours()).padStart(2, "0") + ":" + m
        const h = d.getHours() % 12 || 12
        return h + ":" + m + (d.getHours() < 12 ? " AM" : " PM")
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.host.settings.greeting + (root.who !== "" ? ", " + root.who : "") + "!"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.time
            color: root.t.pInk
            font.family: root.t.fontFamily
            font.pixelSize: 34
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold

            // A click on the time switches 12 / 24 hours. Anything the widget makes clickable
            // keeps its clicks; the rest of the card is the shell's handle for dragging.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.setSetting("use24h", !root.use24h)
            }
        }
    }
}
