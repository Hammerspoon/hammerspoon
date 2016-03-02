--- === hs.javascript ===
---
--- Execute JavaScript code
---
--- Alias for [hs.osascript.javascript](./hs.osascript.html#javascript)

local module = {}

local osascript = require("hs.osascript")

module.javascript = osascript.javascript

setmetatable(module, { __call = function(_, ...) return module.javascript(...) end })

return module
