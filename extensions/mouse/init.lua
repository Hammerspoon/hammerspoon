--- === hs.mouse ===
---
--- Inspect/manipulate the position of the mouse pointer
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.mouse.internal")

-- private variables and methods -----------------------------------------

local check_list = {}

-- Public interface ------------------------------------------------------

--- hs.mouse.getCurrentScreen() -> screen
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
    return hs.fnutils.find(hs.screen.allScreens(), function(screen) return isPointInRect(point, screen:fullFrame()) end)
end

-- Return Module Object --------------------------------------------------

return module



