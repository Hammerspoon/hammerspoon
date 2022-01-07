--- === hs.javascript ===
---
--- Execute JavaScript code
---
--- This module has been replaced by: [hs.osascript.javascript](./hs.osascript.html#javascript)

local module = {}

local osascript = require("hs.osascript")

module.javascript = osascript.javascript

setmetatable(module, { __call = function(_, ...) return module.javascript(...) end })

return module
