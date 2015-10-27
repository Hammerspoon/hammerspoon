local module    = {
--- === hs.image ===
---
--- A module for capturing and manipulating image objects from other modules for use with hs.drawing.
---
}

local fnutils = require("hs.fnutils")

local module = require("hs.image.internal")
require("hs.drawing.color") -- make sure that the conversion helpers required to support color are loaded

local __tostring_for_arrays = function(self)
    local result = ""
    for i,v in fnutils.sortByKeyValues(self) do
        result = result..v.."\n"
    end
    return result
end

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" and width < i:len() then width = i:len() end
    end
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" then
            result = result..string.format("%-"..tostring(width).."s \"%s\"\n", i, v)
        end
    end
    return result
end

module.systemImageNames = setmetatable(module.systemImageNames, { __tostring = __tostring_for_tables
})

return module
