--- === hs.mouse ===
---
--- Inspect/manipulate the position of the mouse pointer
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.mouse.internal")

-- private variables and methods -----------------------------------------

local check_list = {}

-- Public interface ------------------------------------------------------

--- hs.mouse.getAbsolutePosition() -> point
--- Function
--- Gets the absolute co-ordinates of the mouse pointer
---
--- Parameters:
---  * None
---
--- Returns:
---  * A point-table containing the absolute x and y co-ordinates of the mouse pointer
---
--- Notes:
---  * The co-ordinates returned by this function are in relation to the full size of your desktop. If you have multiple monitors, the desktop is a large virtual rectangle that contains them all (e.g. if you have two 1920x1080 monitors and the mouse is in the middle of the second monitor, the returned table would be `{ x=2879, y=540 }`)
---  * Multiple monitors of different sizes can cause the co-ordinates of some areas of the desktop to be negative. This is perfectly normal. 0,0 in the co-ordinates of the desktop is the top left of the primary monitor
function module.getAbsolutePosition()
    return module.get()
end

--- hs.mouse.setAbsolutePosition(point)
--- Function
--- Sets the absolute co-ordinates of the mouse pointer
---
--- Parameters:
---  * point - A point-table containing the absolute x and y co-ordinates to move the mouse pointer to
---
--- Returns:
---  * None
---
--- Notes:
---  * The co-ordinates given to this function must be in relation to the full size of your desktop. See the notes for `hs.mouse.get` for more information
function module.getAbsolutePosition()
    return module.get()
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
    local screen = hs.mouse.getCurrentScreen()
    if screen == nil then
        return nil
    end

    local frame = screen:fullFrame()
    local point = hs.mouse.getAbsolutePosition()
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
function module.setRelativePosition(point, screen)
    if screen == nil then
        screen = hs.mouse.getCurrentScreen()
        if screen == nil then
            print("ERROR: Unable to find the current screen")
            return nil
        end
    end

    local frame = screen:fullFrame()
    local abs = {}

    abs["x"] = frame["x"] + point["x"]
    abs["y"] = frame["y"] + point["y"]

    return module.set(abs)
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
    local point = hs.mouse.get()
    return hs.fnutils.find(hs.screen.allScreens(), function(screen) return hs.geometry.isPointInRect(point, screen:fullFrame()) end)
end

-- Return Module Object --------------------------------------------------

return module



