import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The screen of the launcher phone (LauncherPhone.qml): the shell's home
// screen. Same 654x1214 frame as the Quick Panel's face, so it sits in the same
// PhoneBody.
//
//   - a clock / date strip at the top (the notch is in the middle of it)
//   - a search pill: type anything and the Apps drawer takes over
//   - APPS: every installed app, A to Z, or the ranked matches for what you typed
//
// There is no Home page, no Back chip and no Settings / Wallpapers tile: Settings is
// the gear on the Quick Panel and the Wallpapers have their own key.
//
// Keys: type to search, arrows move the pick, Enter opens it (the first match
// while searching), Escape clears the search, then asks to go back
// (closeRequested). Ctrl+1..4 jump to a screen of the phone (jumpRequested).
//
// It is the Apps screen of the one phone (QuickPanel.qml, PhoneRoute.js).
//
// What the old Overview + App Launcher board could do beyond launching apps (the
// calculator, clipboard, colour, emoji and web cards, `> cmd`, system actions like
// "lock") is here too, in LauncherExtras.qml, driven by the same search box.
//
// Pure UI apart from reading the app index it is given: it never launches
// anything itself, it asks (`appActivated`,
// `closeRequested`, `doneRequested`) and QuickPanel.qml does it.
Item {
    id: face

    // Keeps the classic (white) look in the first dark mode, like the Quick Panel,
    // Settings and Wallpapers screens; see Theme.classicFor. The tiles are Pills, and
    // Pill / MaterialIcon only use the phone's colours inside something that says so.
    readonly property bool classicPanel: true

    width: 654
    height: 1214

    // ===== what it is given =====
    // AppSource.qml: `entries`, `rankEntries(query)` and `iconFor(name)`.
    property var source: null
    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    // Same idea as QuickPanelFace.renderScale (kept so a layer inside could use it).
    property real renderScale: 1
    // How far down the face (design units) is above the monitor's bottom edge.
    // The launcher phone only peeks out of the corner (like the Quick Panel), so
    // the page is laid out above this line; the whole face is 1214.
    property real visibleBottom: 1214

    // ===== what it asks for =====
    signal appActivated(var app)
    // Escape with nothing left to undo here: go back one screen.
    signal closeRequested()
    // Ctrl+1..4 while typing: 1 Quick, 2 Apps, 3 Wallpapers, 4 Settings.
    signal jumpRequested(int number)
    // An extra was run or copied (an action, a command, a copied colour...): the phone
    // should go away.
    signal doneRequested()
    // The colour eyedropper needs the screen: the phone goes away; once a colour is
    // picked, `colorPickedBack` asks for the phone again on the colour card.
    signal pickerRequested()
    signal colorPickedBack(string hex)

    // ===== the layout (design units) =====
    readonly property real sideX: 52
    readonly property real gridW: 550
    readonly property int columns: 4
    readonly property real cellW: gridW / columns
    readonly property real cellH: 168

    // ===== state =====
    readonly property string query: input.text
    readonly property bool searching: query.trim().length > 0
    // The pick comes from the arrow keys (not the mouse): only then is one
    // tile picked out.
    property bool keyNav: false

    // The grid used to come in each time the screen did: a quick rise and fade while
    // the phone was still sliding up under it. That is the expensive part of opening
    // the phone on Apps: the screen's picture is a big supersampled, multisampled
    // layer, and while nothing in it changes it is only moved (the Quick screen's
    // entry is that cheap). Fading the grid changed it on every frame of the slide,
    // so every frame redrew the whole screen *and* the phone around it. So the grid
    // is simply there with the phone now. true = the old rise and fade back.
    property bool reveal: false
    // 0 = just arrived, 1 = settled.
    property real revealT: 1
    onEnabledChanged: {
        if (enabled && reveal) {
            revealT = 0
            revealAnim.restart()
        }
    }
    // A beat behind the phone, so the apps seem to arrive after it rather than with it.
    SequentialAnimation {
        id: revealAnim

        PauseAnimation {
            duration: 60
        }

        NumberAnimation {
            target: face
            property: "revealT"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    function focusSearch() {
        input.forceActiveFocus()
        input.cursorPosition = input.text.length
    }

    // Letters typed on the Quick screen carry over into the search box. The text
    // is set even before this screen is visible (a hidden item cannot take the
    // keyboard yet; QuickPanel.qml hands it over once the screen has come in).
    function appendText(text) {
        input.text = input.text + text
        input.cursorPosition = input.text.length
    }

    // Replace what is typed (the calculator's keys, a colour shade).
    function setText(text) {
        input.text = text
        input.cursorPosition = input.text.length
        input.forceActiveFocus()
    }

    // Back to how it opens: all apps, nothing typed, nothing picked.
    function reset() {
        input.text = ""
        keyNav = false
        drawerGrid.currentIndex = -1
        drawerGrid.positionViewAtBeginning()
    }

    // Escape: one step back.
    function back() {
        if (input.text.length > 0)
            input.text = ""
        else
            face.closeRequested()
    }

    // What the grid shows: AppSource's own entry objects (built once, so the same app
    // is always the same object), every app A to Z or the ranked matches. Nothing is
    // copied or rebuilt here per letter typed.
    readonly property var drawerEntries: {
        if (!face.source)
            return []
        return face.searching ? face.source.rankEntries(face.query) : face.source.entries
    }

    // The grid's model. A ScriptModel compares the new list with the old one by `key`
    // and only adds, removes and moves the tiles that really changed, so typing a
    // letter keeps the tiles of the apps that still match instead of throwing every
    // tile away and building them all again (what a plain array as the model does).
    ScriptModel {
        id: drawerModel

        values: face.drawerEntries
        objectProp: "key"
    }

    function activate(item) {
        if (!item)
            return
        if (item.app)
            face.appActivated(item.app)
    }

    // Whatever has the pick right now (the first match while searching).
    function activateCurrent() {
        const grid = drawerGrid
        let i = grid.currentIndex
        if (i < 0 && face.searching)
            i = 0
        if (i >= 0 && i < face.drawerEntries.length)
            face.activate(face.drawerEntries[i])
    }

    function moveKey(key) {
        // A card (calculator, emoji...) takes the arrows itself.
        if (extrasLayer.cardShown) {
            extrasLayer.navigate(key === Qt.Key_Left ? -1 : key === Qt.Key_Right ? 1 : 0,
                                 key === Qt.Key_Up ? -1 : key === Qt.Key_Down ? 1 : 0)
            return
        }
        // Rows above the grid (system actions, a command): Up / Down walk them first.
        if (key === Qt.Key_Up || key === Qt.Key_Down) {
            const where = extrasLayer.moveRows(key === Qt.Key_Down ? 1 : -1,
                                               drawerGrid.currentIndex >= 0,
                                               drawerGrid.currentIndex >= 0 && drawerGrid.currentIndex < face.columns)
            if (where === "rows") {
                face.keyNav = true
                drawerGrid.currentIndex = -1
                return
            }
            if (where === "grid") {
                face.keyNav = true
                drawerGrid.currentIndex = 0
                return
            }
        }
        const grid = drawerGrid
        if (grid.count === 0)
            return
        face.keyNav = true
        if (grid.currentIndex < 0) {
            grid.currentIndex = 0
            return
        }
        if (key === Qt.Key_Left)
            grid.moveCurrentIndexLeft()
        else if (key === Qt.Key_Right)
            grid.moveCurrentIndexRight()
        else if (key === Qt.Key_Up)
            grid.moveCurrentIndexUp()
        else
            grid.moveCurrentIndexDown()
    }

    // New text: the pick starts on the first match.
    onQueryChanged: {
        drawerGrid.currentIndex = face.searching ? 0 : -1
        drawerGrid.positionViewAtBeginning()
        // Once the model has taken the new list as well.
        Qt.callLater(() => drawerGrid.positionViewAtBeginning())
    }

    // ===== top strip: clock + date =====
    Column {
        x: 64
        y: 38
        spacing: 0

        Text {
            text: face.clockText
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
        }

        Text {
            text: face.dateText
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.italic: false
        }
    }

    // ===== search pill =====
    Rectangle {
        x: face.sideX + 4
        y: 124 + 4
        width: face.gridW
        height: 68
        radius: 34
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: pill

        x: face.sideX
        y: 124
        width: face.gridW
        height: 68
        radius: 34
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true

        MaterialIcon {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 30
        }

        Text {
            x: 70
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "Search apps"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
        }

        TextInput {
            id: input

            x: 70
            width: parent.width - 70 - 64
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.pInk
            selectionColor: Theme.accentCyan
            selectedTextColor: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
            clip: true
            focus: true
            selectByMouse: true

            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                    face.jumpRequested(event.key - Qt.Key_0)
                } else if (event.key === Qt.Key_Escape) {
                    face.back()
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!extrasLayer.enter((event.modifiers & Qt.ShiftModifier) !== 0))
                        face.activateCurrent()
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                           || event.key === Qt.Key_Left && (input.text.length === 0 || extrasLayer.cardMode === "emoji")
                           || event.key === Qt.Key_Right && (input.text.length === 0 || extrasLayer.cardMode === "emoji")) {
                    face.moveKey(event.key)
                } else if (event.key === Qt.Key_Tab) {
                    // Tab picks the next search engine on the web card.
                    if (!extrasLayer.tab(1))
                        face.moveKey(Qt.Key_Right)
                } else if (event.key === Qt.Key_Backtab) {
                    if (!extrasLayer.tab(-1))
                        face.moveKey(Qt.Key_Left)
                } else {
                    return
                }
                event.accepted = true
            }
        }

        // Clears what was typed.
        Item {
            visible: input.text.length > 0
            x: parent.width - 56
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: clearArea.containsMouse ? Theme.accentMint : "transparent"
            }

            MaterialIcon {
                anchors.centerIn: parent
                name: "close"
                size: 26
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    input.text = ""
                    face.focusSearch()
                }
            }
        }
    }

    // ===== the page =====
    // The area under the pill, down to near the bottom of what shows.
    readonly property real pageY: 228
    // Down to 1040 + 60 on the whole face, higher when less of it shows (34 = a
    // little room above the monitor's edge).
    readonly property real pageBottom: Math.max(pageY + 168 + 52, Math.min(1040, face.visibleBottom - 84 - 34)) + 60
    readonly property real pageH: pageBottom - pageY

    // APPS
    Item {
        id: drawerPage

        x: face.sideX
        // Under the rows (system actions, a command) when there are any, and out of
        // the way while a card (calculator, emoji...) has the page.
        y: face.pageY + extrasLayer.rowsHeight + (1 - face.revealT) * 30
        width: face.gridW
        height: face.pageH - extrasLayer.rowsHeight
        opacity: face.revealT
        scale: 0.96 + 0.04 * face.revealT
        transformOrigin: Item.Top
        visible: opacity > 0.01 && !extrasLayer.cardShown

        WheelScroll { scroller: drawerGrid }
        GridView {
            id: drawerGrid

            anchors.fill: parent
            cellWidth: face.cellW
            cellHeight: face.cellH
            clip: true
            model: drawerModel
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            // One row built ahead (was two): fewer tiles alive, and a tile that
            // scrolls out is kept and handed to the next app that scrolls in
            // instead of being destroyed and built again.
            cacheBuffer: face.cellH
            reuseItems: true
            delegate: tileDelegate

            SekaiScrollBar {}
        }

        Text {
            anchors.centerIn: parent
            visible: face.searching && drawerGrid.count === 0 && extrasLayer.rows.length === 0
            text: "No apps match"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 24
            font.weight: Font.Bold
        }
    }

    // ===== the extras: cards and rows (LauncherExtras.qml) =====
    LauncherExtras {
        id: extrasLayer

        x: face.sideX
        y: face.pageY
        width: face.gridW
        height: face.pageH
        visible: face.searching
        query: face.query
        active: face.enabled && face.visible
        appCount: face.drawerEntries.length
        pageWidth: face.gridW
        pageHeight: face.pageH

        onDoneRequested: face.doneRequested()
        onSetTextRequested: text => face.setText(text)
        onPickerRequested: face.pickerRequested()
        onColorPicked: hex => face.colorPickedBack(hex)
    }

    // ===== one tile: a Quick Panel button with the app's icon, the name under it =====
    // Looks exactly like QuickToggle.qml's square button (the Quick Panel's header
    // keys): white with a 3px outline and a small hard shadow at rest; lit (pointer
    // over it, or the arrow keys have it) it goes mint-to-cyan inside a white ring,
    // with a thicker outline and a longer shadow; pressed, it sinks onto its shadow and
    // springs back.
    //
    // It used to be a `Pill`. The look is the same, but a Pill carries what a button
    // in the bar needs and a tile does not (it walks up the tree to find which colours
    // to use, has colour fades and two press animations of its own, and a gradient
    // for the ring), and the grid builds dozens of these, again on every scroll. Here
    // it is four shapes, the colours the Apps screen always uses (`classicPanel` is
    // true above), and ONE animation each for lit and for pressed.
    Component {
        id: tileDelegate

        Item {
            id: tile

            required property var modelData
            required property int index

            readonly property bool picked: face.keyNav && GridView.isCurrentItem
            readonly property bool lit: area.containsMouse || picked

            // 0 = the resting look, 1 = the lit look; glides between them. Every frame
            // of it redraws the whole phone, so it is short.
            property real litP: lit ? 1 : 0
            Behavior on litP {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            // 0 = up, 1 = pushed down onto the shadow. Presses in fast, springs back
            // past rest and settles, like every Quick Panel button.
            property real pressP: area.pressed ? 1 : 0
            Behavior on pressP {
                NumberAnimation {
                    duration: area.pressed ? 80 : 260
                    easing.type: area.pressed ? Easing.OutQuad : Easing.OutBack
                    easing.overshoot: area.pressed ? 0 : 2.2
                }
            }

            readonly property real capSize: 100
            readonly property real capX: Math.round((width - capSize) / 2)
            readonly property real capY: 12
            readonly property real cornerR: 30

            // Where the hard shadow sits, the outline and the white ring, all lit-dependent.
            readonly property real shadowDx: 3 + 2 * litP
            readonly property real shadowDy: 1 + litP
            readonly property real borderW: 3 + 2 * litP
            readonly property real ringW: 3 + 8 * litP

            width: face.cellW
            height: face.cellH

            // The shadow never moves; the cap above it either shows it (up) or covers it
            // (pressed). The cap stays put when it lights up, only the shadow grows.
            Rectangle {
                x: tile.capX + tile.shadowDx
                y: tile.capY + tile.shadowDy
                width: tile.capSize
                height: tile.capSize
                radius: tile.cornerR
                color: Theme.pLineShadow
                antialiasing: true
            }

            Item {
                x: tile.capX + tile.pressP * tile.shadowDx
                y: tile.capY + tile.pressP * tile.shadowDy
                width: tile.capSize
                height: tile.capSize

                // outline + white ring
                Rectangle {
                    id: ring

                    anchors.fill: parent
                    radius: tile.cornerR
                    color: Theme.pRingWhite
                    border.width: tile.borderW
                    border.color: Theme.pLine
                    antialiasing: true
                }

                // the face inside the ring
                Rectangle {
                    id: inner

                    anchors.fill: ring
                    anchors.margins: tile.ringW
                    radius: Math.max(0, tile.cornerR - tile.ringW)
                    color: Theme.pSurface
                    antialiasing: true

                    // The lit look, fading in on top of the white base. Not drawn at all
                    // at rest.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: tile.litP > 0.002
                        opacity: tile.litP
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accentMint }
                            GradientStop { position: 1.0; color: Theme.accentCyan }
                        }
                        antialiasing: true
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 58
                        asynchronous: true
                        scale: 1 + 0.06 * tile.litP
                        // The path is looked up once per icon (AppSource.iconFor), not on
                        // every tile that is built.
                        source: face.source ? face.source.iconFor(tile.modelData.icon) : ""
                    }
                }
            }

            Text {
                x: 4
                y: tile.capY + tile.capSize + 18
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.modelData.name
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            // A sibling of the cap, not inside it: the cap moves while pressed, and a
            // MouseArea riding along would slide out from under the click.
            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: face.keyNav = false
                onClicked: face.activate(tile.modelData)
            }
        }
    }
}
