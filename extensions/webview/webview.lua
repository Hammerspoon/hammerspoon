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

local USERDATA_TAG = "hs.webview"

local osVersion = require"hs.host".operatingSystemVersion()
if (osVersion["major"] == 10 and osVersion["minor"] < 10) then
    hs.luaSkinLog.wf("%s is only available on OS X 10.10 or later", USERDATA_TAG)
    -- nil gets interpreted as "nothing" and thus "true" by require...
    return false
end

local module       = require("hs.libwebview")
module.usercontent = require("hs.libwebviewusercontent")
module.toolbar     = require("hs.webview_toolbar")

local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

local http         = require("hs.http")

if (osVersion["major"] == 10 and osVersion["minor"] < 11) then
    local message = USERDATA_TAG .. ".datastore is only available on OS X 10.11 or later"
    module.datastore = setmetatable({}, {
        __index = function(_)
            hs.luaSkinLog.w(message)
            return nil
        end,
        __tostring = function(_) return message end,
    })
else
    module.datastore   = require("hs.libwebviewdatastore")
    objectMT.datastore = module.datastore.fromWebview
end

-- required for image support
require("hs.image")

-- private variables and methods -----------------------------------------

local deprecatedWarningsGiven = {}
local deprecatedWarningCheck = function(oldName, newName)
    if not deprecatedWarningsGiven[oldName] then
        deprecatedWarningsGiven[oldName] = true
        hs.luaSkinLog.wf("%s:%s is deprecated; use %s:%s instead", USERDATA_TAG, oldName, USERDATA_TAG, newName)
    end
end

-- Public interface ------------------------------------------------------

module.windowMasks     = ls.makeConstantsTable(module.windowMasks)
module.certificateOIDs = ls.makeConstantsTable(module.certificateOIDs)

-- allow array-like usage of object to return child webviews
objectMT.__index = function(self, _)
    if objectMT[_] then
        return objectMT[_]
    elseif type(_) == "number" then
        return self:children()[_]
    else
        return nil
    end
end

