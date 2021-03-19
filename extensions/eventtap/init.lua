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
---
--- `hs.eventtap.event.newGesture` uses an external library by Calf Trail Software, LLC.
---
--- Touch
--- Copyright (C) 2010 Calf Trail Software, LLC
---
--- This program is free software; you can redistribute it and/or
--- modify it under the terms of the GNU General Public License
--- as published by the Free Software Foundation; either version 2
--- of the License, or (at your option) any later version.
---
--- This program is distributed in the hope that it will be useful,
--- but WITHOUT ANY WARRANTY; without even the implied warranty of
--- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--- GNU General Public License for more details.
---
--- You should have received a copy of the GNU General Public License
--- along with this program; if not, write to the Free Software
--- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

local module   = require("hs.eventtap.internal")
module.event   = require("hs.eventtap.event")
local fnutils  = require("hs.fnutils")
local keycodes = require("hs.keycodes")
local timer    = require("hs.timer")

-- private variables and methods -----------------------------------------

local function getKeycode(s)
  local n
  if type(s)=='number' then n=s
  elseif type(s)~='string' then error('key must be a string or a number',3)
  elseif (s:sub(1, 1) == '#') then n=tonumber(s:sub(2))
  else n=keycodes.map[string.lower(s)] end
  if not n then error('Invalid key: '..s..' - this may mean that the key requested does not exist in your keymap (particularly if you switch keyboard layouts frequently)',3) end
  return n
end

