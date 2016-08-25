--- === hs.applescript ===
---
--- Execute AppleScript code
---
--- This module has been replaced by: [hs.osascript.applescript](./hs.osascript.html#applescript)

local module = {}

local osascript = require("hs.osascript")

module.applescript = osascript.applescript

setmetatable(module, { __call = function(_, ...) return module.applescript(...) end })

return module