--- hs.webview.newBrowser(rect, [preferencesTable], [userContentController]) -> webviewObject
--- Constructor
--- Create a webviewObject with some presets common to an interactive web browser.
---
--- Parameters:
---  * `rect`                  - a rectangle specifying where the webviewObject should be displayed.
---  * `preferencesTable`      - an optional table which specifies special settings for the webview object.
---  * `userContentController` - an optional `hs.webview.usercontent` object to provide script injection and JavaScript messaging with Hammerspoon from the webview.
---
--- Returns:
---  * The webview object
---
--- Notes:
---  * The parameters are the same as for [hs.webview.new](#new) -- check there for more details
---  * This constructor is just a short-hand for `hs.webview.new(...):allowTextEntry(true):allowGestures(true):windowStyle(15)`, which specifies a webview with a title bar, title bar buttons (zoom, close, minimize), and allows form entry and gesture support for previous and next pages.
---
--- * See [hs.webview.new](#new) and the following for more details:
---   * [hs.webview:allowGestures](#allowGestures)
---   * [hs.webview:allowTextEntry](#allowTextEntry)
---   * [hs.webview:windowStyle](#windowStyle)
---   * [hs.webview.windowMasks](#windowMasks)
module.newBrowser = function(...)
    return module.new(...):windowStyle(1+2+4+8)
                          :allowTextEntry(true)
                          :allowGestures(true)
end

--- hs.webview:attachedToolbar([toolbar]) -> webviewObject | currentValue
--- Method
--- Get or attach/detach a toolbar to/from the webview.
---
--- Parameters:
---  * `toolbar` - if an `hs.webview.toolbar` object is specified, it will be attached to the webview.  If an explicit nil is specified, the current toolbar will be removed from the webview.
---
--- Returns:
---  * if a toolbarObject or explicit nil is specified, returns the webviewObject; otherwise returns the current toolbarObject or nil, if no toolbar is attached to the webview.
---
--- Notes:
---  * this method is a convenience wrapper for the `hs.webview.toolbar.attachToolbar` function.
---
---  * If the toolbarObject is currently attached to another window when this method is called, it will be detached from the original window and attached to the webview.  If you wish to attach the same toolbar to multiple webviews, see `hs.webview.toolbar:copy`.
objectMT.attachedToolbar = module.toolbar.attachToolbar

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
objectMT.windowStyle = function(self, ...)
    local arg = table.pack(...)
    local theMask = objectMT._windowStyle(self)

    if arg.n ~= 0 then
        if type(arg[1]) == "number" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if module.windowMasks[arg[1]] then
                theMask = theMask ~ module.windowMasks[arg[1]]
            else
                return error("unrecognized style specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theMask = 0
            for _,v in ipairs(arg[1]) do
                if module.windowMasks[v] then
                    theMask = theMask | module.windowMasks[v]
                else
                    return error("unrecognized style specified: "..v)
                end
            end
        else
            return error("invalid type: number, string, or table expected, got "..type(arg[1]))
        end
        return objectMT._windowStyle(self, theMask)
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
objectMT.allowGestures = function(self, ...)
    local r = table.pack(...)
    if r.n ~= 0 then
        self:allowMagnificationGestures(...)
        self:allowNavigationGestures(...)
        return self
    end
    return self:allowMagnificationGestures() and self:allowNavigationGestures()
end

--- hs.webview:delete([propagate], [fadeOutTime]) -> none
--- Method
--- Destroys the webview object, optionally fading it out first (if currently visible).
---
--- Parameters:
---  * `propagate`   - an optional boolean, default false, which indicates whether or not the child windows of this webview should also be deleted.
---  * `fadeOutTime` - an optional number of seconds over which to fade out the webview object. Defaults to zero.
---
--- Returns:
---  * None
---
--- Notes:
---  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload, with a fade time of 0.
objectMT.delete = function(self, propagate, delay)
    if type(propagate) == "number" then
        propagate, delay = nil, propagate
    end
    delay = delay or 0
    if propagate then
        for _,v in ipairs(self:children()) do
            objectMT.delete(v, propagate, delay)
        end
    end

    return objectMT._delete(self, delay)
end

--- hs.webview:frame([rect]) -> webviewObject | currentValue
--- Method
--- Get or set the frame of the webview window.
---
--- Parameters:
---  * rect - An optional rect-table containing the co-ordinates and size the webview window should be moved and set to
---
--- Returns:
---  * If an argument is provided, the webview object; otherwise the current value.
---
--- Notes:
---  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the webview window (keys `x`  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
objectMT.frame = function(obj, ...)
    local args = table.pack(...)

    if args.n == 0 then
        local topLeft = obj:topLeft()
        local size    = obj:size()
        return {
            __luaSkinType = "NSRect",
            x = topLeft.x,
            y = topLeft.y,
            h = size.h,
            w = size.w,
        }
    elseif args.n == 1 and type(args[1]) == "table" then
        obj:size(args[1])
        obj:topLeft(args[1])
        return obj
    elseif args.n > 1 then
        error("frame method expects 0 or 1 arguments", 2)
    else
        error("frame method argument must be a table", 2)
    end
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
---  * This method is a wrapper to the `hs.http.urlParts` function wich uses the OS X APIs, based on RFC 1808.
---  * You may also want to consider the `hs.httpserver.hsminweb.urlParts` function for a version more consistent with RFC 3986.
objectMT.urlParts = function(self)
    return http.urlParts(self)
end

--- hs.webview:asHSWindow() -> hs.window object
--- Deprecated
--- Returns an hs.window object for the webview so that you can use hs.window methods on it.
---
--- This method is identical to [hs.webview:hswindow](#hswindow).  It is included for reasons of backwards compatibility, but use of the new name is recommended for clarity.
objectMT.asHSWindow = function(self, ...)
    deprecatedWarningCheck("asHSWindow", "hswindow")
    return self:hswindow(...)
end

objectMT.__len = function(self) return #self:children() end


--- hs.webview:setLevel(theLevel) -> drawingObject
--- Deprecated
--- Deprecated; you should use [hs.webview:level](#level) instead.
---
--- Parameters:
---  * `theLevel` - the level specified as a number, which can be obtained from `hs.drawing.windowLevels`.
---
--- Returns:
---  * the webview object
---
--- Notes:
---  * see the notes for `hs.drawing.windowLevels`
objectMT.setLevel = function(self, ...)
    deprecatedWarningCheck("setLevel", "level")
    return self:level(...)
end

--- hs.webview:behaviorAsLabels(behaviorTable) -> webviewObject | currentValue
--- Method
--- Get or set the window behavior settings for the webview object using labels defined in `hs.drawing.windowBehaviors`.
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or numbers specifying the desired window behavior for the webview object.
---
--- Returns:
---  * If an argument is provided, the webview object; otherwise the current value.
---
--- Notes:
---  * Window behaviors determine how the webview object is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
objectMT.behaviorAsLabels = function(obj, ...)
    local drawing = require"hs.drawing"
    local args = table.pack(...)

    if args.n == 0 then
        local results = {}
        local behaviorNumber = obj:behavior()

        if behaviorNumber ~= 0 then
            for i, v in pairs(drawing.windowBehaviors) do
                if type(i) == "string" then
                    if (behaviorNumber & v) > 0 then table.insert(results, i) end
                end
            end
        else
            table.insert(results, drawing.windowBehaviors[0])
        end
        return setmetatable(results, { __tostring = function(_)
            table.sort(_)
            return "{ "..table.concat(_, ", ").." }"
        end})
    elseif args.n == 1 and type(args[1]) == "table" then
        local newBehavior = 0
        for _,v in ipairs(args[1]) do
            local flag = tonumber(v) or drawing.windowBehaviors[v]
            if flag then newBehavior = newBehavior | flag end
        end
        return obj:behavior(newBehavior)
    elseif args.n > 1 then
        error("behaviorAsLabels method expects 0 or 1 arguments", 2)
    else
        error("behaviorAsLabels method argument must be a table", 2)
    end
end

--- hs.webview:asHSDrawing() -> hs.drawing object
--- Deprecated
--- Because use of this method can easily lead to a crash, useful methods from `hs.drawing` have been added to the `hs.webview` module itself.  If you believe that a useful method has been overlooked, please submit an issue.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a placeholder object
objectMT.asHSDrawing = setmetatable({}, {
    __call = function(_, obj)
        if not deprecatedWarningsGiven["asHSDrawing"] then
            deprecatedWarningsGiven["asHSDrawing"] = true
            hs.luaSkinLog.wf("%s:asHSDrawing() is deprecated and should not be used.", USERDATA_TAG)
        end
        return setmetatable({}, {
            __index = function(_, func)
                if objectMT[func] then
                    deprecatedWarningCheck("asHSDrawing():" .. func, func)
                    return function (_, ...) return objectMT[func](obj, ...) end
                elseif func:match("^set") then
                    local newFunc = func:match("^set(.*)$")
                    newFunc = newFunc:sub(1,1):lower() .. newFunc:sub(2)
                    if objectMT[newFunc] then
                        deprecatedWarningCheck("asHSDrawing():" .. func, newFunc)
                        return function (_, ...) return objectMT[newFunc](obj, ...) end
                    end
                end
                hs.luaSkinLog.wf("%s:asHSDrawing() is deprecated and the method %s does not currently have a replacement.  If you believer this is an error, please submit an issue.", USERDATA_TAG, func)
                return nil
            end,
        })
    end,
})

-- Return Module Object --------------------------------------------------

return module
