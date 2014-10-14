--- === hs.appfinder ===
---
--- Simplified finding of applications/windows
---
--- Usage: local appfinder = require "hs.appfinder"

local appfinder = {}
local fnutils = require "hs.fnutils"
local application = require "hs.application"
local window = require "hs.window"

-- Internal function to search all windows using a matching function
local function find_window_from_function(fn)
    return fnutils.find(window.allwindows(), fn)
end

-- Internal function to turn a matching function and window title into an application object
local function find_application_from_window(title, fn)
    local w = find_window_from_function(fn)
    if w then
        return w:application()
    else
        return nil
    end
end

--- hs.appfinder.app_from_name(name) -> app or nil
--- Function
--- Finds an application by its name (e.g. "Safari")
function appfinder.app_from_name(name)
    return fnutils.find(application.runningapplications(), function(app) return app:title() == name end)
end

--- hs.appfinder.app_from_window_title(title) -> app or nil
--- Function
--- Finds an application by its window title (e.g. "Activity Monitor (All Processes)")
function appfinder.app_from_window_title(title)
    return find_application_from_window(title, function(win) return win:title() == title end)
end

--- hs.appfinder.app_from_window_title_pattern(pattern) -> app or nil
--- Function
--- Finds an application by Lua pattern in its window title (e.g."Inbox %(%d+ messages.*)")
---  Notes:
---      For more about Lua patterns, see:
---       http://lua-users.org/wiki/PatternsTutorial
---       http://www.lua.org/manual/5.2/manual.html#6.4.1
function appfinder.app_from_window_title_pattern(pattern)
    return find_application_from_window(pattern, function(win) return string.match(win:title(), pattern) end)
end

--- hs.appfinder.window_from_window_title(title) -> win or nil
--- Function
--- Finds a window by its title (e.g. "Activity Monitor (All Processes)")
function appfinder.window_from_window_title(title)
    return find_window_from_function(function(win) return win:title() == title end)
end

return appfinder
