local pathwatcher = {}

local pathwatcher_instance = {}

function pathwatcher_instance:start()
  self.__stream = __api.pathwatcher_start(self.path, self.fn)
end

function pathwatcher_instance:stop()
  __api.pathwatcher_stop(self.__stream)
  self.__stream = nil
end

function pathwatcher.new(path, fn)
  local p = {path = path, fn = fn}
  return setmetatable(p, {__index = pathwatcher_instance})
end

return pathwatcher
