--- === hs.console ===
---
--- Some functions for manipulating the Hammerspoon console.
---
--- These functions allow altering the behavior and display of the Hammerspoon console.  They should be considered experimental, but have worked well for me.

-- make sure NSColor conversion tools are installed
require("hs.drawing.color")
require("hs.styledtext")

local USERDATA_TAG = "hs.console"

local module = require("hs.libconsole")

-- private variables and methods -----------------------------------------

local deprecatedWarningsGiven = {}
local deprecatedWarningCheck = function(oldName, newName)
    if not deprecatedWarningsGiven[oldName] then
        deprecatedWarningsGiven[oldName] = true
        hs.luaSkinLog.wf("%s.%s is deprecated; use %s.%s instead", USERDATA_TAG, oldName, USERDATA_TAG, newName)
    end
end

-- Public interface ------------------------------------------------------

--- hs.console.clearConsole() -> nil
--- Function
--- Clear the Hammerspoon console output window.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This is equivalent to `hs.console.setConsole()`
module.clearConsole = function()
    module.setConsole()
end

--- hs.console.asHSDrawing() -> hs.drawing object
--- Deprecated
--- Because use of this function can easily lead to a crash, useful methods from `hs.drawing` have been added to the `hs.console` module itself.  If you believe that a useful method has been overlooked, please submit an issue.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a placeholder object
module.asHSDrawing = setmetatable({}, {
    __call = function()
        if not deprecatedWarningsGiven["asHSDrawing"] then
            deprecatedWarningsGiven["asHSDrawing"] = true
            hs.luaSkinLog.wf("%s.asHSDrawing() is deprecated and should not be used.", USERDATA_TAG)
        end
        return setmetatable({}, {
            __index = function(_, func)
                if module[func] then
                    deprecatedWarningCheck("asHSDrawing():" .. func, func)
                    return function (_, ...) return module[func](...) end
                elseif func:match("^set") then
                    local newFunc = func:match("^set(.*)$")
                    newFunc = newFunc:sub(1,1):lower() .. newFunc:sub(2)
                    if module[newFunc] then
                        deprecatedWarningCheck("asHSDrawing():" .. func, newFunc)
                        return function (_, ...) return module[newFunc](...) end
                    end
                end
                hs.luaSkinLog.wf("%s.asHSDrawing() is deprecated and the method %s does not currently have a replacement.  If you believer this is an error, please submit an issue.", USERDATA_TAG, func)
                return nil
            end,
        })
    end,
})

--- hs.console.asHSWindow() -> hs.window object
--- Deprecated
--- Returns an hs.window object for the console so that you can use hs.window methods on it.
---
--- This function is identical to [hs.console.hswindow](#hswindow).  It is included for reasons of backwards compatibility, but use of the new name is recommended for clarity.
module.asHSWindow = function(self, ...)
    deprecatedWarningCheck("asHSWindow", "hswindow")
    return self:hswindow(...)
end

--- hs.console.behaviorAsLabels(behaviorTable) -> currentValue
--- Function
--- Get or set the window behavior settings for the console using labels defined in `hs.drawing.windowBehaviors`.
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or numbers specifying the desired window behavior for the Hammerspoon console.
---
--- Returns:
---  * the current (possibly new) value.
---
--- Notes:
---  * Window behaviors determine how the console is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
module.behaviorAsLabels = function(...)
    local drawing = require"hs.drawing"
    local args = table.pack(...)

    if args.n == 0 then
        local results = {}
        local behaviorNumber = module.behavior()

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
        return module.behavior(newBehavior)
    elseif args.n > 1 then
        error("behaviorAsLabels method expects 0 or 1 arguments", 2)
    else
        error("behaviorAsLabels method argument must be a table", 2)
    end
end


--- hs.console.toolbar([toolbar]) -> toolbarObject | currentValue
--- Method
--- Get or attach/detach a toolbar to/from the Hammerspoon console.
---
--- Parameters:
---  * `toolbar` - if an `hs.webview.toolbar` object is specified, it will be attached to the Hammerspoon console.  If an explicit nil is specified, the current toolbar will be removed from the console.
---
--- Returns:
---  * if a toolbarObject or explicit nil is specified, returns the toolbarObject; otherwise returns the current toolbarObject or nil, if no toolbar is attached to the console.
---
--- Notes:
---  * this method is a convenience wrapper for the `hs.webview.toolbar.attachToolbar` function.
---
---  * If the toolbar is currently attached to another window when this function is called, it will be detached from the original window and attached to the console.

-- webview requires 10.10, but the toolbar portion doesn't, so we attach it this way just in case
module.toolbar = require"hs.webview.toolbar".attachToolbar

-- Return Module Object --------------------------------------------------

return module
