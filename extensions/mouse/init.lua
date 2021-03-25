--- === hs.mouse ===
---
--- Inspect/manipulate the position of the mouse pointer
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---
--- This module uses ManyMouse by Ryan C. Gordon.
---
--- MANYMOUSE LICENSE:
---
--- Copyright (c) 2005-2012 Ryan C. Gordon and others.
---
--- This software is provided 'as-is', without any express or implied warranty.
--- In no event will the authors be held liable for any damages arising from
--- the use of this software.
---
--- Permission is granted to anyone to use this software for any purpose,
--- including commercial applications, and to alter it and redistribute it
--- freely, subject to the following restrictions:
---
--- 1. The origin of this software must not be misrepresented; you must not
--- claim that you wrote the original software. If you use this software in a
--- product, an acknowledgment in the product documentation would be
--- appreciated but is not required.
---
--- 2. Altered source versions must be plainly marked as such, and must not be
--- misrepresented as being the original software.
---
--- 3. This notice may not be removed or altered from any source distribution.
---
---     Ryan C. Gordon <icculus@icculus.org>

local module = require("hs.mouse.internal")
local fnutils = require("hs.fnutils")
local geometry = require("hs.geometry")
local screen = require("hs.screen")

-- private variables and methods -----------------------------------------

local deprecation_warnings = {}

-- Public interface ------------------------------------------------------

function module.get(...)
    local state = debug.getinfo(2)
    local tag = state.short_src..":"..state.currentline
    if not deprecation_warnings[tag] then
        print(tag..": hs.mouse.get is deprecated.  Please update your code to use hs.mouse.absolutePosition or hs.mouse.getRelativePosition")
        deprecation_warnings[tag] = true
    end
    return module.absolutePosition(...)
end

function module.set(...)
    local state = debug.getinfo(2)
    local tag = state.short_src..":"..state.currentline
    if not deprecation_warnings[tag] then
        print(tag..": hs.mouse.set is deprecated.  Please update your code to use hs.mouse.absolutePosition or hs.mouse.setRelativePosition")
        deprecation_warnings[tag] = true
    end
    return module.absolutePosition(...)
end

function module.getAbsolutePosition(...)
    local state = debug.getinfo(2)
    local tag = state.short_src..":"..state.currentline
    if not deprecation_warnings[tag] then
        print(tag..": hs.mouse.getAbsolutePosition is deprecated.  Please update your code to use hs.mouse.absolutePosition")
        deprecation_warnings[tag] = true
    end
    return module.absolutePosition(...)
end

function module.setAbsolutePosition(...)
    local state = debug.getinfo(2)
    local tag = state.short_src..":"..state.currentline
    if not deprecation_warnings[tag] then
        print(tag..": hs.mouse.setAbsolutePosition is deprecated.  Please update your code to use hs.mouse.absolutePosition")
        deprecation_warnings[tag] = true
    end
    return module.absolutePosition(...)
end

--- hs.mouse.getRelativePosition() -> point or nil
--- Function
--- Gets the co-ordinates of the mouse pointer, relative to the screen it is on
---
--- Parameters:
---  * None
---
--- Returns:
---  * A point-table containing the relative x and y co-ordinates of the mouse pointer, or nil if an error occured
---
--- Notes:
---  * The co-ordinates returned by this function are relative to the top left pixel of the screen the mouse is on (see `hs.mouse.getAbsolutePosition` if you need the location in the full desktop space)
function module.getRelativePosition()
    local currentScreen = module.getCurrentScreen()
    if currentScreen == nil then
        return nil
    end

    local frame = currentScreen:fullFrame()
    local point = module.absolutePosition()
    local rel = {}

    rel["x"] = point["x"] - frame["x"]
    rel["y"] = point["y"] - frame["y"]

    return rel
end

--- hs.mouse.setRelativePosition(point[, screen])
--- Function
--- Sets the co-ordinates of the mouse pointer, relative to a screen
---
--- Parameters:
---  * point - A point-table containing the relative x and y co-ordinates to move the mouse pointer to
---  * screen - An optional `hs.screen` object. Defaults to the screen the mouse pointer is currently on
---
--- Returns:
---  * None
function module.setRelativePosition(point, currentScreen)
    if currentScreen == nil then
        currentScreen = module.getCurrentScreen()
        if currentScreen == nil then
            print("ERROR: Unable to find the current screen")
            return nil
        end
    end

    local frame = currentScreen:fullFrame()
    local abs = {}

    abs["x"] = frame["x"] + point["x"]
    abs["y"] = frame["y"] + point["y"]

    return module.absolutePosition(abs)
end

--- hs.mouse.getCurrentScreen() -> screen or nil
--- Function
--- Gets the screen the mouse pointer is on
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object that the mouse pointer is on, or nil if an error occurred
function module.getCurrentScreen()
    local point = module.absolutePosition()
    return fnutils.find(screen.allScreens(), function(aScreen) return geometry.isPointInRect(point, aScreen:fullFrame()) end)
end

--- hs.mouse.getButtons() -> table
--- Function
--- Returns a table containing the current mouse buttons being pressed *at this instant*.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Returns an array containing indicies starting from 1 up to the highest numbered button currently being pressed where the index is `true` if the button is currently pressed or `false` if it is not.
---  * Special hash tag synonyms for `left` (button 1), `right` (button 2), and `middle` (button 3) are also set to true if these buttons are currently being pressed.
---
--- Notes:
---  * This function is a wrapper to `hs.eventtap.checkMouseButtons`
---  * This is an instantaneous poll of the current mouse buttons, not a callback.
function module.getButtons(...)
    return require("hs.eventtap").checkMouseButtons(...)
end

-- Return Module Object --------------------------------------------------

return module
