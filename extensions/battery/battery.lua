--- === hs.battery ===
---
--- Battery/power information
--- All functions here may return nil, if the information requested is not available.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


local module = require("hs.libbattery")
local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

local check_list = {}
for i,v in pairs(module) do
    if type(v) == "function" then
        check_list[#check_list + 1] = i
    end
end

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,_ in fnutils.sortByKeys(self) do
        if type(i) == "string" and width < i:len() then width = i:len() end
    end
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" then
            result = result..string.format("%-"..tostring(width).."s %s\n", i, tostring(v))
        end
    end
    return result
end

-- Public interface ------------------------------------------------------

module.watcher = require("hs.libbatterywatcher")

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

    for _, v in ipairs(check_list) do
        t[v] = module[v]()
        if t[v] == nil then t[v] = "n/a" end
    end

    return setmetatable(t, {__tostring = __tostring_for_tables })
end

-- Return Module Object --------------------------------------------------

return module
