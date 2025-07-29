--- === hs.dockicon ===
---
--- Control Hammerspoon's dock icon
---
--- This module is based primarily on code from the previous incarnation of Mjolnir.

local module = require("hs.libdockicon")
require("hs.canvas") -- loads canvas class support for docktile support

local realSetBadge = module.setBadge
module.setBadge = function(arg)
    if type(arg) == "nil" then arg = "" end
    return realSetBadge(arg)
end

return module



