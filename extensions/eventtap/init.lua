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

--- hs.eventtap.event.newMouseEvent(eventtype, point[, modifiers) -> event
--- Constructor
--- Creates a new mouse event
---
--- Parameters:
---  * eventtype - One of the values from `hs.eventtap.event.types`
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---  * modifiers - An optional table containing zero or more of the following keys:
---   * cmd
---   * alt
---   * shift
---   * ctrl
---   * fn
---
--- Returns:
---  * An `hs.eventtap` object
function module.event.newMouseEvent(eventtype, point, modifiers)
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
    return module.event._newMouseEvent(eventtype, point, button, modifiers)
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

--- hs.eventtap.keyStroke(modifiers, character)
--- Function
--- Generates and emits a single keystroke event pair for the supplied keyboard modifiers and character
---
--- Parameters:
---  * modifiers - A table containing the keyboard modifiers to apply ("fn", "ctrl", "alt", "cmd", "shift", "fn", or their Unicode equivalents)
---  * character - A string containing a character to be emitted
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is ideal for sending single keystrokes with a modifier applied (e.g. sending ⌘-v to paste, with `hs.eventtap.keyStroke({"cmd"}, "v")`). If you want to emit multiple keystrokes for typing strings of text, see `hs.eventtap.keyStrokes()`
function module.keyStroke(modifiers, character)
    module.event.newKeyEvent(modifiers, character, true):post()
    module.event.newKeyEvent(modifiers, character, false):post()
end

-- Return Module Object --------------------------------------------------

return module
