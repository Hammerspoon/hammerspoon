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

local module = require("hs.eventtap.internal")
module.event = require("hs.eventtap.event")
local fnutils = require("hs.fnutils")
require("hs.timer")

-- private variables and methods -----------------------------------------

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" and width < i:len() then width = i:len() end
    end
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" then
            result = result..string.format("%-"..tostring(width).."s %d\n", i, v)
        end
    end
    return result
end

local __index_for_types = function(object, key)
    for i,v in pairs(object) do
        if type(i) == "string" then -- ignore numbered keys
            if i:lower() == key then
                print(debug.getinfo(2).short_src..":"..debug.getinfo(2).currentline..": type '"..key.."' is deprecated, use '"..i.."'")
                return object[i]
            end
        end
    end
    return nil
end

local __index_for_props = function(object, key)
    for i,v in pairs(object) do
        if type(i) == "string" then -- ignore numbered keys
            if i:sub(1,1):upper()..i:sub(2,-1) == key then
                print(debug.getinfo(2).short_src..":"..debug.getinfo(2).currentline..": property '"..key.."' is deprecated, use '"..i.."'")
                return object[i]
            end
        end
    end
    return nil
end

module.event.types      = setmetatable(module.event.types,      { __index    = __index_for_types,
                                                                  __tostring = __tostring_for_tables })
module.event.properties = setmetatable(module.event.properties, { __index    = __index_for_props,
                                                                  __tostring = __tostring_for_tables })

-- Public interface ------------------------------------------------------

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
    if eventtype == types["leftMouseDown"] or eventtype == types["leftMouseUp"] or eventtype == types["leftMouseDragged"] then
        button = "left"
    elseif eventtype == types["rightMouseDown"] or eventtype == types["rightMouseUp"] or eventtype == types["rightMouseDragged"] then
        button = "right"
    elseif eventtype == types["middleMouseDown"] or eventtype == types["middleMouseUp"] or eventtype == types["middleMouseDragged"] then
        button = "middle"
    else
        print("Error: unrecognised mouse button eventtype: " .. tostring(eventtype))
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
function module.leftClick(point, delay)
    if delay==nil then
        delay=200000
    end

    module.event.newMouseEvent(module.event.types["leftMouseDown"], point):post()
    hs.timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["leftMouseUp"], point):post()
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
function module.rightClick(point, delay)
    if delay==nil then
        delay=200000
    end

    module.event.newMouseEvent(module.event.types["rightMouseDown"], point):post()
    hs.timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["rightMouseUp"], point):post()
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
function module.middleClick(point, delay)
    if delay==nil then
        delay=200000
    end

    module.event.newMouseEvent(module.event.types["middleMouseDown"], point):post()
    hs.timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["middleMouseUp"], point):post()
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
function module.keyStroke(modifiers, character, delay)
    if delay==nil then
        delay=200000
    end

    module.event.newKeyEvent(modifiers, string.lower(character), true):post()
    hs.timer.usleep(delay)
    module.event.newKeyEvent(modifiers, string.lower(character), false):post()
end


--- hs.eventtap.scrollWheel(offsets, modifiers, unit) -> event
--- Function
--- Generates and emits a scroll wheel event
---
--- Parameters:
---  * offsets - A table containing the {horizontal, vertical} amount to scroll. Positive values scroll up or left, negative values scroll down or right.
---  * mods - A table containing zero or more of the following:
---   * cmd
---   * alt
---   * shift
---   * ctrl
---   * fn
---  * unit - An optional string containing the name of the unit for scrolling. Either "line" (the default) or "pixel"
---
--- Returns:
---  * None
function module.scrollWheel(offsets, modifiers, unit)
    module.event.newScrollEvent(offsets, modifiers, unit):post()
end
-- Return Module Object --------------------------------------------------

return module
