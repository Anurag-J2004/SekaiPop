import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// One secret of an open plugin (PluginEditor.qml): found in the environment or in a file,
// or not found and exactly where to put it. Never its value: `info` (PluginForm.secretInfo)
// does not carry one.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var info: null

    readonly property real labelW: 300
    readonly property real gap: 20

    implicitHeight: Math.max(nameRow.implicitHeight, how.implicitHeight) + 24

    Row {
        id: nameRow
        y: 12
        height: 34
        spacing: 8

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: 17
            name: "key"
            weight: mt.settingsIconWeight
            color: mt.pInk
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.info ? root.info.name : ""
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 17
            font.weight: Font.Black
        }
    }

    Column {
        id: how
        x: root.labelW + root.gap
        y: 12
        width: root.width - x
        spacing: 8

        // found
        Row {
            visible: root.info !== null && root.info.found
            height: 34
            spacing: 10

            PluginBadge {
                anchors.verticalCenter: parent.verticalCenter
                kind: "on"
                icon: "check"
                text: "Found"
            }

            HowText {
                text: root.info && root.info.source === "env" ? "in the environment, as" : "in the file"
            }

            CodeChip {
                text: root.info ? (root.info.source === "env" ? root.info.env : root.info.file) : ""
            }
        }

        // not found: where it goes
        Row {
            visible: root.info !== null && !root.info.found
            height: 34
            spacing: 10

            PluginBadge {
                anchors.verticalCenter: parent.verticalCenter
                kind: "warn"
                icon: "error"
                text: "Not found"
            }

            HowText {
                text: "The widget can't sign in until it is. Put it in "
                    + (root.info && root.info.env !== "" && root.info.file !== "" ? "one of these" : "this")
                    + ", then press Reload:"
            }
        }

        Row {
            visible: root.info !== null && !root.info.found && root.info.env !== ""
            height: 34
            spacing: 10

            HowText { text: "The environment variable" }
            CodeChip { text: root.info ? root.info.env : "" }
            CopyButton { what: root.info ? root.info.env : ""; tip: "Copy the variable's name" }
            HowText { text: "(set before the shell starts)"; sub: true }
        }

        Row {
            visible: root.info !== null && !root.info.found && root.info.file !== ""
            height: 34
            spacing: 10

            HowText { text: root.info && root.info.env !== "" ? "or the file" : "The file" }
            CodeChip { text: root.info ? root.info.file : "" }
            CopyButton { what: root.info ? root.info.file : ""; tip: "Copy the file's path" }
            HowText { text: "(the whole file is the secret)"; sub: true }
        }
    }

    component HowText: Text {
        readonly property var mt: Theme.of(QsWindow.window)
        property bool sub: false
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: sub ? mt.pInkSub : mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    component CodeChip: Rectangle {
        readonly property var mt: Theme.of(QsWindow.window)
        property alias text: codeText.text
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: codeText.implicitWidth + 20
        height: 26
        radius: 9
        color: mt.pSurfaceDivider

        Text {
            id: codeText
            anchors.centerIn: parent
            color: mt.pInk
            font.family: "monospace"
            font.pixelSize: 13
        }
    }

    component CopyButton: KeyRoundButton {
        property string what: ""
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        icon: "content_copy"
        onClicked: Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", what])
    }
}
