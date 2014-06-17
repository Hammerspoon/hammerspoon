local util = require("util")

local app = {}
local application_metatable = {__index = app}

function app:title() return __api.application_title(self.pid) end
function app:ishidden() return __api.application_is_hidden(self.pid) end
function app:show() __api.application_show(self.pid) end
function app:hide() __api.application_hide(self.pid) end
function app:kill() __api.application_kill(self.pid) end
function app:kill9() __api.application_kill9(self.pid) end

function app:all_windows()
  local window = require("window")
  return util.map(__api.application_get_windows(self.pid), window.rawinit)
end

function app:visible_windows()
  local window = require("window")
  return util.filter(self:windows(), window.isvisible)
end

function app:activate()
  return __api.application_activate(self.pid)
end

function application_metatable.__eq(a, b)
  return a.pid == b.pid
end

function app.rawinit(pid)
  return setmetatable({pid = pid}, application_metatable)
end

function app.running_applications()
  return util.map(__api.application_running_applications(), app.rawinit)
end

return app
