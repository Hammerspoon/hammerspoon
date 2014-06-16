local app = {}

local window = require("window")
local fp = require("fp")

local app_instance = {}

function app_instance:title() return __api.app_title(self.pid) end
function app_instance:ishidden() return __api.app_is_hidden(self.pid) end
function app_instance:show() __api.app_show(self.pid) end
function app_instance:hide() __api.app_hide(self.pid) end
function app_instance:kill() __api.app_kill(self.pid) end
function app_instance:kill9() __api.app_kill9(self.pid) end

function app_instance:windows()
  return fp.map(__api.app_get_windows(self.pid), window.rawinit)
end

function app_instance:visible_windows()
  print("not implemented yet :(")
  -- self:windows().filter(function(win) return !win:app().ishidden() && !win:isminimized && win:isstandard() )
end

local function rawinit(pid)
  return setmetatable({pid = pid}, {__index = app_instance})
end

function app.running_apps()
  return fp.map(__api.app_running_apps(), rawinit)
end

return app
