--- === hs.settings ===
---
--- Functions for manipulating user defaults for the Hammerspoon application, allowing for the creation of user-defined settings which persist across Hammerspoon launches and reloads.  Settings must have a string key and must be made up of serializable Lua objects (string, number, boolean, nil, tables of such, etc.)
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---

local module = require("hs.settings.internal-settings")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module



