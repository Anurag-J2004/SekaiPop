import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// The system side of the bar's weather pill and its dropdown
// (WeatherPopup.qml) — with MediaSource.qml, ResourceSource.qml,
// BatterySource.qml, one of the small self-contained *Source files each
// Bar.qml instance owns. Uses wttr.in's JSON output (`?format=j1`), which
// auto-detects the location from the machine's public IP — the same
// one-line `curl wttr.in` people already run from a terminal. No API
// key, no separate geocoding step, nothing to configure for the common
// case. One request carries everything the pill and the popup show.
//
//   temperatureText   e.g. "18°C" — "" until the first fetch lands, or if
//                      curl / the network isn't available
//   conditionText     e.g. "Partly cloudy"
//   iconName          the Material Symbols name that matches it
//   feelsLikeText, humidityText, windText, pressureText, visibilityText,
//   uvText, precipText, areaText   the popup's detail rows ("" until known)
//   forecast          [{ label, date, iconName, condition, high, low, rain }]
//                      for today and the next two days
//   sunriseText, sunsetText   today's, as wttr.in writes them ("06:05 AM"; ""
//                      until known): the desktop weather card's dial marks them
//   hourly            [{ label, iconName, condition, temp, rain, feels }] the next
//                      eight three-hour readings (wttr.in's own resolution)
//   updatedText       "Updated 14:05" — when the last fetch landed
//
// Every Bar.qml instance polls its own copy (same reasoning as
// ResourceSource/BatterySource: cheap enough, and simpler than wiring
// shared state across monitors) — but weather barely moves minute to
// minute, so this refreshes far less often than those do. Opening the
// popup asks for a fresh reading when the last one is a few minutes old.
Scope {
    id: root

    // Flip to true for °F. wttr.in returns both units; this picks which
    // one the shell shows.
    // (Settings -> General -> Fahrenheit.)
    property bool useFahrenheit: SettingsService.flag("weather.fahrenheit")

    // The last answer from wttr.in, kept so a change of unit can redraw it
    // at once instead of waiting for the next fetch (up to 15 minutes).
    property var lastData: null

    onUseFahrenheitChanged: {
        if (!root.lastData)
            return
        // apply() also stamps "Updated hh:mm" and the stale-check time;
        // switching units isn't a new reading, so put those back.
        const keepMs = root.lastFetchMs
        const keepText = root.updatedText
        try {
            root.apply(root.lastData)
        } catch (e) {
            return
        }
        root.lastFetchMs = keepMs
        root.updatedText = keepText
    }

    property string temperatureText: ""
    property string conditionText: ""
    property string iconName: "cloud"
    property string feelsLikeText: ""
    property string humidityText: ""
    property string windText: ""
    property string pressureText: ""
    property string visibilityText: ""
    property string uvText: ""
    property string precipText: ""
    property string areaText: ""
    property string sunriseText: ""
    property string sunsetText: ""
    property var forecast: []
    property var hourly: []
    property string updatedText: ""

    // True while a request is in flight; failed is true when the last one
    // didn't produce anything usable (the previous readings stay on show).
    readonly property bool loading: fetch.running
    property bool failed: false
    property double lastFetchMs: 0

    // Where: "" lets wttr.in guess from your IP (the old behaviour); otherwise a
    // place name ("Lisbon", "Springfield, Illinois", "~Eiffel Tower") or
    // "lat,lon" -- typed in Settings -> General -> Weather. wttr.in takes
    // spaces as "+".
    readonly property string location: String(SettingsService.get("weather.location") || "").trim()
    readonly property string url: "https://wttr.in/"
        + (root.location !== "" ? encodeURIComponent(root.location).replace(/%20/g, "+") : "")
        + "?format=j1"

    // A new place: forget what the old one showed and look again.
    onLocationChanged: {
        root.lastData = null
        root.temperatureText = ""
        root.conditionText = ""
        root.areaText = ""
        root.sunriseText = ""
        root.sunsetText = ""
        root.forecast = []
        root.hourly = []
        root.failed = false
        if (fetch.running) {
            // The old place's answer is no use: stop it, and look again for
            // the new one once it has exited (see `onExited` below).
            root.restartPending = true
            fetch.running = false
        } else {
            root.refresh()
        }
    }
    property bool restartPending: false

    function refresh() {
        if (fetch.running)
            return
        fetch.running = true
    }

    // For the popup: only bother wttr.in again if the reading is old.
    function refreshIfStale() {
        if (Date.now() - root.lastFetchMs > 5 * 60 * 1000)
            root.refresh()
    }

    // Material Symbols name for a WWO weather code (what wttr.in reports).
    function iconFor(code, night) {
        const c = parseInt(code, 10)
        if (c === 113)
            return night ? "clear_night" : "sunny"
        if (c === 116)
            return night ? "partly_cloudy_night" : "partly_cloudy_day"
        if ([119, 122].indexOf(c) >= 0)
            return "cloud"
        if ([143, 248, 260].indexOf(c) >= 0)
            return "foggy"
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0)
            return "thunderstorm"
        if ([179, 182, 185, 227, 230, 281, 284, 317, 320, 323, 326, 329, 332, 335,
             338, 350, 362, 365, 368, 371, 374, 377].indexOf(c) >= 0)
            return "weather_snowy"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].indexOf(c) >= 0)
            return "rainy"
        return "cloud"
    }

    function first(arr) {
        return arr && arr.length > 0 && arr[0] ? (arr[0].value || "") : ""
    }

    function pad(n) {
        return ("0" + n).slice(-2)
    }

    function apply(data) {
        const cur = (data.current_condition || [])[0]
        if (!cur)
            throw new Error("no current_condition")

        const f = root.useFahrenheit
        const unit = f ? "°F" : "°C"
        const hour = new Date().getHours()
        const night = hour < 6 || hour >= 18

        // The bar's pill reads better without a "+" (it's "18°C", not
        // "+18°C"); a negative one keeps its "-" naturally.
        root.temperatureText = (f ? cur.temp_F : cur.temp_C) + unit
        root.conditionText = root.first(cur.weatherDesc)
        root.iconName = root.iconFor(cur.weatherCode, night)
        root.feelsLikeText = (f ? cur.FeelsLikeF : cur.FeelsLikeC) + unit
        root.humidityText = cur.humidity + "%"
        root.windText = (f ? cur.windspeedMiles + " mph" : cur.windspeedKmph + " km/h")
            + (cur.winddir16Point ? " " + cur.winddir16Point : "")
        root.pressureText = cur.pressure + " hPa"
        root.visibilityText = f ? cur.visibilityMiles + " mi" : cur.visibility + " km"
        root.uvText = String(cur.uvIndex)
        root.precipText = f ? (parseFloat(cur.precipInches) || 0).toFixed(2) + " in"
                            : (parseFloat(cur.precipMM) || 0).toFixed(1) + " mm"

        const area = (data.nearest_area || [])[0]
        if (area) {
            const name = root.first(area.areaName)
            const country = root.first(area.country)
            root.areaText = name && country ? name + ", " + country : (name || country)
        }

        const days = []
        const w = data.weather || []
        const astro = w.length > 0 ? (w[0].astronomy || [])[0] : null
        root.sunriseText = astro && astro.sunrise ? String(astro.sunrise) : ""
        root.sunsetText = astro && astro.sunset ? String(astro.sunset) : ""
        for (let i = 0; i < Math.min(3, w.length); i++) {
            const d = w[i]
            const hourly = d.hourly || []
            // Midday (index 4 of 8 three-hour slots) stands for the day.
            const mid = hourly[4] || hourly[0] || {}
            let rain = 0
            for (const h of hourly)
                rain = Math.max(rain, parseInt(h.chanceofrain, 10) || 0)
            const dt = new Date(d.date + "T12:00:00")
            days.push({
                label: i === 0 ? "Today" : dt.toLocaleDateString(Qt.locale(), "ddd"),
                date: dt.getDate(),
                iconName: root.iconFor(mid.weatherCode, false),
                condition: root.first(mid.weatherDesc),
                high: (f ? d.maxtempF : d.maxtempC) + "°",
                low: (f ? d.mintempF : d.mintempC) + "°",
                rain: rain
            })
        }
        root.forecast = days

        // The next eight three-hour readings, across the days wttr.in sent.
        // They come as "time": "0", "300" ... "2100" in the place's local time;
        // they are compared with this machine's clock, which is only a few hours
        // off for a far-away place -- fine, since a reading lasts three hours and
        // the list is just "what is coming".
        const nowD = new Date()
        const hours = []
        for (let di = 0; di < Math.min(3, w.length) && hours.length < 8; di++) {
            const d = w[di]
            for (const h of (d.hourly || [])) {
                const hh = Math.floor((parseInt(h.time, 10) || 0) / 100)
                const start = new Date(d.date + "T" + root.pad(hh) + ":00:00")
                // Still going on (it started less than three hours ago) or ahead.
                if (start.getTime() + 3 * 3600 * 1000 <= nowD.getTime())
                    continue
                hours.push({
                    label: root.pad(hh) + ":00",
                    iconName: root.iconFor(h.weatherCode, hh < 6 || hh >= 18),
                    condition: root.first(h.weatherDesc),
                    temp: (f ? h.tempF : h.tempC) + "°",
                    feels: (f ? h.FeelsLikeF : h.FeelsLikeC) + "°",
                    rain: parseInt(h.chanceofrain, 10) || 0
                })
                if (hours.length >= 8)
                    break
            }
        }
        root.hourly = hours

        const now = new Date()
        root.updatedText = "Updated " + root.pad(now.getHours()) + ":" + root.pad(now.getMinutes())
        root.lastFetchMs = now.getTime()
        root.failed = false
    }

    // False stops the 15-minute poll (and starting it again looks straight away).
    // The bar's pill leaves it on; the desktop weather card (WeatherCardWidget.qml)
    // turns it off while the card is not on screen.
    property bool polling: true

    Timer {
        // Weather doesn't move fast enough to poll like CPU/battery —
        // once every 15 minutes is plenty, and kinder to wttr.in.
        interval: 15 * 60 * 1000
        running: root.polling
        repeat: true
        // The first look at start; a poll that is switched back on (the desktop
        // card coming back after Desktop Focus Mode hid it) only looks again if the
        // reading is old (see onPollingChanged), so going back and forth between an
        // app and an empty workspace does not ask wttr.in every time.
        triggeredOnStart: root.lastFetchMs === 0
        onTriggered: root.refresh()
    }

    onPollingChanged: {
        if (root.polling && root.lastFetchMs > 0)
            root.refreshIfStale()
    }

    Process {
        id: fetch
        // -s: quiet (no progress meter). -m 10: give up after 10s rather
        // than hang onto a process if the network's down. A failed
        // fetch, or a missing curl, just leaves the last-known readings
        // in place — empty the very first time.
        command: ["curl", "-s", "-m", "10", root.url]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.apply(data)
                    root.lastData = data
                } catch (e) {
                    // wttr.in sometimes answers with an HTML/plain-text
                    // error page when it's overloaded; keep what we had.
                    root.failed = true
                }
            }
        }
        onExited: (code, status) => {
            if (root.restartPending) {
                root.restartPending = false
                root.failed = false
                root.refresh()
                return
            }
            if (code !== 0)
                root.failed = true
        }
    }
}
