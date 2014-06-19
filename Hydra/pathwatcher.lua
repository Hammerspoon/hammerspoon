local pathwatcher = {}
local pathwatcher_metatable = {__index = pathwatcher}

function pathwatcher:start()
  self.__stream, self.__closureref = __api.pathwatcher_start(self.path, self.fn)
end

function pathwatcher:stop()
  __api.pathwatcher_stop(self.__stream, self.__closureref)
  self.__stream = nil
  self.__closureref = nil
end

function pathwatcher.new(path, fn)
  local p = {path = path, fn = fn}
  return setmetatable(p, pathwatcher_metatable)
end

return pathwatcher
