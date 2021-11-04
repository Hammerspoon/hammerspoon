--- === hs.wifi ===
---
--- Inspect WiFi networks

local USERDATA_TAG = "hs.wifi"
local module       = require("hs.libwifi")
module.watcher     = require("hs.libwifiwatcher")

local watcherMT = hs.getObjectMetatable(USERDATA_TAG..".watcher")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local originalEventTypes  = module.watcher.eventTypes
module.watcher.eventTypes = ls.makeConstantsTable(originalEventTypes)

local originalWatchingFor = watcherMT.watchingFor
watcherMT.watchingFor = function(self, ...)
    local args = table.pack(...)
--     print(args[1])
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        return originalWatchingFor(self, ...)
    elseif args.n == 1 and args[1] == "all" then
        return originalWatchingFor(self, originalEventTypes)
    else
        args.n = nil
        return originalWatchingFor(self, args)
    end
end

-- Return Module Object --------------------------------------------------

return module
