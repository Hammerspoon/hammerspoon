--- === hs.pasteboard ===
---
--- Inspect/manipulate pasteboards (more commonly called clipboards). Both the system default pasteboard and custom named pasteboards can be interacted with.
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.pasteboard.internal")

-- make sure the convertors for types we can recognize are loaded
require("hs.image")
require("hs.sound")
require("hs.styledtext")
require("hs.drawing.color")

-- private variables and methods -----------------------------------------

-- local _kMetaTable = {}
-- -- planning to experiment with using this with responses to functional queries... and I
-- -- don't want to keep loose generated data hanging around
-- _kMetaTable._k = setmetatable({}, {__mode = "k"})
-- _kMetaTable._t = setmetatable({}, {__mode = "k"})
-- _kMetaTable.__index = function(obj, key)
--         if _kMetaTable._k[obj] then
--             if _kMetaTable._k[obj][key] then
--                 return _kMetaTable._k[obj][key]
--             else
--                 for k,v in pairs(_kMetaTable._k[obj]) do
--                     if v == key then return k end
--                 end
--             end
--         end
--         return nil
--     end
-- _kMetaTable.__newindex = function(obj, key, value)
--         error("attempt to modify a table of constants",2)
--         return nil
--     end
-- _kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
-- _kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
-- _kMetaTable.__tostring = function(obj)
--         local result = ""
--         if _kMetaTable._k[obj] then
--             local width = 0
--             for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
--             for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
--                 if _kMetaTable._t[obj] == "table" then
--                     result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
--                         ((type(v) == "table") and "{ table }" or tostring(v)))
--                 else
--                     result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
--                 end
--             end
--         else
--             result = "constants table missing"
--         end
--         return result
--     end
-- _kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this
--
-- local _makeConstantsTable
-- _makeConstantsTable = function(theTable)
--     if type(theTable) ~= "table" then
--         local dbg = debug.getinfo(2)
--         local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
--         if module.log then module.log.ef(msg) else print(msg) end
--         return theTable
--     end
--     for k,v in pairs(theTable) do
--         if type(v) == "table" then
--             local count = 0
--             for a,b in pairs(v) do count = count + 1 end
--             local results = _makeConstantsTable(v)
--             if #v > 0 and #v == count then
--                 _kMetaTable._t[results] = "array"
--             else
--                 _kMetaTable._t[results] = "table"
--             end
--             theTable[k] = results
--         end
--     end
--     local results = setmetatable({}, _kMetaTable)
--     _kMetaTable._k[results] = theTable
--     local count = 0
--     for a,b in pairs(theTable) do count = count + 1 end
--     if #theTable > 0 and #theTable == count then
--         _kMetaTable._t[results] = "array"
--     else
--         _kMetaTable._t[results] = "table"
--     end
--     return results
-- end

-- Public interface ------------------------------------------------------

-- module.types = _makeConstantsTable(module.types)
-- module.names = _makeConstantsTable(module.names)

-- Return Module Object --------------------------------------------------

return module
