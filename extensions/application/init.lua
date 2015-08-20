--- === hs.application ===
---
--- Manipulate running applications

local uielement = hs.uielement  -- Make sure parent module loads
local application = require "hs.application.internal"
application.watcher = require "hs.application.watcher"
local window = require "hs.window"
local moses = require "hs.moses"

local type,ipairs=type,ipairs
local tunpack,tpack,tinsert=table.unpack,table.pack,table.insert

--- hs.application:visibleWindows() -> win[]
--- Method
--- Returns only the app's windows that are visible.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing zero or more hs.window objects
function application:visibleWindows()
  --  return moses.filter(self:allWindows(), window.isVisible)
  local r={}
  if self:isHidden() then return r
  else for _,w in ipairs(self:allWindows()) do if not w:isMinimized() then tinsert(r,w) end end end -- (barely) faster
  return r
end

--- hs.application:activate([allWindows]) -> bool
--- Method
--- Tries to activate the app (make its key window focused) and returns whether it succeeded; if allWindows is true, all windows of the application are brought forward as well.
---
--- Parameters:
---  * allWindows - If true, all windows of the application will be brought to the front. Otherwise, only the application's key window will. Defaults to false.
---
--- Returns:
---  * A boolean value indicating whether or not the application could be activated
function application:activate(allWindows)
  allWindows=allWindows and true or false
  if self:isUnresponsive() then return false end
  local win = self:_focusedwindow()
  if win then
    return win:becomeMain() and self:_bringtofront(allWindows)
  else
    return self:_activate(allWindows)
  end
end

--- hs.application:name()
--- Method
--- Alias for `hs.application:title()`
application.name=application.title

--- hs.application.find(hint[, exact]) -> hs.application object(s)
--- Function
--- Finds running applications
---
--- Parameters:
---  * hint - search criterion for the desired application(s); it can be:
---    - a pid number as per `hs.application:pid()`
---    - a bundle ID string as per `hs.application:bundleID()`
---    - a string pattern that matches (via `string.find`) the application name as per `hs.application:name()` (for convenience, the matching will be done on lowercased strings)
---    - a string pattern that matches (via `string.find`) the application's window title per `hs.window:title()` (for convenience, the matching will be done on lowercased strings)
---  * exact - (optional) if `true`, `hint` is the exact name of the app, or the exact title of its window; will use `==` instead of `string.find` (and the original case)
---
--- Returns:
---  * one or more hs.application objects that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * for convenience you can call this as `hs.application(hint)`
---
--- Usage:
--- -- by pid
--- hs.application(42):name() --> Finder
--- -- by bundle id
--- hs.application'com.apple.Safari':name() --> Safari
--- -- by name
--- hs.application'chrome':name() --> Google Chrome
--- -- by window title
--- hs.application'bash':name() --> Terminal
function application.find(hint,exact)
  if hint==nil then return end
  local typ=type(hint)
  if typ=='number' then return application.applicationForPID(hint)
  elseif typ~='string' then error('hint must be a number or string',2) end
  local r=application.applicationsForBundleID(hint)
  if #r>0 then return tunpack(r) end
  local apps=application.runningApplications()
  r=moses.filter(apps,exact and function(_,a)return a:name()==hint end or function(_,a)return a:name():lower():find(hint:lower())end)
  if #r>0 then return tunpack(moses.sort(r,function(a,b)return a:kind()>b:kind()end)) end -- gui apps first
  r=moses.toArray(window.find(hint,exact))
  if #r>0 then return tunpack(moses(r):map(function(_,w)return w:application()end):unique():value()) end
end

do
  local mt=getmetatable(application)
  if not mt.__call then mt.__call=function(t,...)if t.find then return t.find(...) else error('cannot call uielement',2) end end end
end
--getmetatable(application).__call=function(_,...)return application.find(...)end
return application

