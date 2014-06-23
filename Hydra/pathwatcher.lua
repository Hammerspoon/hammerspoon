api.pathwatcher.pathwatchers = {}

api.doc.pathwatcher.new = {"api.pathwatcher.new(path, fn())", "Returns a new pathwatcher that can be started and stopped. Contains fields: path, fn."}
function api.pathwatcher.new(path, fn)
  return setmetatable({path = path, fn = fn}, {__index = api.pathwatcher})
end

api.doc.pathwatcher.start = {"api.pathwatcher:start()", "Registers pathwatcher's fn as a callback when pathwatcher's path or any descendent changes."}
function api.pathwatcher:start()
  table.insert(api.pathwatcher.pathwatchers, self)
  self.__pos = # api.pathwatcher.pathwatchers
  return self:_start()
end

api.doc.pathwatcher.stop = {"api.pathwatcher:stop()", "Unregisters pathwatcher's fn so it won't be called again until the pathwatcher is restarted."}
function api.pathwatcher:stop()
  table.remove(api.pathwatcher.pathwatchers, self.__pos)
  return self:_stop()
end
