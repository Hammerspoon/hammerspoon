--- === hs.application ===
---
--- Manipulate running applications

local uielement = hs.uielement  -- Make sure parent module loads
local application = require "hs.application.internal"
local fnutils = require "hs.fnutils"
local window = require "hs.window"

application.watcher = require "hs.application.watcher"

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
  return fnutils.filter(self:allWindows(), window.isVisible)
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
function application:activate(_allWindows)
  local allWindows = nil
  if not _allWindows then
      allWindows = false
  else
      allWindows = _allWindows
  end

  if self:isUnresponsive() then return false end
  local win = self:_focusedwindow()
  if win then
    return win:becomeMain() and self:_bringtofront(allWindows)
  else
    return self:_activate(allWindows)
  end
end

return application
