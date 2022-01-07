--- === hs.image ===
---
--- A module for capturing and manipulating image objects from other modules for use with hs.drawing.
---

local module = require("hs.libimage")
local objectMT = hs.getObjectMetatable("hs.image")

require("hs.drawing.color") -- make sure that the conversion helpers required to support color are loaded

-- local __tostring_for_arrays = function(self)
--     local result = ""
--     for i,v in fnutils.sortByKeyValues(self) do
--         result = result..v.."\n"
--     end
--     return result
-- end
--
-- local __tostring_for_tables = function(self)
--     local result = ""
--     local width = 0
--     for i,v in fnutils.sortByKeys(self) do
--         if type(i) == "string" and width < i:len() then width = i:len() end
--     end
--     for i,v in fnutils.sortByKeys(self) do
--         if type(i) == "string" then
--             result = result..string.format("%-"..tostring(width).."s \"%s\"\n", i, v)
--         end
--     end
--     return result
-- end
--
-- module.systemImageNames = setmetatable(module.systemImageNames, { __tostring = __tostring_for_tables
-- })

module.systemImageNames = ls.makeConstantsTable(module.systemImageNames)
module.additionalImageNames = ls.makeConstantsTable(module.additionalImageNames)

--- hs.image:setName(Name) -> boolean
--- Method
--- Assigns the name assigned to the hs.image object.
---
--- Parameters:
---  * Name - the name to assign to the hs.image object.
---
--- Returns:
---  * Status - a boolean value indicating success (true) or failure (false) when assigning the specified name.
---
--- Notes:
---  * This method is included for backwards compatibility and is considered deprecated.  It is equivalent to `hs.image:name(name) and true or false`.
objectMT.setName = function(self, ...) return self:name(...) and true or false end

--- hs.image:setSize(size [, absolute]) -> object
--- Method
--- Returns a copy of the image resized to the height and width specified in the size table.
---
--- Parameters:
---  * size     - a table with 'h' and 'w' keys specifying the size for the new image.
---  * absolute - an optional boolean specifying whether or not the copied image should be resized to the height and width specified (true), or whether the copied image should be scaled proportionally to fit within the height and width specified (false).  Defaults to false.
---
--- Returns:
---  * a copy of the image object at the new size
---
--- Notes:
---  * This method is included for backwards compatibility and is considered deprecated.  It is equivalent to `hs.image:copy():size(size, [absolute])`.
objectMT.setSize = function(self, ...) return self:copy():size(...) end

return module
