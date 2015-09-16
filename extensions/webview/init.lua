--- === hs.webview ===
---
--- Display web content in a window from Hammerspoon
---
--- This module uses Apple's WebKit WKWebView class to provide web content display with JavaScript injection support.  The objective is to provide a functional interface to the WKWebView and WKUserContentController classes.
---
--- This module is not intended to replace a full web browser and does have some limitations to keep in mind:
---   * Self-signed SSL certificates are not accepted unless they have first been approved and included in the users Keychain by another method, for example, opening the page first in Safari.
---   * The context-menu (right clicking or ctrl-clicking in the webview) provides some menu items which are currently unsupported -- a known example of this is any "Download..." menu item in the context menu for links and images.
---   * It is uncertain at present exactly how or where cookies and cached page data is stored or how it can be invalidated.
---     * This can be mitigated to an extent for web requests by using `hs.webview:reload(true)` and by crafting the url for `hs.webview:url({...})` as a table -- see the appropriate help entries for more information.
---
--- Any suggestions or updates to the code to address any of these or other limitations as they may become apparent are welcome at the Hammerspoon github site: https://www.github.com/Hammerspoon/hammerspoon
---

--- === hs.webview.usercontent ===
---
--- This module provides support for injecting custom JavaScript user content into your webviews and for JavaScript to post messages back to Hammerspoon.

local module       = require("hs.webview.internal")
module.usercontent = require("hs.webview.usercontent") ;
local http         = require("hs.http")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
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
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    return results
end

local internalObject = hs.getObjectMetatable("hs.webview")

-- Public interface ------------------------------------------------------

module.windowMasks = _makeConstantsTable(module.windowMasks)

--- hs.webview:windowStyle(mask) -> webviewObject | currentMask
--- Method
--- Get or set the window display style
---
--- Parameters:
---  * mask - if present, this mask should be a combination of values found in `hs.webview.windowMasks` describing the window style.  The mask should be provided as one of the following:
---    * integer - a number representing the style which can be created by combining values found in `hs.webview.windowMasks` with the logical or operator.
---    * string  - a single key from `hs.webview.windowMasks` which will be toggled in the current window style.
---    * table   - a list of keys from `hs.webview.windowMasks` which will be combined to make the final style by combining their values with the logical or operator.
---
--- Returns:
---  * if a mask is provided, then the webviewObject is returned; otherwise the current mask value is returned.
internalObject.windowStyle = function(self, ...)
    local arg = table.pack(...)
    local theMask = internalObject._windowStyle(self)

    if arg.n ~= 0 then
        if type(arg[1]) == "number" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if module.windowMasks[arg[1]] then
                theMask = theMask | module.windowMasks[arg[1]]
            else
                return error("unrecognized style specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theMask = 0
            for i,v in ipairs(arg[1]) do
                if module.windowMasks[v] then
                    theMask = theMask | module.windowMasks[v]
                else
                    return error("unrecognized style specified: "..v)
                end
            end
        else
            return error("invalid type: number, string, or table expected, got "..type(arg[1]))
        end
        return internalObject._windowStyle(self, theMask)
    else
        return theMask
    end
end

--- hs.webview:allowGestures([value]) -> webviewObject | current value
--- Method
--- Get or set whether or not the webview will respond to gestures from a trackpad or magic mouse.  Default is false.
---
--- Parameters:
---  * value - an optional boolean value indicating whether or not the webview should respond gestures.
---
--- Returns:
---  * If a value is provided, then this method returns the webview object; otherwise the current value
---
--- Notes:
---  * This is a shorthand method for getting or setting both `hs.webview:allowMagnificationGestures` and `hs.webview:allowNavigationGestures`.
---  * This method will set both types of gestures to true or false, if given an argument, but will only return true if *both* gesture types are currently true; if either or both gesture methods are false, then this method will return false.
internalObject.allowGestures = function(self, ...)
    local r = table.pack(...)
    if r.n ~= 0 then
        self:allowMagnificationGestures(...)
        self:allowNavigationGestures(...)
        return self
    end
    return self:allowMagnificationGestures() and self:allowNavigationGestures()
end

--- hs.webview:delete([propagate])
--- Method
--- Destroys the webview object and optionally all of its children.
---
--- Parameters:
---  * propagate - an optional boolean, default false, which indicates whether or not the child windows of this webview should also be deleted.
---
--- Returns:
---  * None
---
--- Notes:
---  * This method is automatically called during garbage collection, when Hammerspoon quits, and when its configuration is reloaded.
internalObject.delete = function(self, propagate)
    if propagate then
        for i,v in ipairs(self:children()) do
            internalObject.delete(v, propagate)
        end
    end

    return internalObject._delete(self)
end

--- hs.webview:urlParts() -> table
--- Method
--- Returns a table of keys containing the individual components of the URL for the webview.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the keys for the webview's URL.  See the function `hs.http.urlParts` for a description of the possible keys returned in the table.
---
--- Notes:
---  * This method is a wrapper to the `hs.http.urlParts` function
internalObject.urlParts = function(self)
    return http.urlParts(self)
end

-- Return Module Object --------------------------------------------------

return module
