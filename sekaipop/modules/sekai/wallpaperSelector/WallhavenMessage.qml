import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/WallhavenMath.js" as WH

// What the gallery says on Wallhaven when there are no pictures to show: nothing found,
// too many requests (with a countdown to trying again), offline, or Wallhaven not
// answering. A glyph in a tilted frame, a title, a sentence and two keys. Centred in the
// gallery by WallpaperFace.qml; the text wraps, and the keys are as wide as their words.
Column {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    // "empty" | "limited" | "offline" | "failed"
    property string kind: "empty"
    property string query: ""
    property var filters: WH.DEFAULT_FILTERS
    property real retryIn: 0
    property real maxWidth: 640

    signal retry()
    signal clearFilters()
    signal editSearch()
    signal backToFolder()

    readonly property string sentence: WH.filtersSentence(root.filters)
    readonly property bool filtered: WH.filterCount(root.filters) > 0

    spacing: 10

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 64
        height: 64

        Rectangle {
            anchors.centerIn: parent
            width: 46
            height: 46
            radius: 12
            rotation: 45
            color: mt.pSurface
            border.width: 3
            border.color: mt.pLine
            antialiasing: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            size: 26
            weight: 700
            color: mt.pInk
            name: root.kind === "limited" ? "timer"
                : root.kind === "offline" ? "cloud_off"
                : root.kind === "failed" ? "error" : "search_off"
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.maxWidth)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
        text: root.kind === "limited" ? "Wallhaven needs a breather"
            : root.kind === "offline" ? "You’re offline"
            : root.kind === "failed" ? "Wallhaven isn’t answering"
            : (root.query.trim() !== "" ? "Nothing on Wallhaven for “" + root.query.trim() + "”" : "Nothing on Wallhaven")
        color: mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 24
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.maxWidth)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.kind === "limited"
            ? "Too many searches in one minute, so it’s saying no for a moment. Nothing is lost: this search comes back where it was."
            : root.kind === "offline"
            ? "Wallhaven needs the internet. Your own pictures, and the ones you already got from Wallhaven, still work."
            : root.kind === "failed"
            ? "The site may be down for a moment. Try again shortly."
            : (root.sentence !== "" ? root.sentence + " Fewer filters, or a shorter search, usually turns something up."
                                    : "A shorter search, or other words, usually turns something up.")
        color: mt.pInkSub
        font.family: mt.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
        lineHeight: 1.2
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        topPadding: 6

        // empty
        WallhavenChip {
            visible: root.kind === "empty" && root.filtered
            text: "Clear the filters"
            on: true
            onClicked: root.clearFilters()
        }
        WallhavenChip {
            visible: root.kind === "empty"
            text: "Edit the search"
            onClicked: root.editSearch()
        }

        // limited / offline / failed
        WallhavenChip {
            visible: root.kind !== "empty"
            icon: root.kind === "limited" && root.retryIn > 0 ? "timer" : "refresh"
            text: root.kind === "limited" && root.retryIn > 0 ? "Try again in " + WH.countdown(root.retryIn) : "Try again"
            available: !(root.kind === "limited" && root.retryIn > 0)
            on: available
            onClicked: root.retry()
        }
        WallhavenChip {
            visible: root.kind === "limited" || root.kind === "offline"
            icon: "folder"
            text: "Back to my folder"
            onClicked: root.backToFolder()
        }
        WallhavenChip {
            visible: root.kind === "failed"
            icon: "open_in_new"
            text: "Open wallhaven.cc"
            onClicked: Qt.openUrlExternally("https://wallhaven.cc")
        }
    }
}