local function getMods(mods)
  local r={}
  if not mods then return r end
  if type(mods)=='table' then mods=table.concat(mods,'-') end
  if type(mods)~='string' then error('mods must be a string or a table of strings',3) end
  -- super simple substring search for mod names in a string
  mods=string.lower(mods)
  local function find(ps)
    for _,s in ipairs(ps) do
      if string.find(mods,s,1,true) then r[#r+1]=ps[#ps] return end
    end
  end
  find{'cmd','command','⌘'} find{'ctrl','control','⌃'}
  find{'alt','option','⌥'} find{'shift','⇧'}
  find{'fn'}
  return r
end

module.event.types        = ls.makeConstantsTable(module.event.types)
module.event.properties   = ls.makeConstantsTable(module.event.properties)
module.event.rawFlagMasks = ls.makeConstantsTable(module.event.rawFlagMasks)

-- Public interface ------------------------------------------------------

local originalNewKeyEvent = module.event.newKeyEvent
module.event.newKeyEvent = function(mods, key, isDown)
    if type(mods) == "nil" then mods = {} end
    if (type(mods) == "number" or type(mods) == "string") and type(key) == "boolean" then
        mods, key, isDown = nil, mods, key
    end
    local keycode = getKeycode(key)
    local modifiers = mods and getMods(mods) or nil
--    print(finspect(table.pack(modifiers, keycode, isDown)))
    return originalNewKeyEvent(modifiers, keycode, isDown)
end

--- hs.eventtap.event.newKeyEventSequence(modifiers, character) -> table
--- Function
--- Generates a table containing the keydown and keyup events to generate the keystroke with the specified modifiers.
---
--- Parameters:
---  * modifiers - A table containing the keyboard modifiers to apply ("cmd", "alt", "shift", "ctrl", "rightCmd", "rightAlt", "rightShift", "rightCtrl", or "fn")
---  * character - A string containing a character to be emitted
---
--- Returns:
---  * a table with events which contains the individual events that Apple recommends for building up a keystroke combination (see [hs.eventtap.event.newKeyEvent](#newKeyEvents)) in the order that they should be posted (i.e. the first half will contain keyDown events and the second half will contain keyUp events)
---
--- Notes:
---  * The `modifiers` table must contain the full name of the modifiers you wish used for the keystroke as defined in `hs.keycodes.map` -- the Unicode equivalents are not supported by this function.
---  * The returned table will always contain an even number of events -- the first half will be the keyDown events and the second half will be the keyUp events.
---  * The events have not been posted; the table can be used without change as the return value for a callback to a watcher defined with [hs.eventtap.new](#new).
function module.event.newKeyEventSequence(modifiers, character)
  local codes = fnutils.map({table.unpack(modifiers), character}, getKeycode)
  local n = #codes
  local events = {}
  for i, code in ipairs(codes) do
    events[i] = module.event.newKeyEvent(code, true)
    events[2*n+1-i] = module.event.newKeyEvent(code, false)
  end
  return events
end

--- hs.eventtap.event.newMouseEvent(eventtype, point[, modifiers) -> event
--- Constructor
--- Creates a new mouse event
---
--- Parameters:
---  * eventtype - One of the mouse related values from `hs.eventtap.event.types`
---  * point - An hs.geometry point table (i.e. of the form `{x=123, y=456}`) indicating the location where the mouse event should occur
---  * modifiers - An optional table (e.g. {"cmd", "alt"}) containing zero or more of the following keys:
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
    local button
    if eventtype == types["leftMouseDown"] or eventtype == types["leftMouseUp"] or eventtype == types["leftMouseDragged"] then
        button = "left"
    elseif eventtype == types["rightMouseDown"] or eventtype == types["rightMouseUp"] or eventtype == types["rightMouseDragged"] then
        button = "right"
    elseif eventtype == types["otherMouseDown"] or eventtype == types["otherMouseUp"] or eventtype == types["otherMouseDragged"] then
        button = "other"
    elseif eventtype == types["mouseMoved"] then
        button = "none"
    else
        print("Error: unrecognised mouse button eventtype: " .. tostring(eventtype))
        return nil
    end
    return module.event._newMouseEvent(eventtype, point, button, modifiers)
end

--- hs.eventtap.leftClick(point[, delay])
--- Function
--- Generates a left mouse click event at the specified point
---
--- Parameters:
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---  * delay - An optional delay (in microseconds) between mouse down and up event. Defaults to 200000 (i.e. 200ms)
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
    timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["leftMouseUp"], point):post()
end

--- hs.eventtap.rightClick(point[, delay])
--- Function
--- Generates a right mouse click event at the specified point
---
--- Parameters:
---  * point - A table with keys `{x, y}` indicating the location where the mouse event should occur
---  * delay - An optional delay (in microseconds) between mouse down and up event. Defaults to 200000 (i.e. 200ms)
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
    timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["rightMouseUp"], point):post()
end

--- hs.eventtap.otherClick(point[, delay][, button])
--- Function
--- Generates an "other" mouse click event at the specified point
---
--- Parameters:
---  * point  - A table with keys `{x, y}` indicating the location where the mouse event should occur
---  * delay  - An optional delay (in microseconds) between mouse down and up event. Defaults to 200000 (i.e. 200ms)
---  * button - An optional integer, default 2, between 2 and 31 specifying the button number to be pressed.  If this parameter is specified then `delay` must also be specified, though you may specify it as `nil` to use the default.
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a wrapper around `hs.eventtap.event.newMouseEvent` that sends `otherMouseDown` and `otherMouseUp` events)
---
---  * macOS recognizes up to 32 distinct mouse buttons, though few mouse devices have more than 3.  The left mouse button corresponds to button number 0 and the right mouse button corresponds to 1;  distinct events are used for these mouse buttons, so you should use `hs.eventtap.leftClick` and `hs.eventtap.rightClick` respectively.  All other mouse buttons are coalesced into the `otherMouse` events and are distinguished by specifying the specific button with the `mouseEventButtonNumber` property, which this function does for you.
---  * The specific purpose of mouse buttons greater than 2 varies by hardware and application (typically they are not present on a mouse and have no effect in an application)
function module.otherClick(point, delay, button)
    if delay==nil then
        delay=200000
    end
    if button==nil then
        button = 2
    end
    if button < 2 or button > 31 then
        error("button number must be between 2 and 31 inclusive", 2)
    end
    module.event.newMouseEvent(module.event.types["otherMouseDown"], point):setProperty(module.event.properties["mouseEventButtonNumber"], button):post()
    hs.timer.usleep(delay)
    module.event.newMouseEvent(module.event.types["otherMouseUp"], point):setProperty(module.event.properties["mouseEventButtonNumber"], button):post()
end


--- hs.eventtap.middleClick(point[, delay])
--- Function
--- Generates a middle mouse click event at the specified point
---
--- Parameters:
---  * point  - A table with keys `{x, y}` indicating the location where the mouse event should occur
---  * delay  - An optional delay (in microseconds) between mouse down and up event. Defaults to 200000 (i.e. 200ms)
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is just a wrapper which calls `hs.eventtap.otherClick(point, delay, 2)` and is included solely for backwards compatibility.
module.middleClick = function(point, delay)
    module.otherClick(point, delay, 2)
end

--- hs.eventtap.keyStroke(modifiers, character[, delay, application])
--- Function
--- Generates and emits a single keystroke event pair for the supplied keyboard modifiers and character
---
--- Parameters:
---  * modifiers - A table containing the keyboard modifiers to apply ("fn", "ctrl", "alt", "cmd", "shift", or their Unicode equivalents)
---  * character - A string containing a character to be emitted
---  * delay - An optional delay (in microseconds) between key down and up event. Defaults to 200000 (i.e. 200ms)
---  * application - An optional hs.application object to send the keystroke to
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is ideal for sending single keystrokes with a modifier applied (e.g. sending ⌘-v to paste, with `hs.eventtap.keyStroke({"cmd"}, "v")`). If you want to emit multiple keystrokes for typing strings of text, see `hs.eventtap.keyStrokes()`
---
---  * Note that invoking this function with a table (empty or otherwise) for the `modifiers` argument will force the release of any modifier keys which have been explicitly created by [hs.eventtap.event.newKeyEvent](#newKeyEvent) and posted that are still in the "down" state. An explicit `nil` for this argument will not (i.e. the keystroke will inherit any currently "down" modifiers)
function module.keyStroke(modifiers, character, delay, application)
    local targetApp = nil
    local keyDelay = 200000

    if type(delay) == "userdata" then
        targetApp = delay
    else
        targetApp = application
    end

    if type(delay) == "number" then
        keyDelay = delay
    end

    --print("targetApp: "..tostring(targetApp))
    --print("keyDelay: "..tostring(keyDelay))

    module.event.newKeyEvent(modifiers, character, true):post(targetApp)
    timer.usleep(keyDelay)
    module.event.newKeyEvent(modifiers, character, false):post(targetApp)
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
