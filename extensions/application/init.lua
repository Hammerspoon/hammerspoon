--- === hs.application ===
---
--- Manipulate running applications

local uielement = hs.uielement  -- Make sure parent module loads
local application = require "hs.application.internal"
application.watcher = require "hs.application.watcher"
local window = require "hs.window"

local type,pairs,ipairs=type,pairs,ipairs
local tunpack,tpack,tsort=table.unpack,table.pack,table.sort

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
  if self:isHidden() then return r -- do not check :isHidden for every window
  else for _,w in ipairs(self:allWindows()) do if not w:isMinimized() then r[#r+1]=w end end end
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

  if exact then for _,a in ipairs(apps) do if a:name()==hint then r[#r+1]=a end end
  else for _,a in ipairs(apps) do if a:name():lower():find(hint:lower()) then r[#r+1]=a end end end
  tsort(r,function(a,b)return a:kind()>b:kind()end) -- gui apps first
  if #r>0 then return tunpack(r) end

  r=tpack(window.find(hint,exact))
  local rs={} for _,w in ipairs(r) do rs[w:application()]=true end -- :toSet
  for a in pairs(rs) do r[#r+1]=a end -- and back, no dupes
  if #r>0 then return tunpack(r) end
end


--- hs.application.open(app) -> hs.application object
--- Constructor
--- Launches an application, or activates it if it's already running
---
--- Parameters:
---  * app - a string describing the application to open; it can be:
---    - the application's name as per `hs.application:name()`
---    - the full path to an application on disk (including the `.app` suffix)
---    - the application's bundle ID as per `hs.application:bundleID()`
---
--- Returns:
---  * the `hs.application` object for the launched or activated application; `nil` if not found
function application.open(app)
  if type(app)~='string' then error('app must be a string',2) end
  if application.launchOrFocus(app) then return application.find(app,true) end
  if application.launchOrFocusByBundleID(app) then return application.find(app,true) end
end

do
  local mt=getmetatable(application)
  if not mt.__call then mt.__call=function(t,...)if t.find then return t.find(...) else error('cannot call uielement',2) end end end
end
--getmetatable(application).__call=function(_,...)return application.find(...)end
return application

