// Loads modules/common/functions/ShelfDragMath.js (a QML `.pragma library` file) into
// node, so the tests run the same code the shell does.
const fs = require("fs")
const src = fs.readFileSync(require("./locate")("modules/common/functions/ShelfDragMath.js"), "utf8").replace(".pragma library", "")
const names = ["THRESHOLD", "PULL", "PULL_SLOPE", "gesture", "toDesktop", "spotFor", "ghostSize"]
module.exports = new Function(src + ";return {" + names.map(n => n + ":" + n).join(",") + "}")()
