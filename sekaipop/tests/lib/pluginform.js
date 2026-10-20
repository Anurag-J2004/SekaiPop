// Loads modules/common/functions/PluginForm.js (a QML `.pragma library` file) into node, so
// the tests run the same code the shell does.
const fs = require("fs")
const src = fs.readFileSync(require("./locate")("modules/common/functions/PluginForm.js"), "utf8").replace(".pragma library", "")
const names = ["humanize", "kindOf", "valueText", "row", "form", "changedKeys", "countText", "hasForm", "skipInfo", "secretInfo", "warnText"]
module.exports = new Function("console", src + ";return {" + names.map(n => n + ":" + n).join(",") + "}")(console)
