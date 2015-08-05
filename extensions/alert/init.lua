local module = require("hs.alert.internal")

setmetatable(module, { __call = function(_, ...) return module.show(...) end })

return module
