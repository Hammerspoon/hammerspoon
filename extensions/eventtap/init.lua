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

--- hs.eventtap.event.newmouseevent(eventtype, point) -> event
--- Constructor
--- Creates a new mouse event.
---   - eventtype is one of the values in hs.eventtap.event.types
---   - point is a table with keys {x,y}
function module.event.newmouseevent(eventtype, point)
    local types = module.event.types
    local button = nil
    if eventtype == types["leftmousedown"] or eventtype == types["leftmouseup"] or eventtype == types["leftmousedragged"] then
        button = "left"
    elseif eventtype == types["rightmousedown"] or eventtype == types["rightmouseup"] or eventtype == types["rightmousedragged"] then
        button = "right"
    elseif eventtype == types["middlemousedown"] or eventtype == types["middlemouseup"] or eventtype == types["middlemousedragged"] then
        button = "middle"
    else
        print("Error: unrecognised mouse button eventtype: " .. eventtype)
        return nil
    end
    return module.event._newmouseevent(eventtype, point, button)
end

if not hs.keycodes then hs.keycodes = require("hs.keycodes") end

-- Return Module Object --------------------------------------------------

return module
