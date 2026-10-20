import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/WallhavenMath.js" as WH

// The sort menu while the gallery is on Wallhaven: the same small white card as the folder's
// (GallerySortCard.qml), with Wallhaven's orders. Relevance needs a search (greyed out
// without one); Top has its range under it (a day ... a year); Random is new each time.
// Purely a display and a signal: `sort` / `range` in, selected(sort, range) out.
//
// Its width is the widest row's (label + note, or the row of range chips), so nothing in
// it is ever cut.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string sort: "toplist"
    property string range: "1M"
    property bool hasQuery: false
    property bool shown: false

    signal selected(string sort, string range)

    readonly property real rowH: 36
    readonly property real headH: 30
    readonly property var notes: ({ relevance: "needs a search", random: "new each time" })

    width: Math.ceil(Math.max(220, widest.width + 36 + 16 + 12, rangesSize.implicitWidth + 30 + 6 + 12))
    height: headH + WH.SORTS.length * rowH + rangesSize.implicitHeight + 6 + 12

    visible: opacity > 0.01
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.94
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // The row of Top ranges, measured once out here (the one in the menu is inside a
    // repeated row, where the card can't see it).
    Row {
        id: rangesSize
        visible: false
        spacing: 4
        Repeater {
            model: WH.TOP_RANGES
            delegate: WallhavenChip {
                required property var modelData
                text: modelData.id.toUpperCase()
            }
        }
    }

    // The widest "label   note" there is, to size the card by.
    TextMetrics {
        id: widest
        font.family: mt.fontFamily
        font.pixelSize: 13
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        text: "Relevance          needs a search"
    }

    Rectangle {
        x: mt.shadowOffset
        y: mt.shadowOffset
        width: parent.width
        height: parent.height
        radius: mt.radiusOuter
        color: mt.lineShadow
    }

    Rectangle {
        anchors.fill: parent
        radius: mt.radiusOuter
        color: "#ffffff"
        border.width: mt.borderWidth
        border.color: mt.line
        antialiasing: true

        MouseArea { anchors.fill: parent }

        Text {
            x: 16
            y: 9
            text: "SORT WALLHAVEN BY"
            color: ScrapbookTheme.inkSoft
            font.family: mt.fontFamily
            font.styleName: mt.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 11
            font.letterSpacing: 1.2
        }

        Column {
            x: 6
            y: root.headH
            width: parent.width - 12

            Repeater {
                model: WH.SORTS

                delegate: Column {
                    id: entry
                    required property var modelData
                    readonly property bool active: modelData.id === root.sort
                    readonly property bool usable: modelData.id !== "relevance" || root.hasQuery
                    width: parent.width

                    Rectangle {
                        id: row
                        width: parent.width
                        height: root.rowH
                        radius: 8
                        color: rowArea.containsMouse && entry.usable ? mt.colHoverTint : "transparent"
                        opacity: entry.usable ? 1 : 0.5

                        MaterialIcon {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 20
                            weight: 600
                            color: mt.colBorder
                            visible: entry.active
                        }

                        Text {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            color: mt.colBorder
                            font.family: mt.fontFamily
                            font.styleName: entry.active ? mt.fontStyleBold : ""
                            font.weight: entry.active ? Font.ExtraBold : Font.Medium
                            font.pixelSize: 13
                        }

                        Text {
                            visible: root.notes[entry.modelData.id] !== undefined
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.notes[entry.modelData.id] || ""
                            color: ScrapbookTheme.inkSoft
                            font.family: mt.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            enabled: entry.usable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected(entry.modelData.id, root.range)
                        }
                    }

                    // Top: over how long.
                    Item {
                        visible: entry.modelData.id === "toplist"
                        width: parent.width
                        height: visible ? rangesSize.implicitHeight + 6 : 0

                        Row {
                            x: 30
                            spacing: 4

                            Repeater {
                                model: WH.TOP_RANGES
                                delegate: WallhavenChip {
                                    required property var modelData
                                    text: modelData.id.toUpperCase()
                                    on: root.sort === "toplist" && root.range === modelData.id
                                    onClicked: root.selected("toplist", modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
