import QtQuick
import Quickshell
import qs.modules.common

// A heading inside an open plugin (PluginEditor.qml): SETTINGS or SECRETS, a note beside it,
// and one small action on the right (Reset all, Reload).
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string title: ""
    property string note: ""
    property string action: ""
    property string actionIcon: ""

    signal activated()

    implicitHeight: 18 + Math.max(36, noteText.implicitHeight) + 6

    Row {
        id: words
        y: 18
        height: Math.max(36, noteText.implicitHeight)
        width: root.width - (chip.visible ? chip.width + 14 : 0)
        spacing: 14

        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            text: root.title.toUpperCase()
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.Black
            font.letterSpacing: 1.4
        }

        Text {
            id: noteText
            anchors.verticalCenter: parent.verticalCenter
            width: words.width - titleText.width - words.spacing
            text: root.note
            wrapMode: Text.WordWrap
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }

    SettingChip {
        id: chip
        visible: root.action !== ""
        x: root.width - width
        y: 18 + (words.height - height) / 2
        capH: 36
        fontSize: 14
        label: root.action
        icon: root.actionIcon
        onClicked: root.activated()
    }
}
