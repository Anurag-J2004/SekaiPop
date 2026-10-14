import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Hyprland: gaps and borders, window looks, animations, workspaces and input.
// Values are read from Hyprland itself and changes apply the moment you make
// them; they are also written to ~/.config/hypr/pjsekai_overrides.lua so they
// survive a reload (see scripts/hyprland/hyprland-settings.sh).
SettingsPage {
    id: page

    readonly property string linkLine: "pcall(require, \"pjsekai_overrides\")"

    function setInt(path, v) { HyprlandSettings.set(path, "int", Math.round(v)) }
    function setFloat(path, v) { HyprlandSettings.set(path, "float", v.toFixed(2)) }
    function flip(path) { HyprlandSettings.set(path, "bool", !HyprlandSettings.bool(path)) }

    // The one line hyprland.lua needs for these to outlive a reload.
    SectionCard {
        visible: HyprlandSettings.isLua && !HyprlandSettings.linked
        height: visible ? implicitHeight : 0
        title: "One-time setup"

        Column {
            width: page.fullWidth - 345
            spacing: 10

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Changes apply now, but Hyprland forgets them on its next reload until hyprland.lua loads the override file. Add this line to it once:"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }

            Rectangle {
                width: codeText.implicitWidth + 28
                height: 36
                radius: 18
                color: Theme.pSurfaceDivider
                antialiasing: true

                Text {
                    id: codeText
                    anchors.centerIn: parent
                    text: page.linkLine
                    color: Theme.pInk
                    font.family: "monospace"
                    font.pixelSize: 16
                }
            }
        }

        SettingAction {
            tileWidth: 310
            icon: "content_copy"
            label: "Copy the line"
            detail: "Uses wl-copy"
            onActivated: Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", page.linkLine])
        }
    }

    SectionCard {
        title: "Gaps & borders"

        SettingSlider {
            width: page.halfWidth
            icon: "padding"
            label: "Gaps between windows"
            from: 0
            to: 40
            step: 1
            suffix: " px"
            value: HyprlandSettings.num("general.gaps_in")
            onMoved: v => page.setInt("general.gaps_in", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "crop_free"
            label: "Gaps to the screen edge"
            from: 0
            to: 80
            step: 1
            suffix: " px"
            value: HyprlandSettings.num("general.gaps_out")
            onMoved: v => page.setInt("general.gaps_out", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "border_style"
            label: "Border thickness"
            from: 0
            to: 10
            step: 1
            suffix: " px"
            specialValue: 0
            specialText: "None"
            value: HyprlandSettings.num("general.border_size")
            onMoved: v => page.setInt("general.border_size", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "rounded_corner"
            label: "Corner rounding"
            from: 0
            to: 40
            step: 1
            suffix: " px"
            specialValue: 0
            specialText: "Square"
            value: HyprlandSettings.num("decoration.rounding")
            onMoved: v => page.setInt("decoration.rounding", v)
        }
    }

    SectionCard {
        title: "Windows"

        SettingSlider {
            width: page.halfWidth
            icon: "opacity"
            label: "Focused window opacity"
            from: 0.5
            to: 1
            step: 0.05
            decimals: 2
            value: HyprlandSettings.num("decoration.active_opacity", 1)
            onMoved: v => page.setFloat("decoration.active_opacity", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "opacity"
            label: "Other windows opacity"
            from: 0.5
            to: 1
            step: 0.05
            decimals: 2
            value: HyprlandSettings.num("decoration.inactive_opacity", 1)
            onMoved: v => page.setFloat("decoration.inactive_opacity", v)
        }

        SettingToggle {
            icon: "blur_on"
            label: "Blur"
            checked: HyprlandSettings.bool("decoration.blur.enabled")
            onToggled: page.flip("decoration.blur.enabled")
        }

        SettingStepper {
            icon: "blur_circular"
            label: "Blur size"
            from: 1
            to: 20
            step: 1
            value: HyprlandSettings.num("decoration.blur.size", 8)
            onMoved: v => page.setInt("decoration.blur.size", v)
        }

        SettingStepper {
            icon: "layers"
            label: "Blur passes"
            from: 1
            to: 8
            step: 1
            value: HyprlandSettings.num("decoration.blur.passes", 1)
            onMoved: v => page.setInt("decoration.blur.passes", v)
        }

        SettingToggle {
            icon: "shadow"
            label: "Shadows"
            checked: HyprlandSettings.bool("decoration.shadow.enabled")
            onToggled: page.flip("decoration.shadow.enabled")
        }

        SettingToggle {
            icon: "brightness_medium"
            label: "Dim other windows"
            checked: HyprlandSettings.bool("decoration.dim_inactive")
            onToggled: page.flip("decoration.dim_inactive")
        }

        SettingToggle {
            icon: "open_in_full"
            label: "Resize on border"
            detail: HyprlandSettings.bool("general.resize_on_border") ? "Drag a window's edge" : "OFF"
            checked: HyprlandSettings.bool("general.resize_on_border")
            onToggled: page.flip("general.resize_on_border")
        }

        SettingToggle {
            icon: "layers_clear"
            label: "Window swallowing"
            detail: HyprlandSettings.bool("misc.enable_swallow") ? "Terminals swallow apps" : "OFF"
            checked: HyprlandSettings.bool("misc.enable_swallow")
            onToggled: page.flip("misc.enable_swallow")
        }
    }

    SectionCard {
        title: "Animations"

        SettingToggle {
            icon: "animation"
            label: "Animations"
            checked: HyprlandSettings.bool("animations.enabled")
            onToggled: page.flip("animations.enabled")
        }

        SettingToggle {
            icon: "aspect_ratio"
            label: "Animate resizing"
            checked: HyprlandSettings.bool("misc.animate_manual_resizes")
            onToggled: page.flip("misc.animate_manual_resizes")
        }

        SettingToggle {
            icon: "hide_image"
            label: "Hide the logo"
            checked: HyprlandSettings.bool("misc.disable_hyprland_logo")
            onToggled: page.flip("misc.disable_hyprland_logo")
        }
    }

    SectionCard {
        title: "Workspaces & layout"

        SettingChoice {
            label: "Workspace switch"
            current: HyprlandSettings.str("animation.workspaces", "slide")
            options: [
                { id: "slide", label: "Sideways", icon: "swap_horiz" },
                { id: "slidevert", label: "Vertical (niri)", icon: "swap_vert" },
                { id: "slidefadevert", label: "Vertical + fade", icon: "vertical_align_center" },
                { id: "fade", label: "Fade", icon: "blur_on" }
            ]
            onPicked: id => HyprlandSettings.set("animation.workspaces", "anim", id)
        }

        SettingChoice {
            label: "Tiling layout"
            current: HyprlandSettings.str("general.layout", "dwindle")
            options: [
                { id: "dwindle", label: "Dwindle", icon: "splitscreen" },
                { id: "master", label: "Master", icon: "view_sidebar" },
                { id: "scrolling", label: "Scrolling (niri)", icon: "view_column" }
            ]
            onPicked: id => HyprlandSettings.set("general.layout", "str", id)
        }

        SettingToggle {
            icon: "swap_horiz"
            label: "Back and forth"
            detail: HyprlandSettings.bool("binds.workspace_back_and_forth") ? "Same key returns" : "OFF"
            checked: HyprlandSettings.bool("binds.workspace_back_and_forth")
            onToggled: page.flip("binds.workspace_back_and_forth")
        }

        SettingToggle {
            icon: "cached"
            label: "Cycle workspaces"
            checked: HyprlandSettings.bool("binds.allow_workspace_cycles")
            onToggled: page.flip("binds.allow_workspace_cycles")
        }

        SettingToggle {
            icon: "close_fullscreen"
            label: "Scratchpad"
            detail: HyprlandSettings.bool("misc.close_special_on_empty") ? "Closes when empty" : "OFF"
            checked: HyprlandSettings.bool("misc.close_special_on_empty")
            onToggled: page.flip("misc.close_special_on_empty")
        }

        SettingToggle {
            icon: "call_split"
            label: "Keep split direction"
            checked: HyprlandSettings.bool("dwindle.preserve_split")
            onToggled: page.flip("dwindle.preserve_split")
        }

        SettingToggle {
            icon: "center_focus_strong"
            label: "Focus on activate"
            detail: HyprlandSettings.bool("misc.focus_on_activate") ? "Jump to the app" : "OFF"
            checked: HyprlandSettings.bool("misc.focus_on_activate")
            onToggled: page.flip("misc.focus_on_activate")
        }
    }

    // The niri-style layout: windows are columns on a strip that scrolls sideways
    // (Hyprland's own `scrolling` layout, Hyprland 0.48 or newer).
    SectionCard {
        visible: HyprlandSettings.str("general.layout", "dwindle") === "scrolling"
        height: visible ? implicitHeight : 0
        title: "Scrolling layout (niri-style)"

        SettingSlider {
            width: page.halfWidth
            icon: "view_column"
            label: "New column width"
            from: 0.2
            to: 1
            step: 0.05
            decimals: 2
            value: HyprlandSettings.num("scrolling.column_width", 0.5)
            onMoved: v => page.setFloat("scrolling.column_width", v)
        }

        SettingChoice {
            label: "Focused column"
            current: String(HyprlandSettings.num("scrolling.focus_fit_method"))
            options: [
                { id: "0", label: "Centre it", icon: "align_horizontal_center" },
                { id: "1", label: "Just fit it", icon: "fit_screen" }
            ]
            onPicked: id => page.setInt("scrolling.focus_fit_method", Number(id))
        }

        SettingChoice {
            label: "Strip scrolls"
            current: HyprlandSettings.str("scrolling.direction", "right")
            options: [
                { id: "right", label: "Rightwards", icon: "east" },
                { id: "left", label: "Leftwards", icon: "west" },
                { id: "down", label: "Downwards", icon: "south" },
                { id: "up", label: "Upwards", icon: "north" }
            ]
            onPicked: id => HyprlandSettings.set("scrolling.direction", "str", id)
        }

        SettingToggle {
            icon: "center_focus_weak"
            label: "Follow focus"
            detail: HyprlandSettings.bool("scrolling.follow_focus") ? "Strip scrolls to it" : "OFF"
            checked: HyprlandSettings.bool("scrolling.follow_focus")
            onToggled: page.flip("scrolling.follow_focus")
        }

        SettingToggle {
            icon: "fullscreen"
            label: "Fullscreen when alone"
            detail: HyprlandSettings.bool("scrolling.fullscreen_on_one_column") ? "One column fills the screen" : "OFF"
            checked: HyprlandSettings.bool("scrolling.fullscreen_on_one_column")
            onToggled: page.flip("scrolling.fullscreen_on_one_column")
        }
    }

    // Which overview the overview key opens: this shell's cork board, or the
    // ScrollOverview Hyprland plugin (niri-style, drawn by the compositor).
    SectionCard {
        id: overviewCard
        title: "Overview"
        icon: "view_column"

        readonly property bool scroll: SettingsService.get("overview.style") === "scroll"
        readonly property bool pluginUp: ScrollOverviewService.available
        readonly property string installLine: "hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git && hyprpm update && hyprpm enable scrolloverview"

        // The plugin may have been installed since the panel was built.
        QtObject {
            Component.onCompleted: ScrollOverviewService.recheck()
        }

        SettingChoice {
            label: "Overview style"
            sublabel: "What your overview key opens"
            current: SettingsService.get("overview.style")
            options: [
                { id: "board", label: "Cork board", icon: "dashboard" },
                { id: "scroll", label: "Scroll (niri)", icon: "view_column" }
            ]
            onPicked: id => SettingsService.set("overview.style", id)
        }

        // The cork board only (the Scroll overview draws its own strip).
        SettingChoice {
            visible: !overviewCard.scroll
            label: "Board position"
            sublabel: "Which side of the screen the cork board sits on"
            current: SettingsService.get("overview.position")
            options: [
                { id: "left", label: "Left", icon: "align_horizontal_left" },
                { id: "center", label: "Center", icon: "align_horizontal_center" },
                { id: "right", label: "Right", icon: "align_horizontal_right" }
            ]
            onPicked: id => SettingsService.set("overview.position", id)
        }

        SettingSlider {
            visible: !overviewCard.scroll
            width: page.halfWidth
            icon: "grid_view"
            label: "Workspaces shown"
            from: 1
            to: 10
            step: 1
            value: SettingsService.get("overview.workspaces")
            onMoved: v => SettingsService.set("overview.workspaces", Math.round(v))
        }

        Text {
            visible: overviewCard.scroll
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: overviewCard.pluginUp
                ? "The ScrollOverview plugin is loaded. Your overview key (ipc call overview toggle) opens it now."
                : (ScrollOverviewService.loading
                   ? "Loading the ScrollOverview plugin (hyprpm reload)..."
                   : "The ScrollOverview plugin is not loaded in Hyprland (the shell already tried hyprpm reload), so your overview key opens the cork board for now. Install and enable it once, then press Check again:")
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }

        Text {
            visible: overviewCard.scroll && !overviewCard.pluginUp && ScrollOverviewService.loadLog !== ""
            width: page.fullWidth
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
            text: "hyprpm said: " + ScrollOverviewService.loadLog
            color: Theme.pInk
            opacity: 0.7
            font.family: "monospace"
            font.pixelSize: 13
        }

        Rectangle {
            visible: overviewCard.scroll && !overviewCard.pluginUp
            width: page.fullWidth
            height: installText.implicitHeight + 22
            radius: 18
            color: Theme.pSurfaceDivider
            antialiasing: true

            Text {
                id: installText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                wrapMode: Text.WrapAnywhere
                text: overviewCard.installLine
                color: Theme.pInk
                font.family: "monospace"
                font.pixelSize: 14
            }
        }

        SettingAction {
            visible: overviewCard.scroll && !overviewCard.pluginUp
            tileWidth: 310
            icon: "content_copy"
            label: "Copy the commands"
            detail: "Uses wl-copy"
            onActivated: Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", overviewCard.installLine])
        }

        SettingAction {
            visible: overviewCard.scroll
            tileWidth: 310
            icon: "refresh"
            label: "Check again"
            detail: overviewCard.pluginUp ? "Plugin found"
                    : (ScrollOverviewService.loading ? "Loading it..." : "Plugin not found; tries hyprpm reload")
            onActivated: ScrollOverviewService.recheck()
        }

        // The plugin's own options, only while it is there to take them. Kept
        // in the shell's settings and applied live (ScrollOverviewService).
        SettingChoice {
            visible: overviewCard.scroll && overviewCard.pluginUp
            label: "Workspaces stack"
            current: ScrollOverviewService.optionValue("layout")
            options: [
                { id: "vertical", label: "Vertically", icon: "swap_vert" },
                { id: "horizontal", label: "Sideways", icon: "swap_horiz" }
            ]
            onPicked: id => ScrollOverviewService.setOption("layout", id)
        }

        SettingSlider {
            visible: overviewCard.scroll && overviewCard.pluginUp
            width: page.halfWidth
            icon: "zoom_out_map"
            label: "Zoom out"
            from: 0.1
            to: 0.9
            step: 0.05
            decimals: 2
            value: ScrollOverviewService.optionValue("scale")
            onMoved: v => ScrollOverviewService.setOption("scale", v)
        }

        SettingSlider {
            visible: overviewCard.scroll && overviewCard.pluginUp
            width: page.halfWidth
            icon: "space_bar"
            label: "Gap between workspaces"
            from: 0
            to: 300
            step: 10
            suffix: " px"
            value: ScrollOverviewService.optionValue("gap")
            onMoved: v => ScrollOverviewService.setOption("gap", v)
        }
    }

    SectionCard {
        title: "Input & display"

        SettingChoice {
            label: "Focus follows mouse"
            current: String(HyprlandSettings.num("input.follow_mouse"))
            options: [
                { id: "0", label: "Click to focus", icon: "ads_click" },
                { id: "1", label: "Always", icon: "mouse" },
                { id: "2", label: "Cursor stays free", icon: "pan_tool" }
            ]
            onPicked: id => page.setInt("input.follow_mouse", Number(id))
        }

        SettingChoice {
            label: "Variable refresh"
            current: String(HyprlandSettings.num("misc.vrr"))
            options: [
                { id: "0", label: "Off", icon: "block" },
                { id: "1", label: "On", icon: "speed" },
                { id: "2", label: "Fullscreen only", icon: "fullscreen" }
            ]
            onPicked: id => page.setInt("misc.vrr", Number(id))
        }

        SettingToggle {
            icon: "swipe_vertical"
            label: "Natural scroll"
            detail: HyprlandSettings.bool("input.touchpad.natural_scroll") ? "Touchpad" : "OFF"
            checked: HyprlandSettings.bool("input.touchpad.natural_scroll")
            onToggled: page.flip("input.touchpad.natural_scroll")
        }

        SettingToggle {
            icon: "touch_app"
            label: "Tap to click"
            detail: HyprlandSettings.bool("input.touchpad.tap-to-click") ? "Touchpad" : "OFF"
            checked: HyprlandSettings.bool("input.touchpad.tap-to-click")
            onToggled: page.flip("input.touchpad.tap-to-click")
        }

        SettingToggle {
            icon: "keyboard_alt"
            label: "Pause while typing"
            detail: HyprlandSettings.bool("input.touchpad.disable_while_typing") ? "Touchpad" : "OFF"
            checked: HyprlandSettings.bool("input.touchpad.disable_while_typing")
            onToggled: page.flip("input.touchpad.disable_while_typing")
        }

        SettingToggle {
            icon: "123"
            label: "Num Lock on"
            checked: HyprlandSettings.bool("input.numlock_by_default")
            onToggled: page.flip("input.numlock_by_default")
        }

        SettingStepper {
            icon: "keyboard"
            label: "Key rate"
            from: 5
            to: 80
            step: 1
            suffix: " /s"
            value: HyprlandSettings.num("input.repeat_rate", 25)
            onMoved: v => page.setInt("input.repeat_rate", v)
        }

        SettingStepper {
            icon: "timer"
            label: "Key delay"
            from: 100
            to: 1000
            step: 25
            suffix: " ms"
            value: HyprlandSettings.num("input.repeat_delay", 600)
            onMoved: v => page.setInt("input.repeat_delay", v)
        }

        SettingToggle {
            icon: "monitor"
            label: "Mouse wakes screen"
            checked: HyprlandSettings.bool("misc.mouse_move_enables_dpms")
            onToggled: page.flip("misc.mouse_move_enables_dpms")
        }

        SettingToggle {
            icon: "keyboard"
            label: "Keys wake screen"
            checked: HyprlandSettings.bool("misc.key_press_enables_dpms")
            onToggled: page.flip("misc.key_press_enables_dpms")
        }
    }

    SectionCard {
        title: "Hyprland"

        SettingAction {
            icon: "refresh"
            label: "Reload Hyprland"
            detail: "hyprctl reload"
            onActivated: Quickshell.execDetached(["hyprctl", "reload"])
        }

        SettingAction {
            icon: "restart_alt"
            label: "Drop my changes"
            detail: "Back to hyprland.lua"
            onActivated: HyprlandSettings.resetAll()
        }
    }
}
