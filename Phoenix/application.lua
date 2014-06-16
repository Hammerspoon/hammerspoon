local application = {}

local window = require("window")
local fp = require("fp")

local application_instance = {}

function application_instance:title() return __api.application_title(self.pid) end
function application_instance:ishidden() return __api.application_is_hidden(self.pid) end
function application_instance:show() __api.application_show(self.pid) end
function application_instance:hide() __api.application_hide(self.pid) end
function application_instance:kill() __api.application_kill(self.pid) end
function application_instance:kill9() __api.application_kill9(self.pid) end

function application_instance:windows()
  return fp.map(__api.application_get_windows(self.pid), window.rawinit)
end

function application_instance:visible_windows()
  print("not implemented yet :(")
  -- self:windows().filter(function(win) return !win:application().ishidden() && !win:isminimized && win:isstandard() )
end

local function rawinit(pid)
  return setmetatable({pid = pid}, {__index = application_instance})
end

function application.running_applications()
  return fp.map(__api.application_running_applications(), rawinit)
end

return application
