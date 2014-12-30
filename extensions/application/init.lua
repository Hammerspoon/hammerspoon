--- === hs.application ===
---
--- Manipulate running applications.

local uielement = hs.uielement  -- Make sure parent module loads
local application = require "hs.application.internal"
local fnutils = require "hs.fnutils"
local window = require "hs.window"

application.watcher = require "hs.application.watcher"

--- hs.application:visibleWindows() -> win[]
--- Method
--- Returns only the app's windows that are visible.
function application:visibleWindows()
  return fnutils.filter(self:allWindows(), window.isVisible)
end

--- hs.application:activate(allWindows = false) -> bool
--- Method
--- Tries to activate the app (make its key window focused) and returns whether it succeeded; if allWindows is true, all windows of the application are brought forward as well.
function application:activate(allWindows)
  if self:isUnresponsive() then return false end
  local win = self:_focusedwindow()
  if win then
    return win:becomeMain() and self:_bringtofront(allWindows)
  else
    return self:_activate(allWindows)
  end
end

return application
