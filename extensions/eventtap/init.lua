--- === hs.eventtap ===
---
--- For tapping into input events (mouse, keyboard, trackpad) for observation and possibly overriding them. This module requires `hs.eventtap.event`.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

--- === hs.eventtap.event ===
---
--- Functionality to inspect, modify, and create events for `hs.eventtap` is provided by this module.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.eventtap.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.event = require("hs.eventtap.event")

if not hs.keycodes then hs.keycodes = require("hs.keycodes") end

-- Return Module Object --------------------------------------------------

return module
