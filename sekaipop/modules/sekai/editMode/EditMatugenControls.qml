import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/MatugenMath.js" as MG

// The Matugen theme's controls, in Edit Desktop's THEME tab: they take the tile row's place
// when the Matugen tile is clicked while it is the theme on (EditThemeBoard.qml, `tuning`).
// The design is docs/handoffs/matugen-controls (issue #28); docs/MATUGEN-CONTROLS.md says
// where this departs from it.
//
//   Back      the matugen palette in miniature; click (or Esc) goes back to the tiles.
//             While matugen re-runs it says "Working" and the miniature has moving stripes.
//   Scheme    matugen's --type, nine keys
//   Seed      which of the wallpaper's colours leads: Auto, or one of its swatches
//             (ThemeService.matugenSources)
//   Contrast  matugen's --contrast in five steps
//   Accents   A and B as they are now; the pin keeps one fixed whatever the wallpaper
//             says. Pinning opens "PIN <X> TO": the colour it has now, one of the
//             wallpaper's, or any hex (typed, or picked off the screen with hyprpicker).
//
// Every change is a setting (SettingsService "matugen.*", cleaned by MatugenMath.js), so it
// is saved, carried by presets, and re-runs matugen at once (ThemeService.matugenTuning).
// The measurements are the handoff's own (hand-set px, not a scale); keep them. The rings are
// not: Pill's ringWidth counts from the outer edge (outline included), and these follow the
// shelf's own keys and tiles (a thin ring), not the handoff's 3 - 4 px insets.
Item {
    id: root

    // Back to the tile row.
    signal back()
    // The hex field gave the keyboard back (EditTray: Esc leaves Edit Desktop again).
    signal finished()

    // "" | "A" | "B": the accent whose "PIN TO" panel is open.
    property string picking: ""

    readonly property var pal: ThemeService.matugenPalette || ThemeService.palette
    readonly property var sources: ThemeService.matugenSources
    readonly property bool busy: ThemeService.matugenBusy

    // The current colour of an accent, and whether it is pinned.
    function accentOf(which) {
        return String(which === "A" ? root.pal.A : root.pal.B)
    }
    function pinOf(which) {
        return which === "A" ? ThemeService.matugenPinA : ThemeService.matugenPinB
    }
    function pin(which, hex) {
        const c = MG.cleanHex(hex)
        if (c === "")
            return
        SettingsService.set("matugen.pin" + which, c)
        root.picking = ""
    }
    function unpin(which) {
        SettingsService.set("matugen.pin" + which, "")
        if (root.picking === which)
            root.picking = ""
    }

    onVisibleChanged: if (!visible) root.picking = ""

    // Opening a PIN TO panel scrolls the row so it is in view (the design moves the row
    // 322 px left to show it).
    onPickingChanged: {
        if (root.picking !== "")
            Qt.callLater(() => flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, accents.x + accents.width - flick.width + 4)))
        else
            flick.contentX = 0
    }

    Gradient {
        id: plateFill
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }
    Gradient {
        id: keyFill
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.accentCyan }
        GradientStop { position: 1.0; color: Theme.accentMint }
    }

    // ===== pieces =====

    // A block: the shelf's chunky card (outline 3, ring 4, shadow 4, corner 15), 138 tall.
    // Its content sits 3 + 11 down and 3 + 13 in (border + padding).
    component Block: Item {
        id: blk

        default property alias content: inner.data
        property string title: ""
        property string titleNote: ""

        height: 142

        Pill {
            anchors.fill: parent
            cornerRadius: 15
            ringWidth: 4
            shadowDx: 0
            shadowDy: 4
            fillColor: Theme.pSurface
        }

        Row {
            visible: blk.title !== ""
            x: 16
            y: 14
            height: 14
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: blk.title.toUpperCase()
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Black
                font.styleName: Theme.fontStyleBold
                font.letterSpacing: 1.1
            }

            Text {
                visible: blk.titleNote !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "· " + blk.titleNote
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    // A key: outline 2.5, corner 10, hard shadow 3; lit with the accent gradient (and a
    // thin ring, like the shelf's tabs) when it is the one on.
    component Key: Item {
        id: key

        property string text: ""
        property string icon: ""
        property bool on: false
        property bool spinning: false
        property real keyHeight: 30

        signal clicked()

        width: 30
        height: key.keyHeight + 3

        Pill {
            anchors.fill: parent
            cornerRadius: 10
            borderWidth: 2.5
            ringWidth: key.on ? 3.5 : 2.5
            shadowDx: 0
            shadowDy: 3
            pressed: keyArea.pressed
            fillColor: keyArea.containsMouse && !key.on ? Theme.pSurfaceHover : Theme.pSurface
            fillGradient: key.on ? keyFill : null
        }

        Row {
            x: (key.width - width) / 2
            y: (key.keyHeight - height) / 2
            spacing: 5

            MaterialIcon {
                visible: key.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: key.icon
                size: 15
                weight: 700
                color: key.on ? Theme.colBorder : Theme.pInk
            }

            Text {
                visible: key.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: key.text
                color: key.on ? Theme.colBorder : Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: key.on ? Font.Black : Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            // Working on it: the shell's busy glyph (UpdatesBadge.qml), turning.
            MaterialIcon {
                visible: key.spinning
                anchors.verticalCenter: parent.verticalCenter
                name: "sync"
                size: 13
                weight: 700
                color: key.on ? Theme.colBorder : Theme.pInk
                transformOrigin: Item.Center

                RotationAnimator on rotation {
                    running: key.spinning
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 800
                }
            }
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: key.clicked()
        }
    }

    // A colour chip with the shelf's ring: the seed swatches (44 x 62, corner 11) and the
    // PIN TO swatches (30 x 30, corner 9). The one on is lifted 3 px, heavier, with a tick.
    component Swatch: Item {
        id: sw

        property color colour: "white"
        property bool on: false
        property real radius: 11

        signal clicked()

        Pill {
            width: sw.width
            height: sw.height + (sw.on ? 6 : 3)
            y: sw.on ? -3 : 0
            cornerRadius: sw.radius
            borderWidth: sw.on ? 3 : 2.5
            ringWidth: sw.on ? 5 : 4
            shadowDx: 0
            shadowDy: sw.on ? 6 : 3
            pressed: swArea.pressed
            fillColor: sw.colour
        }

        Rectangle {
            visible: sw.on
            x: sw.width - 20 + 8
            y: -8 - 3
            width: 20
            height: 20
            radius: 10
            color: Theme.accentMint
            border.width: 2
            border.color: Theme.pLine
            antialiasing: true

            MaterialIcon {
                anchors.centerIn: parent
                name: "check"
                size: 12
                weight: 700
                color: Theme.colBorder
            }
        }

        MouseArea {
            id: swArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.clicked()
        }
    }

    // A caption under a block's keys.
    component Cap: Text {
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
    }

    // ===== the row =====
    Flickable {
        id: flick
        anchors.fill: parent

        contentWidth: Math.max(flick.width, row.width + 8)
        contentHeight: flick.height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: flick.contentWidth > flick.width + 1

        Behavior on contentX {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = Theme.wheelPx(event, true)
                flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d))
            }
        }

        Row {
            id: row
            x: 4
            y: (flick.height - 138) / 2
            spacing: 10

            // ===== Back: the palette in miniature =====
            Item {
                id: backBlk
                width: 110
                height: 142

                Pill {
                    anchors.fill: parent
                    cornerRadius: 15
                    ringWidth: 4
                    shadowDx: 0
                    shadowDy: 4
                    pressed: backArea.pressed
                    fillGradient: plateFill
                }

                // 86 x 62, outline 3, corner 9: the shell in the matugen palette (the same
                // drawing as the tiles', smaller).
                Rectangle {
                    id: mini
                    x: 12
                    y: 12
                    width: 86
                    height: 62
                    radius: 9
                    color: Theme.dark ? Qt.darker(Qt.color(root.pal.deep), 1.3) : Qt.color(root.pal.boardBg)
                    border.width: 3
                    border.color: root.pal.border
                    clip: true
                    antialiasing: true

                    readonly property color surf: Theme.dark ? Qt.lighter(Qt.color(root.pal.deep), 1.18) : "#ffffff"

                    Gradient {
                        id: miniAccent
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.pal.A }
                        GradientStop { position: 1.0; color: root.pal.B }
                    }

                    Rectangle {
                        x: 7
                        y: 7
                        width: 72
                        height: 11
                        radius: 6
                        color: mini.surf
                        border.width: 2
                        border.color: root.pal.border
                    }
                    Rectangle {
                        x: 7
                        y: 23
                        width: 36
                        height: 34
                        radius: 6
                        color: mini.surf
                        border.width: 2
                        border.color: root.pal.border
                    }
                    Rectangle {
                        x: 47
                        y: 23
                        width: 32
                        height: 16
                        radius: 6
                        gradient: miniAccent
                        border.width: 2
                        border.color: root.pal.border
                    }
                    Rectangle {
                        x: 47
                        y: 41
                        width: 32
                        height: 16
                        radius: 6
                        color: mini.surf
                        border.width: 2
                        border.color: root.pal.border
                    }

                    // Working: white stripes sliding across (16 px period, 0.9 s a step).
                    Canvas {
                        id: stripes
                        visible: root.busy
                        x: -23
                        width: mini.width + 46
                        height: mini.height
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.fillStyle = "rgba(255,255,255,0.55)"
                            for (let i = -height; i < width + height; i += 16) {
                                ctx.beginPath()
                                ctx.moveTo(i, height)
                                ctx.lineTo(i + 8, height)
                                ctx.lineTo(i + 8 + height, 0)
                                ctx.lineTo(i + height, 0)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                        NumberAnimation on x {
                            running: root.busy
                            loops: Animation.Infinite
                            from: -23
                            to: 0
                            duration: 900
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 110
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.busy ? "sync" : "chevron_left"
                        size: 14
                        weight: 700
                        color: Theme.colBorder
                        transformOrigin: Item.Center

                        RotationAnimator on rotation {
                            running: root.busy
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.busy ? "Working" : "Themes"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Black
                        font.styleName: Theme.fontStyleBold
                    }
                }

                // The theme on: the tiles' tick.
                Rectangle {
                    x: backBlk.width - 24 + 9
                    y: -9
                    width: 24
                    height: 24
                    radius: 12
                    color: Theme.accentMint
                    border.width: 2
                    border.color: Theme.pLine
                    antialiasing: true

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 15
                        weight: 700
                        color: Theme.colBorder
                    }
                }

                EditPinBadge {
                    x: -9
                    y: -9
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            // ===== Scheme =====
            // Departs from the handoff: three rows of its 30 px keys under the header ran past
            // the bottom of a 138 px block (and the grid 8 px past its right side), so the keys
            // are 27 tall and the block 16 px wider. See docs/MATUGEN-CONTROLS.md.
            Block {
                width: 16 + 3 * 76 + 2 * 5 + 16
                title: "Scheme"

                Grid {
                    x: 16
                    y: 34
                    columns: 3
                    columnSpacing: 5
                    rowSpacing: 1

                    Repeater {
                        model: MG.SCHEMES

                        delegate: Key {
                            required property var modelData
                            width: 76
                            keyHeight: 27
                            text: modelData.label
                            on: ThemeService.matugenType === modelData.id
                            spinning: on && root.busy
                            onClicked: SettingsService.set("matugen.scheme", modelData.id)
                        }
                    }
                }
            }

            // ===== Seed =====
            Block {
                // 16 px each side of Auto and the swatches (the handoff's 26 left 6 px poking out).
                width: 16 + 54 + root.sources.length * 50 + 16
                title: "Seed"
                titleNote: "leading colour"

                Row {
                    x: 16
                    y: 39
                    spacing: 6

                    Key {
                        width: 54
                        keyHeight: 62
                        on: ThemeService.matugenSeed < 0
                        onClicked: SettingsService.set("matugen.seed", -1)

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (62 - height) / 2
                            spacing: 2

                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "magic_stick"
                                size: 18
                                weight: 700
                                color: ThemeService.matugenSeed < 0 ? Theme.colBorder : Theme.pInk
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Auto"
                                color: ThemeService.matugenSeed < 0 ? Theme.colBorder : Theme.pInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Black
                                font.styleName: Theme.fontStyleBold
                            }
                        }
                    }

                    Repeater {
                        model: root.sources

                        delegate: Swatch {
                            required property var modelData
                            required property int index
                            width: 44
                            height: 62
                            colour: modelData
                            on: ThemeService.matugenSeed === index
                            onClicked: SettingsService.set("matugen.seed", index)
                        }
                    }
                }

                Cap {
                    x: 16
                    y: 109
                    text: root.sources.length === 0 ? "Reading the wallpaper…"
                        : root.sources.length === 1 ? "1 colour in this wallpaper"
                        : root.sources.length + " colours in this wallpaper"
                }
            }

            // ===== Contrast =====
            // 16 px each side of the five keys (the handoff's 190 left 8 px poking out).
            Block {
                width: 16 + 5 * 30 + 4 * 4 + 16
                title: "Contrast"

                Row {
                    x: 16
                    y: 44
                    spacing: 4

                    Repeater {
                        model: MG.CONTRASTS

                        delegate: Key {
                            required property var modelData
                            width: 30
                            text: modelData.label
                            on: ThemeService.matugenContrast === modelData.value
                            onClicked: SettingsService.set("matugen.contrast", modelData.value)
                        }
                    }
                }

                Cap {
                    x: 18
                    y: 80
                    text: "Softer"
                }
                Cap {
                    x: 16 + 5 * 30 + 4 * 4 - 2 - width
                    y: 80
                    text: "Sharper"
                }
            }

            // ===== Accents (and the PIN TO panel) =====
            Block {
                id: accents
                width: 32 + 196 + (root.picking !== "" ? pickPanel.width : 0)
                title: "Accents"

                Column {
                    x: 16
                    y: 34
                    spacing: 6

                    Repeater {
                        model: ["A", "B"]

                        delegate: Item {
                            id: ar
                            required property string modelData
                            readonly property string pinned: root.pinOf(modelData)
                            width: 196
                            height: 40

                            // The colour now, with a pin dot when it is pinned.
                            Pill {
                                id: asw
                                y: 4
                                width: 32
                                height: 32
                                cornerRadius: 10
                                borderWidth: 2.5
                                ringWidth: 4
                                shadowDy: 0
                                fillColor: root.accentOf(ar.modelData)

                                Rectangle {
                                    visible: ar.pinned !== ""
                                    x: asw.width - 18 + 7
                                    y: -7
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: Theme.pSurface
                                    border.width: 2
                                    border.color: Theme.pLine

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "push_pin"
                                        size: 10
                                        weight: 700
                                        color: Theme.pInk
                                    }
                                }
                            }

                            Column {
                                x: 32 + 9
                                width: 196 - 32 - 9 - 9 - 32
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: ar.modelData
                                    color: Theme.pInk
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Black
                                    font.styleName: Theme.fontStyleBold
                                }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 2
                                    lineHeight: 1.15
                                    text: root.accentOf(ar.modelData) + " · " + (ar.pinned !== "" ? "pinned" : "wallpaper")
                                    color: Theme.pInkSub
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }

                            // Pinned: the key is lit and unpins. Not pinned: it opens PIN TO
                            // (lit while that panel is open).
                            Key {
                                x: 196 - 32
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                icon: ar.pinned !== "" ? "keep_off" : "push_pin"
                                on: ar.pinned !== "" || root.picking === ar.modelData
                                onClicked: {
                                    if (ar.pinned !== "")
                                        root.unpin(ar.modelData)
                                    else
                                        root.picking = root.picking === ar.modelData ? "" : ar.modelData
                                }
                            }
                        }
                    }
                }

                // PIN <X> TO: the colour it has now, one of the wallpaper's, or any hex.
                Item {
                    id: pickPanel
                    visible: root.picking !== ""
                    x: 16 + 196
                    y: 14
                    width: 2.5 + 14 + pickRows.width + 13
                    height: 110

                    // The dashed line down its left side.
                    Column {
                        spacing: 4
                        Repeater {
                            model: 11
                            Rectangle {
                                width: 2.5
                                height: 6
                                color: Theme.pSurfaceDivider
                            }
                        }
                    }

                    Column {
                        id: pickRows
                        x: 2.5 + 14
                        spacing: 8

                        Text {
                            height: 14
                            verticalAlignment: Text.AlignVCenter
                            text: "PIN " + root.picking + " TO"
                            color: Theme.pInkSub
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Black
                            font.styleName: Theme.fontStyleBold
                            font.letterSpacing: 1.1
                        }

                        // Keep this one: the colour the accent has right now.
                        Key {
                            width: keepRow.width + 13
                            onClicked: root.pin(root.picking, root.accentOf(root.picking))

                            Row {
                                id: keepRow
                                x: 4
                                y: (30 - height) / 2
                                spacing: 5

                                Pill {
                                    width: 20
                                    height: 20
                                    cornerRadius: 6
                                    borderWidth: 2
                                    ringWidth: 2
                                    shadowDy: 0
                                    fillColor: root.picking !== "" ? root.accentOf(root.picking) : "white"
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Keep this one"
                                    color: Theme.pInk
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.ExtraBold
                                    font.styleName: Theme.fontStyleBold
                                }
                            }
                        }

                        Row {
                            spacing: 6

                            Cap {
                                width: 62
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "Wallpaper"
                            }
                            Repeater {
                                model: root.sources
                                delegate: Swatch {
                                    required property var modelData
                                    width: 30
                                    height: 30
                                    radius: 9
                                    colour: modelData
                                    onClicked: root.pin(root.picking, modelData)
                                }
                            }
                        }

                        Row {
                            spacing: 6

                            Cap {
                                width: 62
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: "Any"
                            }

                            // A hex: Enter pins it. A typo just does nothing.
                            Rectangle {
                                width: 104
                                height: 30
                                radius: 10
                                color: Theme.pSurface
                                border.width: 2.5
                                border.color: Theme.pLine

                                Rectangle {
                                    x: 2.5
                                    y: 2.5
                                    width: parent.width - 5
                                    height: 2
                                    radius: 1
                                    color: Theme.pSurfaceHover
                                }

                                Text {
                                    id: hash
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "#"
                                    color: Theme.pInkSub
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                }

                                TextInput {
                                    id: hexInput
                                    anchors.left: hash.right
                                    anchors.leftMargin: 4
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    maximumLength: 7
                                    clip: true
                                    selectByMouse: true
                                    color: Theme.pInk
                                    font.family: "monospace"
                                    font.pixelSize: 12

                                    Text {
                                        visible: hexInput.text === ""
                                        text: root.picking !== "" ? root.accentOf(root.picking).replace("#", "") : ""
                                        color: Theme.pInkSub
                                        font: hexInput.font
                                    }

                                    Keys.onReturnPressed: root.commitHex()
                                    Keys.onEnterPressed: root.commitHex()
                                    Keys.onEscapePressed: event => {
                                        event.accepted = true
                                        hexInput.text = ""
                                        hexInput.focus = false
                                        root.finished()
                                    }
                                }
                            }

                            Key {
                                width: 32
                                icon: "colorize"
                                onClicked: picker.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    function commitHex() {
        const c = MG.cleanHex(hexInput.text)
        if (c === "")
            return
        hexInput.text = ""
        hexInput.focus = false
        root.pin(root.picking, c)
        root.finished()
    }

    // Pick from the screen: hyprpicker prints the hex it was clicked on.
    Process {
        id: picker
        command: ["hyprpicker", "-f", "hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = MG.cleanHex(text.trim())
                if (c !== "" && root.picking !== "")
                    root.pin(root.picking, c)
            }
        }
    }
}
