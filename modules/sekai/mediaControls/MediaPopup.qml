import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import "MediaOwner.js" as Owner
import "MediaMath.js" as MM
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.bar
import qs.modules.sekai.visualizer

// The card that drops down from the media pill, kept simple: the cover, the song
// and four or five keys. It is the shared SekaiPopup frame (pop-in, focus grab,
// placement and Escape come from SekaiPopup.qml); Bar.qml gives it `source`, the
// MediaSource, so the pill's player is the one shown first.
//
//   +----------------------------------------+
//   | [ZEN] [mpv]                            |   tabs: only when there is more than one player
//   | +------+  * ZEN TWILIGHT               |
//   | |COVER |  Title (two lines)             |   the cover IS a key: click it to play / pause
//   | +------+  Artist                        |
//   | [EQ] [ prev ] [ > Play ] [ next ] [win] |
//   +----------------------------------------+
//
//   The cover    a keycap: raised while the song plays, pressed flush when paused.
//   The play key wears the cover's own two colours (or the theme's accent when there
//                is no cover); everything else is the shell's plain card.
//   The tabs     one per app (Zen, Chromium and mpv can report several players; the bar
//                pill's player comes first). Click one, or roll the wheel over them.
//                With one player its name sits above the title instead.
//   The keys     previous / play-pause / next; the tools at the ends open the equalizer
//                and the player's own window (workspace and all). A key the player cannot
//                do is dimmed.
//   Keyboard     Space plays / pauses, N / P next / previous, Left / Right seek by five
//                seconds (best effort, whenever the compositor gives the popup the
//                keyboard). There is no progress bar on purpose.
//
// Every colour is a Theme token (or the cover's / the app's), so Light, Dark and
// Darker all work.
SekaiPopup {
    id: root

    property var source: null          // MediaSource (which player the pill shows)

    // The EQ tool was pressed: Bar.qml puts this card away and opens the equalizer
    // card (EqualizerPopup.qml) in its place.
    signal eqRequested()

    // ===== the players =====
    readonly property var players: {
        const featured = root.source ? root.source.player : null
        const live = Mpris.players.values.filter(pl =>
            pl.playbackState === MprisPlaybackState.Playing || (pl.trackTitle ?? "") !== "")
        // One card per app: Zen, Chromium and mpv can report several players.
        const list = Owner.onePerApp(live, Hyprland.toplevels.values, featured, MprisPlaybackState.Playing)
        return list.slice().sort((a, b) => (b === featured ? 1 : 0) - (a === featured ? 1 : 0))
    }

    // The one you turned to (null = the first). Forgotten each time the card opens.
    property var picked: null
    readonly property var p: MM.current(root.players, root.picked)
    readonly property bool hasPlayer: root.p !== null
    readonly property bool multi: root.players.length > 1
    readonly property int playerNo: root.hasPlayer ? Math.max(0, root.players.indexOf(root.p)) + 1 : 0
    readonly property bool featured: root.hasPlayer && root.source !== null && root.p === root.source.player

    readonly property bool playing: root.hasPlayer && root.p.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.hasPlayer && (root.p.trackTitle ?? "") !== ""
    readonly property real length: root.hasPlayer && root.p.lengthSupported ? Math.max(0, root.p.length) : 0
    readonly property bool seekable: root.hasPlayer && root.p.canSeek && root.p.positionSupported && root.length > 0

    // Which window this player lives in (see MediaOwner.js). Reading
    // Hyprland.toplevels.values keeps it live as windows come and go.
    readonly property var ownerInfo: root.hasPlayer ? Owner.resolve(root.p, Hyprland.toplevels.values)
                                                    : { matches: [], viaFallback: false }
    readonly property bool usingLua: Hyprland.usingLua !== false

    // The name on a tab: the player's identity, or, when it is really a Firefox
    // fork wearing Firefox's name, the window's class ("zen-twilight" -> "Zen
    // Twilight"). Reading Hyprland.toplevels.values keeps it live.
    function labelFor(pl) {
        if (!pl)
            return "Media"
        let raw = String(pl.identity ?? "")
        const info = Owner.resolve(pl, Hyprland.toplevels.values)
        if (info.viaFallback && info.matches.length > 0)
            raw = Owner.classOf(info.matches[0]).split(".").pop()
        return MM.appLabel(raw)
    }

    // One of the five SEKAI attribute colours per app, the same one every time.
    function toneFor(name) {
        return Theme.attributeColors[MM.pickIndex(name, Theme.attributeColors.length)]
    }

    readonly property string appName: root.labelFor(root.hasPlayer ? root.p : null)
    readonly property color appColor: root.toneFor(root.appName)

    // Cover art: the player's own, else a YouTube tab's thumbnail.
    readonly property string art: {
        if (!root.hasPlayer)
            return ""
        const direct = root.p.trackArtUrl ?? ""
        if (direct !== "")
            return direct
        const md = root.p.metadata
        return MM.youtubeThumb(md ? md["xesam:url"] : undefined)
    }

    readonly property string trackKey: root.hasPlayer ? String(root.p.trackTitle ?? "") + "|" + String(root.p.trackArtist ?? "") : ""
    readonly property string subLine: {
        if (!root.hasPlayer)
            return ""
        const artist = String(root.p.trackArtist ?? "")
        const album = String(root.p.trackAlbum ?? "")
        return artist !== "" && album !== "" ? artist + "  ·  " + album : artist + album
    }

    // Take the person to the player's window, workspace included.
    //
    // MprisPlayer.raise() only asks the player to raise itself, which browsers
    // answer with a taskbar "attention" flash and no workspace switch under
    // Hyprland. So use the window found above: prefer the one whose title
    // carries the track title (a browser's title is its active tab), then the
    // focused one, then any. Switch to its workspace first and focus it second
    // (what the dock does, since focuswindow alone doesn't always cross
    // workspaces). No window found: fall back to the player's own raise().
    function openPlayerWindow() {
        if (!root.hasPlayer)
            return
        const matches = root.ownerInfo.matches
        if (matches.length === 0) {
            if (root.p.canRaise)
                root.p.raise()
            return
        }

        const title = String(root.p.trackTitle ?? "").toLowerCase()
        const target = (title !== "" ? matches.find(t => String(t.title ?? t.lastIpcObject?.title ?? "").toLowerCase().indexOf(title) !== -1) : null)
            ?? matches.find(t => t.activated)
            ?? matches[0]

        let address = String(target.address ?? target.lastIpcObject?.address ?? "")
        if (address === "")
            return
        if (address.indexOf("0x") !== 0)
            address = "0x" + address

        const ws = target.workspace?.id ?? target.lastIpcObject?.workspace?.id
        if (ws !== undefined && ws !== null)
            Hyprland.dispatch(root.usingLua
                ? "hl.dsp.focus({ workspace = " + ws + " })"
                : "workspace " + ws)
        Hyprland.dispatch(root.usingLua
            ? "hl.dsp.focus({ window = \"address:" + address + "\" })"
            : "focuswindow address:" + address)
    }

    // (The player does not announce its position, so ask for it first.)
    function seekBy(sec) {
        if (!root.seekable)
            return
        root.p.positionChanged()
        root.p.position = Math.max(0, Math.min(root.length, root.p.position + sec))
    }

    onKeyed: event => {
        if (!root.hasPlayer)
            return
        if (event.key === Qt.Key_Space && root.p.canTogglePlaying) {
            root.p.togglePlaying()
            event.accepted = true
        } else if (event.key === Qt.Key_N && root.p.canGoNext) {
            root.p.next()
            event.accepted = true
        } else if (event.key === Qt.Key_P && root.p.canGoPrevious) {
            root.p.previous()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.seekBy(5)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.seekBy(-5)
            event.accepted = true
        }
    }

    // ===== the design =====
    readonly property int pad: 16
    readonly property int innerW: 304
    readonly property int coverSize: 76

    contentWidth: root.innerW + 2 * root.pad
    contentHeight: stack.implicitHeight + 2 * root.pad - 2

    // ===== colours =====
    // The cover's colours, for the play key (the visualizer's reader: it downloads a
    // web cover once into the cache, ColorQuantizer takes the most saturated colours
    // and lifts them so the dark ink reads on them).
    VisualizerCover {
        id: cover
        artUrl: root.art
        enabled: root.hasTrack
    }
    readonly property var coverColors: cover.palette
    readonly property color tone: root.coverColors ? Qt.lighter(root.coverColors[0], 1.06) : Theme.accentMint
    readonly property color tone2: root.coverColors ? root.coverColors[1] : Theme.accentCyan

    onOpenChanged: {
        if (open)
            root.picked = null
    }

    // The words: the title, then the artist under it (a video with no artist: the
    // album, or the app).
    readonly property string artistText: root.hasPlayer ? String(root.p.trackArtist ?? "") : ""
    readonly property string titleText: root.hasPlayer ? String(root.p.trackTitle ?? "") : ""
    readonly property string line1: {
        if (!root.hasPlayer)
            return "Nothing playing"
        if (root.titleText !== "")
            return root.titleText
        return root.artistText !== "" ? root.artistText : root.appName
    }
    readonly property string line2: {
        if (!root.hasPlayer)
            return "Start a song or a video"
        if (root.titleText === "")
            return ""
        if (root.artistText !== "")
            return root.artistText
        const album = String(root.p.trackAlbum ?? "")
        return album !== "" ? album : root.appName
    }

    // ===== the card =====
    Column {
        id: stack
        x: root.pad
        y: root.pad - 2
        width: root.innerW
        spacing: 14

        // ===== the tabs (only with more than one player) =====
        Item {
            id: tabBox
            visible: root.multi
            width: stack.width
            height: 24

            Row {
                id: tabRow
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 4
                clip: true

                Repeater {
                    // An integer model: the delegates stay put while the list updates.
                    model: root.hasPlayer ? root.players.length : 0

                    delegate: MediaTab {
                        id: tab
                        required property int index
                        readonly property var pl: root.players[tab.index] ?? null

                        active: tab.pl === root.p
                        text: root.labelFor(tab.pl)
                        tone: root.toneFor(root.labelFor(tab.pl))
                        onClicked: {
                            if (!tab.active && tab.pl)
                                root.picked = tab.pl
                        }
                    }
                }
            }

            Timer {
                id: wheelGate
                interval: 160
            }
            MouseArea {
                anchors.fill: tabRow
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheelGate.running) {
                        wheel.accepted = true
                        return
                    }
                    wheelGate.restart()
                    root.picked = wheel.angleDelta.y < 0 ? MM.nextPlayer(root.players, root.p)
                                                         : MM.prevPlayer(root.players, root.p)
                    wheel.accepted = true
                }
            }
        }

        // ===== the song =====
        Item {
            id: song
            width: stack.width
            height: root.coverSize + Theme.shadowOffset

            // The cover: a keycap. Raised while the song plays, pressed flush when
            // it is paused. Click it to play / pause.
            Pill {
                id: jacket
                width: root.coverSize
                height: root.coverSize + Theme.shadowOffset
                cornerRadius: 18
                ringWidth: 4
                fillColor: Theme.surfaceHover
                pressed: jacketArea.pressed || !root.playing

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.max(0, jacket.cornerRadius - jacket.ringWidth)
                    color: Theme.surfaceHover

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: coverImage.status !== Image.Ready
                        name: root.hasTrack ? "music_note" : "music_off"
                        size: 36
                        fill: 0
                        color: Theme.inkSub
                    }

                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        cache: false
                        sourceSize: Qt.size(240, 240)
                        opacity: root.playing ? 1 : 0.9
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    // Hover: what pressing it does.
                    Rectangle {
                        anchors.fill: parent
                        color: "#55000000"
                        opacity: jacketArea.containsMouse && jacketArea.enabled ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: root.playing ? "pause" : "play_arrow"
                            size: 38
                            fill: 0
                            weight: 500
                            color: Theme.textWhite
                        }
                    }
                }
            }

            MouseArea {
                id: jacketArea
                anchors.fill: jacket
                enabled: root.hasPlayer && root.p.canTogglePlaying
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.p.togglePlaying()
            }

            Column {
                id: info
                x: root.coverSize + 16
                width: song.width - x
                anchors.verticalCenter: jacket.verticalCenter
                anchors.verticalCenterOffset: -Theme.shadowOffset / 2
                spacing: 4

                // The app, as a small gem and its name (with several players the
                // tabs above say it instead).
                Row {
                    visible: !root.multi
                    spacing: 6

                    DiamondDot {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 7
                        lit: true
                        litColor: root.appColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, info.width - 20)
                        elide: Text.ElideRight
                        text: root.appName.toUpperCase()
                        color: Theme.inkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        font.letterSpacing: 1.2
                    }
                }

                Text {
                    width: parent.width
                    text: root.line1
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    width: parent.width
                    visible: root.line2 !== ""
                    text: root.line2
                    elide: Text.ElideRight
                    color: Theme.inkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // ===== the keys: [EQ] [prev] [play] [next] [window] =====
        Row {
            id: keys
            height: 48          // the tall keys' height; the small tool keys centre in it
            spacing: 8

            MediaKey {
                y: Math.round((keys.height - height) / 2)
                compact: true
                icon: "equalizer"
                onClicked: root.eqRequested()
            }
            MediaKey {
                width: 56
                icon: "skip_previous"
                available: root.hasPlayer && root.p.canGoPrevious
                onClicked: root.p.previous()
            }
            MediaKey {
                width: 92
                primary: true
                icon: root.playing ? "pause" : "play_arrow"
                label: root.playing ? "Pause" : "Play"
                toneTop: root.tone
                toneBottom: root.tone2
                available: root.hasPlayer && root.p.canTogglePlaying
                onClicked: root.p.togglePlaying()
            }
            MediaKey {
                width: 56
                icon: "skip_next"
                available: root.hasPlayer && root.p.canGoNext
                onClicked: root.p.next()
            }
            MediaKey {
                y: Math.round((keys.height - height) / 2)
                compact: true
                icon: "open_in_new"
                available: root.hasPlayer
                onClicked: root.openPlayerWindow()
            }
        }
    }
}
