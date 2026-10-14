import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The small media player that opens over the dock's media key (Dock.qml): cover,
// title, artist, previous / play-pause / next and a progress line. Pure
// UI on top of a MediaSource (MediaSource.qml) given as `source`.
DockCard {
    id: root

    property var source: null

    readonly property var player: root.source ? root.source.player : null
    readonly property bool playing: root.source ? root.source.playing : false
    readonly property bool hasLength: root.player !== null && root.player.lengthSupported === true
                                      && root.player.length > 0
    readonly property real progress: root.hasLength && root.player.positionSupported
        ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0

    readonly property real artSize: 76
    contentWidth: 316
    contentHeight: root.artSize + (root.hasLength ? 18 : 0)

    // The player doesn't announce its position; ask for it while the card is open.
    Timer {
        interval: 500
        repeat: true
        running: root.open && root.playing && root.player !== null
        onTriggered: root.player.positionChanged()
    }

    // Cover.
    Rectangle {
        id: art
        x: root.pad
        y: root.pad
        width: root.artSize
        height: root.artSize
        radius: 14
        color: Theme.surfaceDivider
        border.width: 3
        border.color: Theme.line
        antialiasing: true

        Image {
            id: cover
            anchors.fill: parent
            anchors.margins: 3
            visible: status === Image.Ready
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(152, 152)
            source: root.source ? root.source.artUrl : ""
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            name: "genres"
            size: 34
        }
    }

    Column {
        x: root.pad + root.artSize + 14
        y: root.pad
        width: root.contentWidth - root.artSize - 14
        height: root.artSize
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.source && root.source.present ? root.source.title : "Nothing playing"
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.source ? root.source.artist : ""
            color: Theme.inkSub
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Item {
            width: 1
            height: 6
        }

        Row {
            spacing: 8

            Repeater {
                model: [
                    { icon: "skip_previous", act: "prev" },
                    { icon: root.playing ? "pause" : "play_arrow", act: "toggle" },
                    { icon: "skip_next", act: "next" }
                ]

                delegate: Item {
                    id: btn
                    required property var modelData

                    width: 40
                    height: 36

                    Pill {
                        anchors.fill: parent
                        cornerRadius: 11
                        ringWidth: 5
                        fillColor: btn.modelData.act === "toggle" ? Theme.accentCyan : Theme.surface
                        pressed: btnArea.pressed

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: btn.modelData.icon
                            size: 20
                            fill: 1
                            color: btn.modelData.act === "toggle" ? Theme.colBorder : Theme.ink
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.source)
                                return
                            if (btn.modelData.act === "prev")
                                root.source.previous()
                            else if (btn.modelData.act === "next")
                                root.source.next()
                            else
                                root.source.togglePlaying()
                        }
                    }
                }
            }
        }
    }

    // Progress.
    Rectangle {
        visible: root.hasLength
        x: root.pad
        y: root.pad + root.artSize + 12
        width: root.contentWidth
        height: 6
        radius: 3
        color: Theme.surfaceDivider

        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: 3
            color: Theme.accentMint
        }
    }
}
