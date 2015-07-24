--- === hs.appfinder ===
---
--- Easily find ```hs.application``` and ```hs.window``` objects

local appfinder = {}
local fnutils = require "hs.fnutils"
local application = require "hs.application"
local window = require "hs.window"

-- Internal function to search all windows using a matching function
local function find_window_from_function(fn)
    return fnutils.find(window.allWindows(), fn)
end

-- Internal function to turn a matching function into an application object
local function find_application_from_window(fn)
    local w = find_window_from_function(fn)
    if w then
        return w:application()
    else
        return nil
    end
end

--- hs.appfinder.appFromName(name) -> app or nil
--- Function
--- Finds an application by its name (e.g. "Safari")
---
--- Parameters:
---  * name - A string containing the name of the application to search for
---
--- Returns:
---  * An hs.application object if one can be found, otherwise nil
function appfinder.appFromName(name)
    return fnutils.find(application.runningApplications(), function(app) return app:title() == name end)
end

--- hs.appfinder.appFromWindowTitle(title) -> app or nil
--- Function
--- Finds an application by its window title (e.g. "Activity Monitor (All Processes)")
---
--- Parameters:
---  * title - A string containing a window title of the application to search for
---
--- Returns:
---  * An hs.application object if one can be found, otherwise nil
function appfinder.appFromWindowTitle(title)
    return find_application_from_window(function(win) return win:title() == title end)
end

--- hs.appfinder.appFromWindowTitlePattern(pattern) -> app or nil
--- Function
--- Finds an application by Lua pattern in its window title (e.g."Inbox %(%d+ messages.*)")
---
--- Parameters:
---  * pattern - a Lua pattern describing a window title of the application to search for
---
--- Returns:
---  * An hs.application object if one can be found, otherwise nil
---
--- Notes:
---  * For more about Lua patterns, see http://lua-users.org/wiki/PatternsTutorial and http://www.lua.org/manual/5.2/manual.html#6.4.1
function appfinder.appFromWindowTitlePattern(pattern)
    return find_application_from_window(function(win) return string.match(win:title(), pattern) end)
end

--- hs.appfinder.windowFromWindowTitle(title) -> win or nil
--- Function
--- Finds a window by its title (e.g. "Activity Monitor (All Processes)")
---
--- Parameters:
---  * title - A string containing the title of the window to search for
---
--- Returns:
---  * An hs.window object if one can be found, otherwise nil
function appfinder.windowFromWindowTitle(title)
    return find_window_from_function(function(win) return win:title() == title end)
end
--
--- hs.appfinder.windowFromWindowTitlePattern(pattern) -> app or nil
--- Function
--- Finds a window by Lua pattern in its title (e.g."Inbox %(%d+ messages.*)")
---
--- Parameters:
---  * pattern - a Lua pattern describing a window title of the window to search for
---
--- Returns:
---  * An hs.window object if one can be found, otherwise nil
---
--- Notes:
---  * For more about Lua patterns, see http://lua-users.org/wiki/PatternsTutorial and http://www.lua.org/manual/5.2/manual.html#6.4.1
function appfinder.windowFromWindowTitlePattern(pattern)
    return find_window_from_function(function(win) return string.match(win:title(), pattern) end)
end

return appfinder
