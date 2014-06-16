local util = require("util")

local application = {}

local application_instance = {}

function application_instance:title() return __api.application_title(self.pid) end
function application_instance:ishidden() return __api.application_is_hidden(self.pid) end
function application_instance:show() __api.application_show(self.pid) end
function application_instance:hide() __api.application_hide(self.pid) end
function application_instance:kill() __api.application_kill(self.pid) end
function application_instance:kill9() __api.application_kill9(self.pid) end

function application_instance:windows()
  local window = require("window")
  return util.map(__api.application_get_windows(self.pid), window.rawinit)
end

function application_instance:visible_windows()
  local window = require("window")
  return util.filter(self:windows(), window.isvisible)
end

local application_instance_metadata = {__index = application_instance}

function application_instance_metadata.__eq(a, b)
  return a.pid == b.pid
end

function application.rawinit(pid)
  return setmetatable({pid = pid}, application_instance_metadata)
end

function application.running_applications()
  return util.map(__api.application_running_applications(), application.rawinit)
end

return application
