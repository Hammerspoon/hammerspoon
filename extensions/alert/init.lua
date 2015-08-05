local module = require("hs.libalert")

setmetatable(module, { __call = function(_, ...) return module.show(...) end })

return module
