--- === hs.appfinder ===
---
--- Easily find ```hs.application``` and ```hs.window``` objects
---
--- This module is *deprecated*; you can use `hs.window.find()`, `hs.window.get()`, `hs.application.find()`,
--- `hs.application.get()`, `hs.application:findWindow()` and `hs.application:getWindow()` instead.

local appfinder = {}
local application = require "hs.application"
local window = require "hs.window"

--- hs.appfinder.appFromName(name) -> app or nil
--- Function
--- Finds an application by its name (e.g. "Safari")
---
--- Parameters:
---  * name - A string containing the name of the application to search for
---
--- Returns:
---  * An hs.application object if one can be found, otherwise nil
appfinder.appFromName=application.get

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
  local w=window.get(title) if w then return w:application() end
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
  local w=window.find(pattern) if w then return w:application() end
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
appfinder.windowFromWindowTitle=window.get

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
appfinder.windowFromWindowTitlePattern=window.find

return appfinder
