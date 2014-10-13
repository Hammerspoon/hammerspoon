--- === mjolnir.application ===
---
--- Manipulate running applications.

local application = require "mjolnir.application.internal"
local fnutils = require "mjolnir.fnutils"
local window = require "mjolnir.window"

--- mjolnir.application:visiblewindows() -> win[]
--- Method
--- Returns only the app's windows that are visible.
function application:visiblewindows()
  return fnutils.filter(self:allwindows(), window.isvisible)
end

--- mjolnir.application:activate(allwindows = false) -> bool
--- Method
--- Tries to activate the app (make its key window focused) and returns whether it succeeded; if allwindows is true, all windows of the application are brought forward as well.
function application:activate(allwindows)
  if self:isunresponsive() then return false end
  local win = self:_focusedwindow()
  if win then
    return win:becomemain() and self:_bringtofront(allwindows)
  else
    return self:_activate(allwindows)
  end
end

return application
