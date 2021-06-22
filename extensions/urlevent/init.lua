--- === hs.urlevent ===
---
--- Allows Hammerspoon to respond to URLs
--- Hammerspoon is configured to react to URLs that start with `hammerspoon://` when they are opened by OS X.
--- This extension allows you to register callbacks for these URL events and their parameters, offering a flexible way to receive events from other applications.
---
--- You can also choose to make Hammerspoon the default for `http://` and `https://` URLs, which lets you route the URLs in your Lua code
---
--- Given a URL such as `hammerspoon://someEventToHandle?someParam=things&otherParam=stuff`, in the literal, RFC1808 sense of the URL, `someEventToHandle` is the hostname (or net_loc) of the URL, but given that these are not network resources, we consider `someEventToHandle` to be the name of the event. No path should be specified in the URL - it should consist purely of a hostname and, optionally, query parameters.
---
--- See also `hs.ipc` for a command line IPC mechanism that is likely more appropriate for shell scripts or command line use. Unlike `hs.ipc`, `hs.urlevent` is not able to return any data to its caller.
---
--- NOTE: If Hammerspoon is not running when a `hammerspoon://` URL is opened, Hammerspoon will be launched, but it will not react to the URL event. Nor will it react to any events until this extension is loaded and event callbacks have been bound.
--- NOTE: Any event which is received, for which no callback has been bound, will be logged to the Hammerspoon Console
--- NOTE: When you trigger a URL from another application, it is usually best to have the URL open in the background, if that option is available. Otherwise, OS X will activate Hammerspoon (i.e. give it focus), which makes URL events difficult to use for things like window management.

local log = require'hs.logger'.new('urlevent')
local urlevent = require "hs.urlevent.internal"
local callbacks = {}

--- hs.urlevent.httpCallback
--- Variable
--- A function that should handle http:// and https:// URL events
---
--- Notes:
---  * The function should handle four arguments:
---   * scheme - A string containing the URL scheme (i.e. "http")
---   * host - A string containing the host requested (e.g. "www.hammerspoon.org")
---   * params - A table containing the key/value pairs of all the URL parameters
---   * fullURL - A string containing the full, original URL
---   * senderPID - An integer containing the PID of the application that opened the URL, if available (otherwise -1)
urlevent.httpCallback = nil

-- Set up our top-level callback and register it with the Objective C part of the extension
local function urlEventCallback(scheme, event, params, fullURL, senderPID)
	local bundleID = hs.processInfo["bundleID"]
	local hsScheme = string.lower(string.sub(bundleID, (string.find(bundleID, "%.[^%.]*$")) + 1))
    if (scheme == "http" or scheme == "https" or scheme == "file") then
        if not urlevent.httpCallback then
            log.ef("Hammerspoon is configured for http(s):// URLs, but no http callback has been set")
        else
            local ok, err = xpcall(function() return urlevent.httpCallback(scheme, event, params, fullURL, senderPID) end, debug.traceback)
            if not ok then
                hs.showError(err)
            end
        end
    elseif (scheme == hsScheme) then
        if not event then
            log.wf("Something called a " .. hsScheme .. ":// URL without an action")
            return
        end
        if not callbacks[event] then
            log.wf("Received hs.urlevent event with no registered callback:"..event)
        else
            local ok, err = xpcall(function() return callbacks[event](event, params, senderPID) end, debug.traceback)
            if not ok then
                hs.showError(err)
            end
        end
    else
        log.ef("Hammerspoon has been passed a %s URL, but does not know how to handle it", scheme)
    end
end
urlevent.setCallback(urlEventCallback)

--- hs.urlevent.bind(eventName, callback)
--- Function
--- Registers a callback for a hammerspoon:// URL event
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
---   * senderPID - An integer containing the PID of the sending application, if available (otherwise -1)
---  * Given the URL `hammerspoon://doThingA?value=1` The event name is `doThingA` and the callback's `params` argument will be a table containing `{["value"] = "1"}`
function urlevent.bind(eventName, callback)
    callbacks[eventName] = callback
end

--- hs.urlevent.openURL(url)
--- Function
--- Opens a URL with the default application
---
--- Parameters:
---  * url - A string containing a URL, which must contain a scheme and '://'
---
--- Returns:
---  * A boolean, true if the URL was opened successfully, otherwise false
function urlevent.openURL(url)
  local c = string.find(url, "://")
  if not c then
    log.ef("hs.urlevent.openURL() called for a URL that lacks '://'")
    return false
  end

  local scheme = string.sub(url, 0, c - 1)
  local handler = urlevent.getDefaultHandler(scheme)
  return urlevent.openURLWithBundle(url, handler)
end

return urlevent
