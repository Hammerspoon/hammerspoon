--- === hs.battery ===
---
--- Functions for getting battery info. All functions here may return nil, if the information requested is not available.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


local module = require("hs.battery.internal")

-- private variables and methods -----------------------------------------

local check_list = {}
for i,v in pairs(module) do check_list[#check_list + 1] = i end

-- Public interface ------------------------------------------------------

module.watcher = require("hs.battery.watcher")

--- hs.battery.getAll() -> table
--- Function
--- Get all available battery information
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing all the information provided by the separate functions in hs.battery
---
--- Notes:
---  * If you require multiple pieces of information about a battery, this function may be more efficient than calling several other functions separately
module.getAll = function()
    local t = {}

    for i, v in ipairs(check_list) do
        t[v] = module[v]()
        if t[v] == nil then t[v] = "n/a" end
    end

    return t
end

-- Return Module Object --------------------------------------------------

return module



