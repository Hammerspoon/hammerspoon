--- === hs.settings ===
---
--- Serialize simple Lua variables across Hammerspoon launches
--- Settings must have a string key and must be made up of serializable Lua objects (string, number, boolean, nil, tables of such, etc.)
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---

local module = require("hs.libsettings")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module



