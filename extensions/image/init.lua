local _kMetaTable = {}
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end



local module    = {
--- === hs.image ===
---
--- A module for capturing and manipulating image objects from other modules for use with hs.drawing.
---
}

local fnutils = require("hs.fnutils")

local module = require("hs.image.internal")
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

module.systemImageNames = _makeConstantsTable(module.systemImageNames)
module.additionalImageNames = _makeConstantsTable(module.additionalImageNames)

return module
