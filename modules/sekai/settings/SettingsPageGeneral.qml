import QtQuick
import Quickshell
import qs.services

// General: how the shell behaves, apart from how it looks. Time and units,
// what the Quick Panel and notifications do, the launcher, the lockscreen,
// and the shell itself.
SettingsPage {
    id: page

    SectionCard {
        title: "Time & alerts"

        SettingToggle {
            icon: "schedule"
            label: "24-hour time"
            checked: SettingsService.flag("time.use24h")
            onToggled: {
                const on = !SettingsService.flag("time.use24h")
                SettingsService.set("time.use24h", on)
                // The desktop clock card keeps its own copy of this.
                ClockService.setUse24h(on)
            }
        }

        SettingToggle {
            icon: "thermostat"
            label: "Fahrenheit"
            detail: SettingsService.flag("weather.fahrenheit") ? "°F" : "°C"
            checked: SettingsService.flag("weather.fahrenheit")
            onToggled: SettingsService.toggle("weather.fahrenheit")
        }

        SettingChoice {
            label: "Notification alert"
            sublabel: "Phone: the Quick Panel's phone rises. Popups: a stack of cards in the corner"
            current: SettingsService.get("notify.style")
            options: [
                { id: "phone", label: "Phone", icon: "smartphone" },
                { id: "popups", label: "Popups", icon: "notifications_active" }
            ]
            onPicked: id => SettingsService.set("notify.style", id)
        }

        SettingToggle {
            icon: "vibration"
            label: "Buzz on arrival"
            detail: SettingsService.get("notify.style") === "phone" ? "" : "Phone alert only"
            checked: SettingsService.flag("notify.buzz")
            onToggled: SettingsService.toggle("notify.buzz")
        }

        SettingAction {
            icon: "clear_all"
            label: "Clear all"
            detail: page.host && page.host.notificationSource
                ? (page.host.notificationSource.count === 0 ? "Nothing waiting" : page.host.notificationSource.count + " waiting") : ""
            onActivated: if (page.host && page.host.notificationSource) page.host.notificationSource.clearAll()
        }
    }

    SectionCard {
        title: "Weather"

        SettingText {
            label: "Location"
            sublabel: "A place name or latitude,longitude. Empty: wttr.in guesses from your IP"
            value: SettingsService.get("weather.location")
            placeholder: "automatic (from your IP)"
            onSubmitted: text => SettingsService.set("weather.location", text)
            onCleared: SettingsService.set("weather.location", "")
        }

        SettingChoice {
            label: "Popup shows"
            sublabel: "The row under the details"
            current: SettingsService.get("weather.view")
            options: [
                { id: "days", label: "Next days", icon: "calendar_view_week" },
                { id: "hourly", label: "Hourly", icon: "schedule" }
            ]
            onPicked: id => SettingsService.set("weather.view", id)
        }

    }

    SectionCard {
        title: "Screen region"

        SettingToggle {
            icon: "screenshot_region"
            label: "Own region picker"
            detail: "For the Screenshot and Record keys"
            checked: SettingsService.flag("region.own")
            onToggled: SettingsService.toggle("region.own")
        }

        SettingToggle {
            icon: "preview"
            label: "Preview after a screenshot"
            detail: "A card to annotate, copy or save"
            checked: SettingsService.flag("region.preview")
            onToggled: SettingsService.toggle("region.preview")
        }

        SettingStepper {
            icon: "timer"
            label: "Preview stays"
            from: 2
            to: 20
            step: 1
            suffix: " s"
            value: SettingsService.get("region.previewSeconds")
            onMoved: v => SettingsService.set("region.previewSeconds", v)
        }

        SettingChoice {
            label: "Record with sound"
            sublabel: "Which sound goes in the video"
            current: SettingsService.get("region.audio")
            options: [
                { id: "system", label: "What you hear", icon: "volume_up" },
                { id: "mic", label: "Microphone", icon: "mic" }
            ]
            onPicked: id => SettingsService.set("region.audio", id)
        }

        SettingAction {
            icon: "crop_free"
            label: "Pick a region"
            detail: "Copy, save, text, search, record"
            onActivated: {
                if (page.host) page.host.closeRequested()
                RegionService.showLater("copy")
            }
        }
    }

    SectionCard {
        title: "Quick Panel"

        SettingToggle {
            icon: "swipe_up"
            label: "Hot edge"
            detail: SettingsService.flag("panel.hotEdge") ? "Bottom centre" : "OFF"
            checked: SettingsService.flag("panel.hotEdge")
            onToggled: SettingsService.toggle("panel.hotEdge")
        }

        SettingStepper {
            icon: "timer"
            label: "Edge delay"
            from: 40
            to: 800
            step: 20
            suffix: " ms"
            value: SettingsService.get("panel.hotDwell")
            onMoved: v => SettingsService.set("panel.hotDwell", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "vertical_align_top"
            label: "How much of the phone shows"
            from: 40
            to: 100
            step: 2
            suffix: "%"
            value: SettingsService.get("panel.peek")
            onMoved: v => SettingsService.set("panel.peek", v)
        }

        SettingToggle {
            icon: "keyboard"
            label: "Type to search apps"
            detail: SettingsService.flag("panel.typeToSearch") ? "A letter opens Apps" : "OFF"
            checked: SettingsService.flag("panel.typeToSearch")
            onToggled: SettingsService.toggle("panel.typeToSearch")
        }

        SettingChoice {
            label: "Avatar & banner picker"
            sublabel: "The window that opens when you pick a picture. Auto: KDE's if installed. GTK / system goes through the desktop portal and can be slow"
            current: SettingsService.get("files.chooser")
            options: [
                { id: "auto", label: "Auto", icon: "auto_awesome" },
                { id: "kdialog", label: "KDE", icon: "folder_open" },
                { id: "zenity", label: "GTK / system", icon: "desktop_windows" },
                { id: "yad", label: "yad", icon: "folder" }
            ]
            onPicked: id => SettingsService.set("files.chooser", id)
        }
    }

    SectionCard {
        title: "Launcher & lock"

        SettingToggle {
            icon: "search"
            label: "Web suggestions"
            detail: SettingsService.flag("launcher.webSuggestions") ? "Sent to DuckDuckGo" : "OFF"
            checked: SettingsService.flag("launcher.webSuggestions")
            onToggled: SettingsService.toggle("launcher.webSuggestions")
        }

        SettingToggle {
            icon: "content_paste"
            label: "Clipboard history"
            detail: SettingsService.flag("launcher.clipboard") ? "Recording" : "OFF"
            checked: SettingsService.flag("launcher.clipboard")
            onToggled: SettingsService.toggle("launcher.clipboard")
        }

        SettingToggle {
            icon: "blur_on"
            label: "Blur lock wallpaper"
            checked: SettingsService.flag("lock.blur")
            onToggled: SettingsService.toggle("lock.blur")
        }

        SettingAction {
            icon: "lock"
            label: "Lock now"
            detail: "Lock the screen"
            onActivated: {
                if (page.host)
                    page.host.closeRequested()
                LockState.lock()
            }
        }
    }

    SectionCard {
        title: "Shell"

        SettingAction {
            icon: "refresh"
            label: "Reload shell"
            detail: "Rebuild every window"
            onActivated: Quickshell.reload(true)
        }

        SettingAction {
            icon: "restart_alt"
            label: "Reset settings"
            detail: SettingsService.changedCount === 0 ? "Nothing changed"
                : SettingsService.changedCount + (SettingsService.changedCount === 1 ? " change" : " changes")
            onActivated: SettingsService.reset()
        }
    }
}
