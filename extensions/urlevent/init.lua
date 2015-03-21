--- === hs.urlevent ===
---
--- Allows hammerspoon:// URLs to act as an IPC mechanism
--- Hammerspoon is configured to react to URLs that start with `hammerspoon://` when they are opened by OS X.
--- This extension allows you to register callbacks for these URL events and their parameters, offering a flexible way to receive events from other applications.
---
--- Given a URL such as `hammerspoon://someEventToHandle?someParam=things&otherParam=stuff`, in the literal, RFC1808 sense of the URL, `someEventToHandle` is the hostname (or net_loc) of the URL, but given that these are not network resources, we consider `someEventToHandle` to be the name of the event. No path should be specified in the URL - it should consist purely of a hostname and, optionally, query parameters.
---
--- See also `hs.ipc` for a command line IPC mechanism that is likely more appropriate for shell scripts or command line use. Unlike `hs.ipc`, `hs.urlevent` is not able to return any data to its caller.
---
--- NOTE: If Hammerspoon is not running when a `hammerspoon://` URL is opened, Hammerspoon will be launched, but it will not react to the URL event. Nor will it react to any events until this extension is loaded and event callbacks have been bound.
--- NOTE: Any event which is received, for which no callback has been bound, will be logged to the Hammerspoon Console

local urlevent = require "hs.urlevent.internal"
local callbacks = {}

-- Set up our top-level callback and register it with the Objective C part of the extension
local function callback(event, params)
    if (callbacks[event]) then
        if not pcall(callbacks[event], event, params) then
            error("Callback handler for event '"..event.."' failed")
        end
    else
        print("Received hs.urlevent event with no registered callback:"..event)
    end
end
urlevent.setCallback(callback)

--- hs.urlevent.bind(eventName, callback)
--- Function
--- Registers a callback for a URL event
---
--- Parameters:
---  * eventName - A string containing the name of an event
---  * callback - A function that will be called when the specified event is received, or nil to remove an existing callback
---
--- Returns:
---  * None
---
--- Notes:
---  * The callback function should accept two parameters:
---   * eventName - A string containing the name of the event
---   * params - A table containing key/value string pairs containing any URL parameters that were specified in the URL
---  * Given the URL `hammerspoon://doThingA?value=1` The event name is `doThingA` and the callback's `params` argument will be a table containing `{["value"] = "1"}`
function urlevent.bind(eventName, callback)
    callbacks[eventName] = callback
end

return urlevent
