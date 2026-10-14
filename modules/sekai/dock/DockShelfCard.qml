import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The dock's Shelf (Dock.qml): what you have put down on the Shelf key (files dropped on
// it, or text), to pick up again. For a file: click opens it, the copy button puts it on
// the clipboard as a file (paste it into a file manager), the folder button opens the
// folder it is in. For text: click copies it. The x takes it off the shelf.
DockCard {
    id: root

    signal closeRequested()

    readonly property var items: ShelfService.items
    readonly property int shownMax: 6
    readonly property real rowH: 46
    readonly property real listW: 360

    contentWidth: root.listW
    contentHeight: header.height + 12
        + (root.items.length === 0 ? 44 : Math.min(root.items.length, root.shownMax) * (root.rowH + 3))
        + (root.items.length > root.shownMax ? 28 : 0)

    function isImage(path) {
        return /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(path)
    }

    Item {
        id: header
        x: root.pad
        y: root.pad
        width: root.listW
        height: 36

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                radius: 4
                rotation: 45
                color: Theme.accentMint
                border.width: 2
                border.color: Theme.line
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Shelf"
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            DockButton {
                height: 32
                icon: "content_paste_go"
                label: "Paste"
                fontSize: 13
                iconSize: 18
                onClicked: ShelfService.addFromClipboard()
            }

            DockButton {
                visible: root.items.length > 0
                height: 32
                icon: "delete_sweep"
                label: "Clear"
                fontSize: 13
                iconSize: 18
                onClicked: ShelfService.clear()
            }
        }
    }

    Text {
        visible: root.items.length === 0
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        wrapMode: Text.WordWrap
        text: "Drop files or text on the Shelf key, or press Paste."
        color: Theme.inkSub
        font.family: Theme.fontFamily
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    Column {
        x: root.pad
        y: root.pad + header.height + 12
        width: root.listW
        spacing: 3

        Repeater {
            model: root.items.slice(0, root.shownMax)

            delegate: Item {
                id: row
                required property var modelData

                readonly property bool isFile: row.modelData.kind === "file"

                width: root.listW
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: rowHover.hovered
                        ? Qt.rgba(Theme.accentCyan.r, Theme.accentCyan.g, Theme.accentCyan.b, area.pressed ? 0.34 : 0.2)
                        : "transparent"
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }
                }

                // A picture shows itself; anything else, its kind.
                Item {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32

                    Image {
                        id: thumb
                        anchors.fill: parent
                        visible: row.isFile && root.isImage(row.modelData.value) && status === Image.Ready
                        asynchronous: true
                        smooth: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(64, 64)
                        source: row.isFile && root.isImage(row.modelData.value) ? "file://" + row.modelData.value : ""
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !thumb.visible
                        name: row.isFile ? "description" : "notes"
                        size: 24
                    }
                }

                Text {
                    x: 50
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.listW - 50 - (row.isFile ? 96 : 40)
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    text: row.modelData.name
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.isFile)
                            ShelfService.open(row.modelData)
                        else
                            ShelfService.copy(row.modelData)
                        root.closeRequested()
                    }
                }

                // The small buttons, after the row's own MouseArea so they take their clicks.
                Row {
                    x: root.listW - width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: rowHover.hovered ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 110 }
                    }

                    Repeater {
                        model: row.isFile ? ["copy", "folder", "x"] : ["copy", "x"]

                        delegate: Rectangle {
                            id: btn
                            required property string modelData
                            width: 26
                            height: 26
                            radius: 8
                            color: Theme.surface
                            border.width: 2
                            border.color: ma.containsMouse ? (btn.modelData === "x" ? "#e0575b" : Theme.accentMint) : Theme.line
                            antialiasing: true

                            MaterialIcon {
                                anchors.centerIn: parent
                                name: btn.modelData === "copy" ? "content_copy" : (btn.modelData === "folder" ? "folder_open" : "close")
                                size: 15
                                weight: 700
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (btn.modelData === "copy")
                                        ShelfService.copy(row.modelData)
                                    else if (btn.modelData === "folder")
                                        ShelfService.revealInFolder(row.modelData)
                                    else
                                        ShelfService.remove(row.modelData.id)
                                }
                            }
                        }
                    }
                }

                // True while the pointer is anywhere on the row, buttons included.
                HoverHandler {
                    id: rowHover
                }
            }
        }

        Text {
            visible: root.items.length > root.shownMax
            width: root.listW
            horizontalAlignment: Text.AlignHCenter
            text: "+ " + (root.items.length - root.shownMax) + " more"
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }
}
