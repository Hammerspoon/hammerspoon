--- === hs.console ===
---
--- Some functions for manipulating the Hammerspoon console.
---
--- These functions allow altering the behavior and display of the Hammerspoon console.  They should be considered experimental, but have worked well for me.

-- make sure NSColor conversion tools are installed
require("hs.drawing.color")

require("hs.styledtext")

local module = require("hs.console.internal")

-- private variables and methods -----------------------------------------

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

-- Return Module Object --------------------------------------------------

return module
