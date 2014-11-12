--- === hs.eventtap ===
---
--- For tapping into input events (mouse, keyboard, trackpad) for observation and possibly overriding them.
--- It also provides convenience wrappers for sending mouse and keyboard events. If you need to construct finely controlled mouse/keyboard events, see hs.eventtap.event
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

--- === hs.eventtap.event ===
---
--- Functionality to inspect, modify, and create events for `hs.eventtap` is provided by this module.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

if not hs.keycodes then hs.keycodes = require("hs.keycodes") end

local module = require("hs.eventtap.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.event = require("hs.eventtap.event")

--- hs.eventtap.event.newMouseEvent(eventtype, point) -> event
--- Constructor
--- Creates a new mouse event.
---   - eventtype is one of the values in hs.eventtap.event.types
---   - point is a table with keys {x,y}
function module.event.newMouseEvent(eventtype, point)
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
    return module.event._newMouseEvent(eventtype, point, button)
end

--- hs.eventtap.leftClick(point)
--- Function
--- Generates a left mouse click event at the specified point
---    - point is a table with keys {x,y} (e.g. {x=0,y=0})
---
--- (Note: this is a wrapper around hs.eventtap.event.newMouseEvent that sends leftmousedown and leftmouseup events)
function module.leftClick(point)
    module.event.newMouseEvent(module.event.types["leftmousedown"], point):post()
    module.event.newMouseEvent(module.event.types["leftmouseup"], point):post()
end

--- hs.eventtap.rightClick(point)
--- Function
--- Generates a right mouse click event at the specified point
---    - point is a table with keys {x,y} (e.g. {x=0,y=0})
---
--- (Note: this is a wrapper around hs.eventtap.event.newMouseEvent that sends rightmousedown and rightmouseup events)
function module.rightClick(point)
    module.event.newMouseEvent(module.event.types["rightmousedown"], point):post()
    module.event.newMouseEvent(module.event.types["rightmouseup"], point):post()
end

--- hs.eventtap.middleClick(point)
--- Function
--- Generates a middle mouse click event at the specified point
---    - point is a table with keys {x,y} (e.g. {x=0,y=0})
---
--- (Note: this is a wrapper around hs.eventtap.event.newMouseEvent that sends middlemousedown and middlemouseup events)
function module.middleClick(point)
    module.event.newMouseEvent(module.event.types["middlemousedown"], point):post()
    module.event.newMouseEvent(module.event.types["middlemouseup"], point):post()
end

--- hs.eventtap.keyStrokes(modifiers, string)
--- Function
--- Generates keystrokes for the supplied keyboard modifiers and string
--- The modifiers should be a table, containing any/several/all/none of "fn", "ctrl", "alt", "cmd", "shift" or "fn" (or their Unicode equivalents ⌃, ⌥, ⌘, ⇧)
--- The string can be a single character or many (e.g. if you want to simulate typing of a block of text)
function module.keyStrokes(modifiers, text)
    for c in text:gmatch"." do
        module.event.newKeyEvent(modifiers, c, true):post()
        module.event.newKeyEvent(modifiers, c, false):post()
    end
end

-- Return Module Object --------------------------------------------------

return module
