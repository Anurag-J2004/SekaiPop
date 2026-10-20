// Most QML files read their colours and sizes through `mt`, their monitor's theme
// (`readonly property var mt: Theme.of(...)`, see modules/common/Theme.qml), not through
// the `Theme` singleton itself. Source checks written as "uses Theme.capShade" mean the
// same thing either way, so they read the file through this: every `mt.` is `Theme.`.
//
//   const themeText = require("../lib/themetext")
//   const src = themeText(fs.readFileSync(file, "utf8"))
module.exports = src => String(src).replace(/(?<![\w.])mt\./g, "Theme.")
