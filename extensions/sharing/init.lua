--- === hs.sharing ===
---
--- Share items with the macOS Sharing Services under the control of Hammerspoon.
---
--- This module will allow you to share Hammerspoon items with registered Sharing Services.  Some of the built-in sharing services include sharing through mail, Facebook, AirDrop, etc.  Other applications can add additional services as well.
---
--- For most sharing services (this has not been tested with all), the user will be prompted with the standard sharing dialog showing what is to be shared and offered a chance to submit or cancel.
---
--- This example prepares an email with a screenshot:
--- ~~~lua
--- mailer = hs.sharing.newShare("com.apple.share.Mail.compose")
--- mailer:subject("Screenshot generated at " .. os.date()):recipients({ "user@address.com" })
--- mailer:shareItems({ [[
---     Add any notes that you wish to add describing the screenshot here and click the Send icon when you are ready to send this
---
--- ]], hs.screen.mainScreen():snapshot() })
--- ~~~
---
--- Common item data types that can be shared with Sharing Services include (but are not necessarily limited to):
---  * basic data types like strings and numbers
---  * hs.image objects
---  * hs.styledtext objects
---  * web sites and other URLs through the use of the [hs.sharing.URL](#URL) function
---  * local files through the use of file URLs created with the [hs.sharing.fileURL](#fileURL) function

local USERDATA_TAG = "hs.sharing"
local module       = require(USERDATA_TAG..".internal")
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

-- private variables and methods -----------------------------------------

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

-- Public interface ------------------------------------------------------

--- hs.sharing.builtinSharingServices[]
--- Constant
--- A table containing the predefined sharing service labels defined by Apple.
---
--- This table contains the default sharing service identifiers as identified by Apple.  Depending upon the software you have installed on your system, not all of the identifiers included here may be available on your computer and other Applications may provide sharing services with identifiers not included here.  You can determine valid identifiers for specific data types by using the [hs.sharing.shareTypesFor](#shareTypesFor) function which will list all identifiers that will work for all of the specified items, even those which do not appear in this table.
module.builtinSharingServices = _makeConstantsTable(module.builtinSharingServices)

--- hs.sharing.fileURL(path) -> table
--- Function
--- Returns a table representing a file URL for the path specified.
---
--- Parameters:
---  * path - a string specifying a path to represent as a file URL.
---
--- Returns:
---  * a table containing the necessary labels for converting the specified path into a URL as required by the macOS APIs.
---
--- Notes:
---  * this function is a wrapper to [hs.sharing.URL](#URL) which sets the second argument to `true` for you.
---  * see [hs.sharing.URL](#URL) for more information about the table format returned by this function.
module.fileURL = function(...)
    -- if we did module.URL(..., true), then only the first argument of ... would be used - any others
    -- would be lost.  In this specific case, it would work correctly, but since this is likely to be
    -- reused, better not introduce a potentially hard to identify bug where arguments disappear.
    local args = table.pack(...)
    table.insert(args, true)
    return module.URL(table.unpack(args))
end

-- wrapper to convert a list of arguments to the shareTypesFor function into the table the function expects
local shareTypesFor = module.shareTypesFor
module.shareTypesFor = function(...)
    local args = table.pack(...)
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        return shareTypesFor(...)
    else
        return shareTypesFor({ ... })
    end
end

-- wrapper to convert a list of arguments to the recipients method into the table the method expects
local recipients = objectMT.recipients
objectMT.recipients = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        return recipients(self, ...)
    else
        return recipients(self, { ... })
    end
end

-- wrapper to convert a list of arguments to the shareItems method into the table the method expects
local shareItems = objectMT.shareItems
objectMT.shareItems = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        return shareItems(self, ...)
    else
        return shareItems(self, { ... })
    end
end

-- wrapper to convert a list of arguments to the canShareItems method into the table the method expects
local canShareItems = objectMT.canShareItems
objectMT.canShareItems = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 or (args.n == 1 and type(args[1]) == "table") then
        return canShareItems(self, ...)
    else
        return canShareItems(self, { ... })
    end
end

-- Return Module Object --------------------------------------------------

return module
