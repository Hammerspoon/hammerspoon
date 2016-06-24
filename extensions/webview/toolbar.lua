
--- === hs.webview.toolbar ===
---
--- Create and manipulate toolbars which can be attached to the Hammerspoon console or hs.webview objects.
---
--- Toolbars are attached to titled windows and provide buttons which can be used to perform various actions within the application.  Hammerspoon can use this module to add toolbars to the console or `hs.webview` objects which have a title bar (see `hs.webview.windowMasks` and `hs.webview:windowStyle`).  Toolbars are identified by a unique identifier which is used by OS X to identify information which can be auto saved in the application's user defaults to reflect changes the user has made to the toolbar button order or active button list (this requires setting [hs.webview.toolbar:autosaves](#autosaves) and [hs.webview.toolbar:canCustomize](#canCustomize) both to true).
---
--- Multiple copies of the same toolbar can be made with the [hs.webview.toolbar:copy](#copy) method so that multiple webview windows use the same toolbar, for example.  If the user customizes a copied toolbar, changes to the active buttons or their order will be reflected in all copies of the toolbar.
---
--- Example:
--- ~~~lua
--- t = require("hs.webview.toolbar")
--- a = t.new("myConsole", {
---         { id = "select1", selectable = true, image = hs.image.imageFromName("NSStatusAvailable") },
---         { id = "NSToolbarSpaceItem" },
---         { id = "select2", selectable = true, image = hs.image.imageFromName("NSStatusUnavailable") },
---         { id = "notShown", default = false, image = hs.image.imageFromName("NSBonjour") },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "navGroup", label = "Navigation", groupMembers = { "navLeft", "navRight" }},
---         { id = "navLeft", image = hs.image.imageFromName("NSGoLeftTemplate"), allowedAlone = false },
---         { id = "navRight", image = hs.image.imageFromName("NSGoRightTemplate"), allowedAlone = false },
---         { id = "NSToolbarFlexibleSpaceItem" },
---         { id = "cust", label = "customize", fn = function(t, w, i) t:customizePanel() end, image = hs.image.imageFromName("NSAdvanced") }
---     }):canCustomize(true)
---       :autosaves(true)
---       :selectedItem("select2")
---       :setCallback(function(...)
---                         print("a", inspect(table.pack(...)))
---                    end)
---
--- t.attachToolbar(a)
--- ~~~
---
--- Note: This module is supported in OS X versions prior to 10.10 (for the Hammerspoon console only), even though its parent `hs.webview` is not.  To load this module directly, use `require("hs.webview.toolbar")` instead of relying on module auto-loading.

local USERDATA_TAG = "hs.webview.toolbar"
local module       = require(USERDATA_TAG.."_internal")
local toolbarMT    = hs.getObjectMetatable(USERDATA_TAG)

-- required for image support
require("hs.image")

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

module.systemToolbarItems = _makeConstantsTable(module.systemToolbarItems)
module.itemPriorities     = _makeConstantsTable(module.itemPriorities)

toolbarMT.addItems = function(self, ...)
    local args = table.pack(...)
    if args.n == 1 then
        if #args[1] > 1 then -- it's already a table of tables
            args = args[1]
        end
    end
    args.n = nil
    return self:_addItems(args)
end

-- Return Module Object --------------------------------------------------

return module
