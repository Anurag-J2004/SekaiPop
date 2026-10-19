import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/WallhavenMath.js" as WH

// The Filters card under the gallery's Filters key while it is on Wallhaven: categories
// (any mix), shape, minimum size and one of Wallhaven's colours. Every pick applies at
// once (WallhavenService.setFilter searches again) and is remembered; Reset filters puts
// the defaults back. Pure display and signals; `filters` in is WallhavenService.filters.
//
// Every row is chips sized by their own words, and the card is as wide as its widest row,
// so nothing in it is cut.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var filters: WH.DEFAULT_FILTERS
    // "2560×1440": the monitor the picker is on (the "This screen" choice).
    property string screenLabel: ""
    property bool shown: false

    signal categoriesPicked(var categories)
    signal picked(string key, string value)
    signal resetRequested()

    readonly property real pad: 16
    readonly property real swatch: 20
    readonly property int perRow: 15

    width: Math.ceil(Math.max(cats.implicitWidth, shapes.implicitWidth, sizes.implicitWidth,
                              colours.implicitWidth, foot.implicitWidth) + 2 * root.pad)
    height: col.implicitHeight + 2 * 14

    visible: opacity > 0.01
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.94
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    component Head: Text {

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)
        color: ScrapbookTheme.inkSoft
        font.family: mt.fontFamily
        font.styleName: mt.fontStyleBold
        font.weight: Font.ExtraBold
        font.pixelSize: 11
        font.letterSpacing: 1.2
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

        Column {
            id: col
            x: root.pad
            y: 14
            spacing: 7

            Head { text: "CATEGORIES" }
            Row {
                id: cats
                spacing: 5
                Repeater {
                    model: WH.CATEGORIES
                    delegate: WallhavenChip {
                        required property string modelData
                        readonly property var list: Array.isArray(root.filters.categories) ? root.filters.categories : WH.CATEGORIES
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        on: list.indexOf(modelData) >= 0
                        onClicked: {
                            const next = on ? list.filter(c => c !== modelData) : list.concat([modelData])
                            // Never none at all: that would mean everything anyway.
                            if (next.length > 0)
                                root.categoriesPicked(next)
                        }
                    }
                }
            }

            Head { text: "SHAPE"; topPadding: 4 }
            Row {
                id: shapes
                spacing: 5
                Repeater {
                    model: WH.SHAPES
                    delegate: WallhavenChip {
                        required property var modelData
                        text: modelData.label
                        on: (root.filters.shape || "landscape") === modelData.id
                        onClicked: root.picked("shape", modelData.id)
                    }
                }
            }

            Head { text: "AT LEAST"; topPadding: 4 }
            Row {
                id: sizes
                spacing: 5
                Repeater {
                    model: WH.AT_LEAST
                    delegate: WallhavenChip {
                        required property var modelData
                        icon: modelData.id === "screen" ? "desktop_windows" : ""
                        text: modelData.id === "screen" && root.screenLabel !== ""
                            ? "This screen · " + root.screenLabel : modelData.label
                        on: (root.filters.atLeast || "screen") === modelData.id
                        onClicked: root.picked("atLeast", modelData.id)
                    }
                }
            }

            Head { text: "COLOUR"; topPadding: 4 }
            Row {
                id: colours
                spacing: 8

                WallhavenChip {
                    text: "Any"
                    on: (root.filters.colour || "") === ""
                    onClicked: root.picked("colour", "")
                }

                Grid {
                    columns: root.perRow
                    spacing: 4

                    Repeater {
                        model: WH.COLOURS
                        delegate: Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool on: root.filters.colour === modelData
                            width: root.swatch
                            height: root.swatch
                            radius: 5
                            color: modelData
                            border.width: sw.on ? 3 : 2
                            border.color: sw.on ? mt.colBorder : mt.line
                            antialiasing: true

                            MaterialIcon {
                                visible: sw.on
                                anchors.centerIn: parent
                                name: "check"
                                size: 12
                                weight: 700
                                color: Qt.color(sw.modelData).hslLightness > 0.55 ? "#000000" : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.picked("colour", sw.on ? "" : sw.modelData)
                            }
                        }
                    }
                }
            }

            Item {
                id: foot
                width: Math.max(implicitWidth, root.width - 2 * root.pad)
                implicitWidth: applies.implicitWidth + 24 + resetChip.width
                height: resetChip.height

                Text {
                    id: applies
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Applies as you pick"
                    color: ScrapbookTheme.inkSoft
                    font.family: mt.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                WallhavenChip {
                    id: resetChip
                    anchors.right: parent.right
                    text: "Reset filters"
                    available: WH.filterCount(root.filters) > 0
                    onClicked: root.resetRequested()
                }
            }
        }
    }
}
