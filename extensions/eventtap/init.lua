--- === hs.eventtap ===
---
--- Tap into input events (mouse, keyboard, trackpad) for observation and possibly overriding them
--- It also provides convenience wrappers for sending mouse and keyboard events. If you need to construct finely controlled mouse/keyboard events, see hs.eventtap.event
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

--- === hs.eventtap.event ===
---
--- Create, modify and inspect events for `hs.eventtap`
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

if not hs.keycodes then hs.keycodes = require("hs.keycodes") end

local module = require("hs.eventtap.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.event = require("hs.eventtap.event")

--- hs.eventtap.event.newMouseEvent(eventtype, point) -> event
--- Constructor
--- Creates a new mouse event
---
--- Parameters:
---  * eventtype - One of the values from `hs.eventtap.event.types`
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---
--- Returns:
---  * An `hs.eventtap` object
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
---
--- Parameters:
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a wrapper around `hs.eventtap.event.newMouseEvent` that sends `leftmousedown` and `leftmouseup` events)
function module.leftClick(point)
    module.event.newMouseEvent(module.event.types["leftmousedown"], point):post()
    module.event.newMouseEvent(module.event.types["leftmouseup"], point):post()
end

--- hs.eventtap.rightClick(point)
--- Function
--- Generates a right mouse click event at the specified point
---
--- Parameters:
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a wrapper around `hs.eventtap.event.newMouseEvent` that sends `rightmousedown` and `rightmouseup` events)
function module.rightClick(point)
    module.event.newMouseEvent(module.event.types["rightmousedown"], point):post()
    module.event.newMouseEvent(module.event.types["rightmouseup"], point):post()
end

--- hs.eventtap.middleClick(point)
--- Function
--- Generates a middle mouse click event at the specified point
---
--- Parameters:
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a wrapper around `hs.eventtap.event.newMouseEvent` that sends `middlemousedown` and `middlemouseup` events)
function module.middleClick(point)
    module.event.newMouseEvent(module.event.types["middlemousedown"], point):post()
    module.event.newMouseEvent(module.event.types["middlemouseup"], point):post()
end

--- hs.eventtap.keyStrokes(modifiers, text)
--- Function
--- Generates and emits keystroke events for the supplied keyboard modifiers and text
---
--- Parameters:
---  * modifiers - A table containing the keyboard modifiers to apply ("fn", "ctrl", "alt", "cmd", "shift", "fn", or their Unicode equivalents)
---  * text - A string containing the text that should be broken down into individual keystroke events. This can be a single character, or many
---
--- Returns:
---  * None
function module.keyStrokes(modifiers, text)
    for c in text:gmatch"." do
        module.event.newKeyEvent(modifiers, c, true):post()
        module.event.newKeyEvent(modifiers, c, false):post()
    end
end

-- Return Module Object --------------------------------------------------

return module
